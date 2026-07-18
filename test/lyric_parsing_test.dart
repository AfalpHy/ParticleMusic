import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/services/lyric.dart';

const _noLyrics = 'no lyrics';
const _parseFailed = 'parse failed';

ParsedLyrics parse(List<String> lines, {Duration? songDuration}) {
  final result = ParsedLyrics();
  applyLrcParsing(
    result,
    lines,
    noLyricsMessage: _noLyrics,
    parseFailedMessage: _parseFailed,
    songDuration: songDuration,
  );
  return result;
}

void main() {
  group('applyLrcParsing', () {
    test('falls back to noLyricsMessage when there are no lines', () {
      final result = parse([]);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _noLyrics);
      expect(result.isKaraoke, isFalse);
    });

    test('falls back to noLyricsMessage when all lines are empty strings', () {
      final result = parse(['', '', '']);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _noLyrics);
    });

    test('falls back to parseFailedMessage for whitespace-only lines '
        '(only exactly-empty strings are filtered before parsing)', () {
      final result = parse(['   ', '\t']);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, _parseFailed);
    });

    test(
      'falls back to parseFailedMessage when no line matches the LRC format',
      () {
        final result = parse(['just plain text', 'no timestamps here']);
        expect(result.lines, hasLength(1));
        expect(result.lines.first.text, _parseFailed);
      },
    );

    test('parses plain (non-karaoke) LRC lines in order', () {
      final result = parse(['[00:01.000]First line', '[00:05.500]Second line']);

      expect(result.isKaraoke, isFalse);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].start, Duration(seconds: 1));
      expect(result.lines[0].text, 'First line');
      expect(result.lines[1].start, Duration(milliseconds: 5500));
      expect(result.lines[1].text, 'Second line');
    });

    test(
      'backfills the previous line\'s end time from the next line start',
      () {
        final result = parse([
          '[00:01.000]First line',
          '[00:05.000]Second line',
        ]);

        expect(result.lines[0].tokens.single.end, Duration(seconds: 5));
      },
    );

    test('detects karaoke lines (multiple timed tokens per line)', () {
      final result = parse(['[00:01.000]He[00:01.500]llo [00:02.000]world']);

      expect(result.isKaraoke, isTrue);
      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello world');
      expect(result.lines.first.tokens, hasLength(3));
      expect(result.lines.first.tokens[0].text, 'He');
      expect(result.lines.first.tokens[0].end, Duration(milliseconds: 1500));
      expect(result.lines.first.tokens[1].text, 'llo ');
      expect(result.lines.first.tokens[1].end, Duration(seconds: 2));
      expect(result.lines.first.tokens[2].text, 'world');
    });

    test('treats a second line at the same timestamp as a translation', () {
      final result = parse([
        '[00:01.000]Hello world',
        '[00:01.000]你好世界',
        '[00:05.000]Next line',
      ]);

      expect(result.lines, hasLength(2));
      expect(result.lines[0].text, 'Hello world');
      expect(result.lines[0].translates, ['你好世界']);
    });

    test('supports angle-bracket timestamps as well as square brackets', () {
      final result = parse(['<00:01.00>Hello']);

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Hello');
    });

    test(
      'sets the final token\'s end time to the song duration when nothing follows',
      () {
        final result = parse([
          '[00:01.000]Only line',
        ], songDuration: Duration(minutes: 3));

        expect(result.lines.single.tokens.single.end, Duration(minutes: 3));
      },
    );

    test('ignores lines whose only token is blank', () {
      final result = parse(['[00:01.000]   ', '[00:02.000]Real line']);

      expect(result.lines, hasLength(1));
      expect(result.lines.first.text, 'Real line');
    });
  });
}
