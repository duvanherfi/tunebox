import 'package:flutter_test/flutter_test.dart';
import 'package:tunebox/data/models/song.dart';

void main() {
  group('thumbnailAt', () {
    test('rewrites the box a track cover carries', () {
      expect(
        thumbnailAt(
          'https://lh3.googleusercontent.com/abc=w544-h544-l90-rj',
          156,
        ),
        'https://lh3.googleusercontent.com/abc=w156-h156-l90-rj',
      );
    });

    test('rewrites the side a portrait carries', () {
      expect(
        thumbnailAt(
          'https://yt3.googleusercontent.com/abc=s1200-c-k-no-rj',
          144,
        ),
        'https://yt3.googleusercontent.com/abc=s144-c-k-no-rj',
      );
    });

    // The two shapes never appear together, and a `w`/`h` box is the one that
    // describes artwork, so it wins where something carries both.
    test('prefers the box when a URL somehow carries both', () {
      expect(
        thumbnailAt('https://example.com/a=w544-h544=s1200', 64),
        'https://example.com/a=w64-h64=s1200',
      );
    });

    test('leaves a URL with no size of its own alone', () {
      const plain = 'https://example.com/cover.jpg';
      expect(thumbnailAt(plain, 128), plain);
    });

    // A local file is drawn through the same widget as anything else, and it
    // has no size to ask for.
    test('leaves a file path alone', () {
      const path = '/storage/emulated/0/Music/cover.png';
      expect(thumbnailAt(path, 96), path);
    });
  });

  group('thumbnailBucket', () {
    test('rounds up to the next power of two', () {
      expect(thumbnailBucket(150), 256);
      expect(thumbnailBucket(256), 256);
      expect(thumbnailBucket(257), 512);
    });

    test(
      'never asks for less than a small thumbnail or more than a large one',
      () {
        expect(thumbnailBucket(0), 64);
        expect(thumbnailBucket(10000), 2048);
      },
    );

    // The player's cover shrinks from about 1260 pixels to the bar's size in
    // one animation; asking for each of those sizes is what froze the app.
    test('an animation across the whole range asks for a handful of sizes', () {
      final sizes = {for (var p = 150.0; p <= 1260; p += 1) thumbnailBucket(p)};
      expect(sizes.length, lessThanOrEqualTo(4));
    });
  });
}
