import 'package:sylvakru/base/audio_handler.dart';
import 'package:windows_taskbar/windows_taskbar.dart';

void setupTaskbar() async {
  await WindowsTaskbar.setThumbnailToolbar([
    ThumbnailToolbarButton(
      ThumbnailToolbarAssetIcon('assets/previous.ico'),
      'Previous',
      () {
        audioHandler.skipToPrevious();
      },
    ),

    ThumbnailToolbarButton(
      ThumbnailToolbarAssetIcon(
        isPlayingNotifier.value ? 'assets/pause.ico' : 'assets/play.ico',
      ),
      isPlayingNotifier.value ? 'Pause' : 'Play',
      () {
        audioHandler.togglePlay();
      },
    ),

    ThumbnailToolbarButton(
      ThumbnailToolbarAssetIcon('assets/next.ico'),
      'Next',
      () {
        audioHandler.skipToNext();
      },
    ),
  ]);
}
