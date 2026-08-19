import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// The build running right now, in the two numbers a release carries.
///
/// [build] is what Android compares when it decides whether an APK may be
/// installed over another; [name] is the one a human reads.
class AppVersion {
  const AppVersion({required this.name, required this.build});

  final String name;
  final int build;

  @override
  String toString() => '$name+$build';
}

/// A published release, as much of it as an installer needs.
class Release {
  const Release({
    required this.version,
    required this.build,
    required this.notes,
    required this.url,
    required this.size,
  });

  /// The tag, without its leading `v`.
  final String version;

  /// The build number, read from the asset's file name. Null when the name
  /// did not give it up — the comparison then falls back to [version], which
  /// is the worse signal but never the missing one.
  final int? build;

  final String notes;
  final Uri url;
  final int size;
}

/// Whether there is a newer build than this one out on GitHub.
///
/// Pure logic over an injected `http` client, like `core/innertube`: the
/// installed version, the cache directory and the network all arrive from
/// outside so the whole decision can be tested against a recorded answer.
/// Installing is somebody else's job — this one only knows what exists and
/// how to bring the file down.
///
/// Nothing here throws. A tunnel, a rate limit, a release with no APK and a
/// body that is not JSON are the same kind of event as a shelf the network
/// refuses in `getChildren`: they mean "no news", and [failed] tells the sheet
/// whether the silence was an answer or a failure to ask.
class Updates extends ChangeNotifier {
  Updates({
    http.Client? httpClient,
    Directory? directory,
    Uri? endpoint,
    AppVersion? installed,
  })  : _http = httpClient ?? http.Client(),
        _directory = directory,
        _endpoint = endpoint ?? _releasesEndpoint,
        _installed = installed;

  static final _releasesEndpoint = Uri.parse(
    'https://api.github.com/repos/duvanherfi/tunebox/releases/latest',
  );

  /// `tunebox-0.1.4+5.apk` — the build number rides in the file name because a
  /// GitHub release has nowhere else to put it.
  static final _buildInName = RegExp(r'\+(\d+)\.apk$');

  final http.Client _http;
  final Uri _endpoint;

  Directory? _directory;
  AppVersion? _installed;
  Release? _available;
  double? _progress;
  bool _failed = false;

  /// The build installed on this device. Null until [load].
  AppVersion? get installed => _installed;

  /// The release worth offering, if the last check found one.
  Release? get available => _available;

  /// Fraction of the APK already on disk, or null when nothing is downloading.
  double? get progress => _progress;

  /// Whether the last check or download could not be completed. An automatic
  /// check ignores this; a sheet the user opened on purpose says so.
  bool get failed => _failed;

  /// Reads the installed version and clears anything an earlier run left in
  /// the cache — an APK is worth keeping only until the installer has read it.
  Future<void> load() async {
    _installed ??= await _readInstalled();
    await _clearCache();
  }

  /// Asks GitHub for the latest release and answers with it when it beats the
  /// installed build. Never throws, never proposes a downgrade.
  Future<Release?> check() async {
    _failed = false;
    Release? found;
    try {
      final response = await _http.get(
        _endpoint,
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
        },
      );
      if (response.statusCode >= 400) throw const _NoNews();
      found = _parse(utf8.decode(response.bodyBytes));
    } catch (_) {
      _failed = true;
    }

    final installed = _installed;
    _available =
        found != null && installed != null && _beats(found, installed)
            ? found
            : null;
    notifyListeners();
    return _available;
  }

  /// Brings the APK down to the cache directory, reporting progress as it
  /// goes. Answers null — and raises [failed] — if it did not arrive whole.
  Future<File?> download(Release release) async {
    _failed = false;
    _progress = 0;
    notifyListeners();

    final directory = await _resolve();
    final name = Uri.decodeComponent(release.url.pathSegments.last);
    final file = File('${directory.path}/$name');
    final partial = File('${file.path}.part');
    final sink = partial.openWrite();
    try {
      final response = await _http.send(http.Request('GET', release.url));
      if (response.statusCode >= 400) {
        throw HttpException('${response.statusCode}', uri: release.url);
      }

      // The release told us the size; the response may not, and a download
      // with no denominator would report progress it cannot know.
      final total = response.contentLength ?? release.size;
      var written = 0;
      await for (final chunk in response.stream) {
        sink.add(chunk);
        written += chunk.length;
        if (total > 0) {
          _progress = (written / total).clamp(0.0, 1.0);
          notifyListeners();
        }
      }
      await sink.close();

      // Renamed only once whole, so a broken transfer is never handed to the
      // installer as an APK.
      return await partial.rename(file.path);
    } catch (_) {
      await sink.close();
      if (partial.existsSync()) await partial.delete();
      _failed = true;
      return null;
    } finally {
      _progress = null;
      notifyListeners();
    }
  }

  Release? _parse(String body) {
    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) throw const _NoNews();

    final tag = (json['tag_name'] as String?) ?? '';
    final version = tag.startsWith('v') ? tag.substring(1) : tag;
    if (version.isEmpty) throw const _NoNews();

    final assets = (json['assets'] as List?) ?? const [];
    final asset = assets.whereType<Map<String, dynamic>>().firstWhere(
          (asset) => ((asset['name'] as String?) ?? '').endsWith('.apk'),
          orElse: () => throw const _NoNews(),
        );
    final url = asset['browser_download_url'] as String?;
    if (url == null) throw const _NoNews();

    final build = _buildInName.firstMatch(asset['name'] as String);
    return Release(
      version: version,
      build: build == null ? null : int.parse(build.group(1)!),
      notes: ((json['body'] as String?) ?? '').trim(),
      url: Uri.parse(url),
      size: (asset['size'] as num?)?.toInt() ?? 0,
    );
  }

  /// Android installs by build number, so that is what decides — and only
  /// when the asset name gave one up does the version name get a say.
  bool _beats(Release release, AppVersion installed) =>
      release.build != null
          ? release.build! > installed.build
          : _compare(release.version, installed.name) > 0;

  static int _compare(String left, String right) {
    final a = _numbers(left);
    final b = _numbers(right);
    for (var i = 0; i < 3; i++) {
      final difference = a[i].compareTo(b[i]);
      if (difference != 0) return difference;
    }
    return 0;
  }

  /// Major, minor and patch, with anything else in the string ignored: a tag
  /// this app cannot read is not a reason to offer an install.
  static List<int> _numbers(String version) {
    final parts = version
        .split('.')
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0)
        .toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts;
  }

  Future<AppVersion> _readInstalled() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(
      name: info.version,
      build: int.tryParse(info.buildNumber) ?? 0,
    );
  }

  Future<void> _clearCache() async {
    final directory = await _resolve();
    for (final entity in directory.listSync()) {
      if (entity is File &&
          (entity.path.endsWith('.apk') || entity.path.endsWith('.part'))) {
        try {
          await entity.delete();
        } catch (_) {
          // A file the system still holds open is not worth an error.
        }
      }
    }
  }

  Future<Directory> _resolve() async {
    return _directory ??= await () async {
      final directory = Directory(
        '${(await getTemporaryDirectory()).path}/updates',
      );
      await directory.create(recursive: true);
      return directory;
    }();
  }
}

/// There is nothing to offer. Thrown inside, never out.
class _NoNews implements Exception {
  const _NoNews();
}
