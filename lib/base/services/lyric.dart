import 'dart:io';
import 'dart:ui';

import 'package:charset/charset.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/l10n/generated/app_localizations_en.dart';

class LyricToken {
  final Duration start;
  final String text;
  Duration? end;

  LyricToken(this.start, this.text, [this.end]);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'end': end?.inMilliseconds,
      'text': text,
    };
  }

  factory LyricToken.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);

    return LyricToken(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      map['end'] != null ? Duration(milliseconds: map['end'] as int) : null,
    );
  }
}

class LyricLine {
  final Duration start;
  final String text;
  final List<LyricToken> tokens;

  List<String> translates = [];

  LyricLine(this.start, this.text, this.tokens);

  Map<String, dynamic> toMap() {
    return {
      'start': start.inMilliseconds,
      'text': text,
      'tokens': tokens.map((t) => t.toMap()).toList(),
      'translates': translates,
    };
  }

  factory LyricLine.fromMap(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    final lyricLine = LyricLine(
      Duration(milliseconds: map['start'] as int),
      map['text'] as String,
      (map['tokens'] as List).map((e) => LyricToken.fromMap(e as Map)).toList(),
    );
    lyricLine.translates = List<String>.from(map['translates']);
    return lyricLine;
  }
}

class ParsedLyrics {
  bool isKaraoke = false;
  List<LyricLine> lines = [];
}

Duration parseTime(RegExpMatch m) {
  final min = int.parse(m.group(1)!);
  final sec = int.parse(m.group(2)!);
  final ms = int.parse(m.group(3)!.padRight(3, '0'));
  return Duration(minutes: min, seconds: sec, milliseconds: ms);
}

Future<void> setParsedLyrics(MyAudioMetadata song) async {
  if (song.parsedLyrics != null) {
    return;
  }
  ParsedLyrics result = ParsedLyrics();
  song.parsedLyrics = result;

  List<String> lines = [];
  late AppLocalizations l10n;

  if (localeNotifier.value != null) {
    l10n = lookupAppLocalizations(localeNotifier.value!);
  } else {
    try {
      l10n = lookupAppLocalizations(PlatformDispatcher.instance.locale);
    } catch (_) {
      l10n = AppLocalizationsEn();
    }
  }

  if (song.sourceType == .subsonic) {
    final lyrics = await subsonicClient!.getLyricsById(song.id);
    if (lyrics != null) {
      lines = lyrics.split(RegExp(r'[\n]'));
    }
  } else if (song.sourceType == .navidrome) {
    final lyrics = await navidromeClient!.getLyricsById(song.id);
    if (lyrics != null) {
      lines = lyrics.split(RegExp(r'[\n]'));
    }
  } else if (song.sourceType == .emby) {
    result.lines.add(LyricLine(Duration.zero, l10n.noLyrics, []));
    return;
  } else {
    if (song.lyrics == null || song.lyrics!.isEmpty) {
      String path = song.path!;
      path = "${path.substring(0, path.lastIndexOf('.'))}.lrc";

      late File lrcFile;
      if (song.sourceType == .webdav) {
        lrcFile = File('${tmpDir.path}/sylvakru_lyric');
        await webdavClient?.download(remotePath: path, localPath: lrcFile.path);
      } else {
        lrcFile = File(path);
      }
      if (lrcFile.existsSync()) {
        try {
          lines = await lrcFile.readAsLines();
        } catch (e) {
          logger.output(e.toString());
          try {
            lines = await lrcFile.readAsLines(encoding: gbk);
          } catch (e) {
            logger.output(e.toString());
          }
        }
      }
    } else {
      lines = song.lyrics!.split(RegExp(r'[\n]'));
    }
  }
  applyLrcParsing(
    result,
    lines,
    noLyricsMessage: l10n.noLyrics,
    parseFailedMessage: l10n.lyricsParseFailed,
    songDuration: song.duration,
  );
}

/// Fills in [result] from already-fetched raw LRC lines: parses word/line
/// timestamps, detects karaoke (multiple timed tokens per line) and
/// translation lines (a second line sharing the same timestamp as the one
/// before it), and falls back to [noLyricsMessage]/[parseFailedMessage]
/// placeholders when there's nothing to show. Split out from
/// [setParsedLyrics] so the parsing itself can be unit tested without a
/// network/file round trip.
void applyLrcParsing(
  ParsedLyrics result,
  List<String> rawLines, {
  required String noLyricsMessage,
  required String parseFailedMessage,
  Duration? songDuration,
}) {
  final lines = List<String>.from(rawLines)..removeWhere((e) => e.isEmpty);
  if (lines.isEmpty) {
    result.lines.add(LyricLine(Duration.zero, noLyricsMessage, []));
    return;
  }

  final lineTimeRegex = RegExp(r'^[\[<](\d{2}):(\d{2})[.:](\d{2,3})[\]>]');
  final wordRegex = RegExp(r'[\[<](\d{2}):(\d{2})[.:](\d{2,3})[\]>]([^\[<]*)');

  for (var line in lines) {
    final lineMatch = lineTimeRegex.firstMatch(line);
    if (lineMatch == null) continue;

    final lineStart = parseTime(lineMatch);

    final lastLyric = result.lines.isNotEmpty ? result.lines.last : null;
    bool isTranslate = lastLyric?.start == lineStart;

    if (lastLyric?.tokens.last.end == null && !isTranslate) {
      lastLyric?.tokens.last.end = lineStart;
    }

    final tokenMatches = wordRegex.allMatches(line);

    final tokens = <LyricToken>[];
    final textBuffer = StringBuffer();

    for (final match in tokenMatches) {
      final start = parseTime(match);
      final token = match.group(4)!;

      if (tokens.isNotEmpty) {
        tokens.last.end = start;
      }

      if (token.isNotEmpty) {
        tokens.add(LyricToken(start, token));
        textBuffer.write(token);
      }
    }
    if (tokens.isNotEmpty) {
      if (tokens.length == 1 && tokens[0].text.trim().isEmpty) {
        continue;
      }
      if (tokens.length > 1) {
        result.isKaraoke = true;
      }
      if (isTranslate) {
        lastLyric!.translates.add(textBuffer.toString());
      } else {
        result.lines.add(LyricLine(lineStart, textBuffer.toString(), tokens));
      }
    }
  }
  if (result.lines.isEmpty) {
    result.lines.add(LyricLine(Duration.zero, parseFailedMessage, []));
  } else {
    if (result.lines.last.tokens.last.end == null) {
      result.lines.last.tokens.last.end = songDuration;
    }
  }
}
