import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart';
import 'package:sylvakru/base/audio_handler.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/lyric.dart';
import 'package:sylvakru/landscape_view/desktop_lyrics.dart';
import 'package:window_manager/window_manager.dart';

/// The desktop lyrics window runs in its own isolate with its own Flutter
/// engine, so it cannot see the main isolate's globals (currentSongNotifier,
/// isPlayingNotifier, etc.). Everything they need to agree on - the current
/// lyric line, play/pause state, playback controls - has to be pushed
/// explicitly across this platform channel.
extension WindowControllerExtension on WindowController {
  Future<void> desktopLyricsCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'window_center':
          return await windowManager.center();
        case 'window_close':
          return await windowManager.close();
        case 'update_lyric':
          getDesktopLyricFromMap(call.arguments);
          break;
        case 'update_style':
          applyDesktopLyricsStyleFromMap(call.arguments);
          break;
        case 'set_playing':
          isPlayingNotifier.value = call.arguments as bool;
          break;
        case 'unlock':
          await windowManager.setIgnoreMouseEvents(false);
          break;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  Future<void> mainCustomInitialize() async {
    return await setWindowMethodHandler((call) async {
      switch (call.method) {
        case 'hide_desktop_lyrics':
          lyricsWindowVisible = false;
          break;
        case 'skip_to_previous':
          audioHandler.skipToPrevious();
          break;
        case 'toggle_play':
          audioHandler.togglePlay();
          break;
        case 'skip_to_next':
          audioHandler.skipToNext();
          break;
        default:
          throw MissingPluginException('Not implemented: ${call.method}');
      }
    });
  }

  Future<void> center() => _safeInvoke('window_center');

  Future<void> close() => _safeInvoke('window_close');

  Future<void> updateLyric(
    Duration postion,
    LyricLine? lyricline,
    LyricLine? nextLyricline,
    bool isKaraoke,
  ) => _safeInvoke('update_lyric', {
    'position': postion.inMicroseconds,
    'lyric_line': lyricline?.toMap(),
    'next_lyric_line': nextLyricline?.toMap(),
    'isKaraoke': isKaraoke,
  });

  Future<void> sendPlaying(bool playing) => _safeInvoke('set_playing', playing);

  Future<void> updateStyle(Map<String, dynamic> style) =>
      _safeInvoke('update_style', style);

  Future<void> hideDesktopLyrics() => _safeInvoke('hide_desktop_lyrics');

  Future<void> skipToPrevious() => _safeInvoke('skip_to_previous');

  Future<void> togglePlay() => _safeInvoke('toggle_play');

  Future<void> skipToNext() => _safeInvoke('skip_to_next');

  Future<void> unlock() => _safeInvoke('unlock');

  /// The two windows are only loosely coupled: the lyrics window can be
  /// closed, still starting up, or briefly unresponsive, and none of that
  /// should ever be able to crash the caller (e.g. the position stream in
  /// audio_handler.dart fires many times per second). Swallow and log
  /// instead of letting a transient channel error propagate.
  Future<void> _safeInvoke(String method, [dynamic arguments]) async {
    try {
      await invokeMethod(method, arguments);
    } catch (e) {
      logger.output('desktop lyrics IPC "$method" failed: $e');
    }
  }
}
