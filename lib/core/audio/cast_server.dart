import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'stream_proxy.dart';

/// What the receiver is told it is fetching, and where it lives.
class CastMedia {
  const CastMedia(this.url, this.contentType);

  final Uri url;
  final String contentType;
}

/// The phone's side of casting: an HTTP server on the Wi-Fi interface that the
/// Cast receiver reads the track from.
///
/// A receiver cannot be handed what the phone plays. A googlevideo URL is
/// signed for the identity that asked for it and only serves bounded windows —
/// see [StreamProxy] — and a download or a song off this phone is a file no
/// other device can reach. So the receiver is given a URL on this phone and
/// the bytes are relayed from wherever they really are.
///
/// It listens on the local network, so it serves only what was published to
/// it: every URL carries a random token minted at start and an id minted per
/// track, and nothing outside that table — no path, no origin URL — can be
/// asked for.
class CastServer {
  /// [address] is overridable so tests can serve on loopback.
  CastServer({Future<InternetAddress?> Function()? address})
      : _address = address ?? lanAddress;

  final Future<InternetAddress?> Function() _address;
  HttpServer? _server;
  String _token = '';
  final _random = Random.secure();

  /// Published entries by id. Bounded: a receiver only ever reads the current
  /// track, and one left behind keeps a signed URL alive for nothing.
  final _entries = <String, _Entry>{};
  static const _kept = 4;

  Future<void> _start() async {
    if (_server != null) return;
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _token = _mint(16);
    _server = server;
    server.listen(_handle, onError: (Object _) {});
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _entries.clear();
  }

  /// Publishes a googlevideo stream, relayed in windows like local playback.
  Future<CastMedia> publishStream(
    String originUrl, {
    required String mimeType,
    String userAgent = '',
  }) =>
      _publish(
        _Entry.stream(Uri.parse(originUrl), userAgent),
        // The receiver wants the bare type; YouTube's carries the codecs too.
        mimeType.split(';').first.trim(),
      );

  /// Publishes a file on this phone.
  Future<CastMedia> publishFile(File file) =>
      _publish(_Entry.file(file), sniffContentType(file));

  Future<CastMedia> _publish(_Entry entry, String contentType) async {
    await _start();
    final address = await _address();
    if (address == null) {
      throw const SocketException('No Wi-Fi address to cast from');
    }
    final id = _mint(12);
    _entries[id] = entry;
    while (_entries.length > _kept) {
      _entries.remove(_entries.keys.first);
    }
    return CastMedia(
      Uri(
        scheme: 'http',
        host: address.address,
        port: _server!.port,
        path: '/$_token/$id',
      ),
      contentType,
    );
  }

  String _mint(int bytes) => List.generate(
        bytes,
        (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    // The receiver is a web page on another origin. A plain media element
    // needs none of this, but CAF reads some formats through XHR, and a
    // preflight left unanswered fails as a format error with no hint why.
    response.headers
      ..set('access-control-allow-origin', '*')
      ..set('access-control-allow-headers', 'range')
      ..set('access-control-expose-headers',
          'content-length, content-range, accept-ranges');
    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    final segments = request.uri.pathSegments;
    final entry = segments.length == 2 && segments[0] == _token
        ? _entries[segments[1]]
        : null;
    if (entry == null) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }

    final file = entry.file;
    if (file != null) {
      await _serveFile(request, file);
    } else {
      await StreamProxy.relay(request, entry.origin!,
          userAgent: entry.userAgent);
    }
  }

  static Future<void> _serveFile(HttpRequest request, File file) async {
    final response = request.response;
    try {
      final length = await file.length();
      final range = RegExp(r'bytes=(\d+)-(\d*)')
          .firstMatch(request.headers.value(HttpHeaders.rangeHeader) ?? '');
      var start = 0;
      var end = length - 1;
      if (range != null) {
        start = int.parse(range.group(1)!);
        final last = range.group(2)!;
        if (last.isNotEmpty) end = min(int.parse(last), length - 1);
        if (start > end) {
          response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
          response.headers.set('content-range', 'bytes */$length');
          await response.close();
          return;
        }
        response.statusCode = HttpStatus.partialContent;
        response.headers.set('content-range', 'bytes $start-$end/$length');
      }
      response.headers
        ..set(HttpHeaders.acceptRangesHeader, 'bytes')
        ..set(HttpHeaders.contentTypeHeader, sniffContentType(file))
        ..set(HttpHeaders.contentLengthHeader, '${end - start + 1}');
      if (request.method == 'HEAD') {
        await response.close();
        return;
      }
      await response.addStream(file.openRead(start, end + 1));
      await response.close();
    } catch (_) {
      // A receiver dropping the connection to seek lands here; it is normal.
      try {
        await response.close();
      } catch (_) {}
    }
  }

  /// This phone's address on the local network, which is the only one a
  /// receiver can reach. Null off Wi-Fi.
  static Future<InternetAddress?> lanAddress() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    InternetAddress? fallback;
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!_isPrivate(address)) continue;
        // Mobile data also hands out private addresses (carrier NAT); the
        // receiver is on the Wi-Fi, so that interface wins when present.
        if (interface.name.startsWith('wlan')) return address;
        fallback ??= address;
      }
    }
    return fallback;
  }

  static bool _isPrivate(InternetAddress address) {
    final b = address.rawAddress;
    return b[0] == 10 ||
        (b[0] == 172 && b[1] >= 16 && b[1] < 32) ||
        (b[0] == 192 && b[1] == 168);
  }

  /// The container, read from the first bytes rather than the name: downloads
  /// are stored as `<id>.audio` whatever they hold.
  static String sniffContentType(File file) {
    List<int> head;
    try {
      final handle = file.openSync();
      try {
        head = handle.readSync(12);
      } finally {
        handle.closeSync();
      }
    } catch (_) {
      return 'audio/mpeg';
    }
    bool at(int offset, List<int> bytes) {
      if (head.length < offset + bytes.length) return false;
      for (var i = 0; i < bytes.length; i++) {
        if (head[offset + i] != bytes[i]) return false;
      }
      return true;
    }

    if (at(4, 'ftyp'.codeUnits)) return 'audio/mp4';
    if (at(0, const [0x1A, 0x45, 0xDF, 0xA3])) return 'audio/webm';
    if (at(0, 'fLaC'.codeUnits)) return 'audio/flac';
    if (at(0, 'OggS'.codeUnits)) return 'audio/ogg';
    if (at(0, 'RIFF'.codeUnits)) return 'audio/wav';
    return 'audio/mpeg';
  }
}

class _Entry {
  _Entry.stream(Uri this.origin, this.userAgent) : file = null;
  _Entry.file(File this.file)
      : origin = null,
        userAgent = '';

  final Uri? origin;
  final String userAgent;
  final File? file;
}
