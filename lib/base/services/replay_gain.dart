import 'dart:math' as math;

import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

class ReplayGainResult {
  final double gainDb;
  final double? peak;
  final ReplayGainMode? source;

  const ReplayGainResult(this.gainDb, this.peak, this.source);
}

ReplayGainResult replayGainFor(MyAudioMetadata song, ReplayGainMode mode) {
  if (mode == ReplayGainMode.off) {
    return const ReplayGainResult(0, null, null);
  }
  final order = mode == ReplayGainMode.track
      ? const [ReplayGainMode.track, ReplayGainMode.album]
      : const [ReplayGainMode.album, ReplayGainMode.track];
  for (final source in order) {
    final gain = source == ReplayGainMode.track
        ? song.replayGainTrackGainDb
        : song.replayGainAlbumGainDb;
    if (gain == null || !gain.isFinite) continue;
    final rawPeak = source == ReplayGainMode.track
        ? song.replayGainTrackPeak
        : song.replayGainAlbumPeak;
    final peak = rawPeak != null && rawPeak.isFinite && rawPeak > 0
        ? rawPeak
        : null;
    final limitedGain = peak == null
        ? gain
        : math.min(gain, -20 * math.log(peak) / math.ln10);
    return ReplayGainResult(limitedGain, peak, source);
  }
  return const ReplayGainResult(0, null, null);
}

double dbToLinear(double db) => math.pow(10, db / 20).toDouble();

double replayGainWithinOutputHeadroom(double gainDb, double userLinearGain) {
  if (userLinearGain <= 0) return gainDb;
  final headroomDb = -20 * math.log(userLinearGain) / math.ln10;
  return math.min(gainDb, headroomDb);
}
