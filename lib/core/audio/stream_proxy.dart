import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// Byte range parsed from a `Range` header.
class _RangeSpec {
  const _RangeSpec(this.start, this.end);

  final int start;

  /// Null when the client asked for everything from [start] onwards.
  final int? end;

  static _RangeSpec? parse(String? header) {
    if (header == null) return null;
    final match = RegExp(r'bytes=(\d+)-(\d*)').firstMatch(header);
    if (match == null) return null;
    final end = match.group(2);
    return _RangeSpec(
      int.parse(match.group(1)!),
      end == null || end.isEmpty ? null : int.parse(end),
    );
  }
}

/// Loopback proxy that turns one continuous read into a series of bounded
/// range requests against googlevideo.
///
/// This exists because googlevideo refuses to serve a whole file in a single
/// response. Measured against a live URL:
///
///   no Range header                  -> 403
///   Range: bytes=0-                  -> 403
///   Range: bytes=0-(last byte)       -> 403
///   Range: bytes=0-131071            -> 206
///
/// Asking for everything is rejected however it is phrased; only a bounded
/// window is served. ExoPlayer issues exactly one open-ended request per track,
/// so no combination of injected headers could have worked — the request has to
/// be split. This proxy answers the player with a single continuous stream
/// while fetching the origin one chunk at a time underneath.
class StreamProxy {
  /// Big enough that the per-chunk round trip disappears into the buffer,
  /// small enough that starting playback does not wait on a large download.
  static const _chunkSize = 1 << 20; // 1 MiB

  HttpServer? _server;

  bool get isRunning => _server != null;

  Future<void> start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  /// Wraps an origin URL into one this proxy serves.
  Uri wrap(String originUrl) {
    final server = _server;
    if (server == null) {
      throw StateError('StreamProxy.start() must be awaited before wrap()');
    }
    return Uri(
      scheme: 'http',
      host: server.address.address,
      port: server.port,
      path: '/stream',
      queryParameters: {'u': base64Url.encode(utf8.encode(originUrl))},
    );
  }

  Future<HttpClientResponse> _fetchChunk(
    HttpClient client,
    Uri origin,
    int start,
    int end,
  ) async {
    final request = await client.getUrl(origin);
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-$end');
    return request.close();
  }

  Future<void> _handle(HttpRequest request) async {
    final encoded = request.uri.queryParameters['u'];
    if (encoded == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final origin = Uri.parse(utf8.decode(base64Url.decode(encoded)));
    final client = HttpClient();
    final requested = _RangeSpec.parse(
      request.headers.value(HttpHeaders.rangeHeader),
    );
    final start = requested?.start ?? 0;

    try {
      // The first chunk doubles as a probe: its Content-Range reveals the total
      // size, which is what the player needs to enable seeking.
      final firstEnd = min(
        start + _chunkSize - 1,
        requested?.end ?? (start + _chunkSize - 1),
      );
      final first = await _fetchChunk(client, origin, start, firstEnd);

      if (first.statusCode != HttpStatus.partialContent &&
          first.statusCode != HttpStatus.ok) {
        request.response.statusCode = first.statusCode;
        await first.drain<void>();
        await request.response.close();
        return;
      }

      final total = _totalLength(first.headers.value('content-range'));
      final end = requested?.end ?? (total != null ? total - 1 : null);

      request.response.statusCode = requested == null
          ? HttpStatus.ok
          : HttpStatus.partialContent;
      final contentType = first.headers.contentType;
      if (contentType != null) {
        request.response.headers.contentType = contentType;
      }
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      if (end != null) {
        request.response.headers
            .set(HttpHeaders.contentLengthHeader, '${end - start + 1}');
        if (requested != null && total != null) {
          request.response.headers
              .set('content-range', 'bytes $start-$end/$total');
        }
      }

      var position = start;
      var chunk = first;
      while (true) {
        await for (final bytes in chunk) {
          request.response.add(bytes);
          position += bytes.length;
        }
        // Backpressure: without this the whole track would be buffered in
        // memory as fast as the origin serves it.
        await request.response.flush();

        if (end == null || position > end) break;
        chunk = await _fetchChunk(
          client,
          origin,
          position,
          min(position + _chunkSize - 1, end),
        );
        if (chunk.statusCode != HttpStatus.partialContent &&
            chunk.statusCode != HttpStatus.ok) {
          break;
        }
      }

      await request.response.close();
    } catch (_) {
      // The player closing the connection mid-seek lands here and is normal;
      // a failed hop must never take down the server.
      try {
        await request.response.close();
      } catch (_) {}
    } finally {
      client.close();
    }
  }

  /// Reads the total size out of a `Content-Range: bytes a-b/total` header.
  static int? _totalLength(String? contentRange) {
    if (contentRange == null) return null;
    final match = RegExp(r'/(\d+)$').firstMatch(contentRange.trim());
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }
}
