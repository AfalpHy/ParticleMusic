import 'dart:math' as math;

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

class ReplayGainResult {
  final double gainDb;
  final double? peak;
  final ReplayGainMode? source;

  const ReplayGainResult(this.gainDb, this.peak, this.source);
}

class SafeOutputGainTransition {
  final double appliedGain;
  final double adjustmentDb;
  final bool needsRamp;

  const SafeOutputGainTransition(
    this.appliedGain,
    this.adjustmentDb,
    this.needsRamp,
  );
}

SafeOutputGainTransition safeOutputGainTransition({
  required double? appliedGain,
  required double userGain,
  required double adjustmentDb,
  double maxIncrease = 0.02,
}) {
  final safeUserGain = userGain.clamp(0.0, 1.0).toDouble();
  final targetGain = (safeUserGain * dbToLinear(adjustmentDb))
      .clamp(0.0, 1.0)
      .toDouble();
  final currentGain = appliedGain?.clamp(0.0, 1.0).toDouble();
  final nextGain = currentGain == null || targetGain <= currentGain
      ? targetGain
      : math.min(
          targetGain,
          currentGain + maxIncrease.clamp(0.0, 1.0).toDouble(),
        );
  final appliedAdjustmentDb = safeUserGain <= 0 || nextGain <= 0
      ? adjustmentDb
      : 20 * math.log(nextGain / safeUserGain) / math.ln10;
  return SafeOutputGainTransition(
    nextGain,
    appliedAdjustmentDb,
    nextGain + 0.000001 < targetGain,
  );
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

ReplayGainResult? replayGainForMetadataUpdate({
  required MyAudioMetadata? currentSong,
  required String updatedSongId,
  required ReplayGainMode mode,
}) {
  if (currentSong == null || currentSong.id != updatedSongId) {
    return null;
  }
  return replayGainFor(currentSong, mode);
}

bool supplementReplayGainMetadata(
  MyAudioMetadata song,
  AudioMetadata metadata,
) {
  return supplementReplayGainValues(
    song,
    trackGain: metadata.replayGainTrackGainDb,
    trackPeak: metadata.replayGainTrackPeak,
    albumGain: metadata.replayGainAlbumGainDb,
    albumPeak: metadata.replayGainAlbumPeak,
  );
}

bool supplementReplayGainValues(
  MyAudioMetadata song, {
  double? trackGain,
  double? trackPeak,
  double? albumGain,
  double? albumPeak,
}) {
  final supplementedTrackGain =
      song.replayGainTrackGainDb == null &&
          trackGain != null &&
          trackGain.isFinite
      ? trackGain
      : null;
  final supplementedTrackPeak =
      song.replayGainTrackPeak == null &&
          trackPeak != null &&
          trackPeak.isFinite &&
          trackPeak > 0
      ? trackPeak
      : null;
  final supplementedAlbumGain =
      song.replayGainAlbumGainDb == null &&
          albumGain != null &&
          albumGain.isFinite
      ? albumGain
      : null;
  final supplementedAlbumPeak =
      song.replayGainAlbumPeak == null &&
          albumPeak != null &&
          albumPeak.isFinite &&
          albumPeak > 0
      ? albumPeak
      : null;
  if (supplementedTrackGain == null &&
      supplementedTrackPeak == null &&
      supplementedAlbumGain == null &&
      supplementedAlbumPeak == null) {
    return false;
  }
  song.replayGainTrackGainDb ??= supplementedTrackGain;
  song.replayGainTrackPeak ??= supplementedTrackPeak;
  song.replayGainAlbumGainDb ??= supplementedAlbumGain;
  song.replayGainAlbumPeak ??= supplementedAlbumPeak;
  return true;
}

double dbToLinear(double db) {
  if (db.isNaN) return 1;
  if (db == double.negativeInfinity) return 0;
  if (db == double.infinity) return double.maxFinite;
  final gain = math.pow(10, db / 20).toDouble();
  return gain.isInfinite ? double.maxFinite : gain;
}

double replayGainWithinOutputHeadroom(double gainDb, double userLinearGain) {
  if (userLinearGain <= 0) return gainDb;
  final headroomDb = -20 * math.log(userLinearGain) / math.ln10;
  return math.min(gainDb, headroomDb);
}

double usbUserVolumeFromHardwareGain(
  int actualGainQ16,
  double replayGainDb,
  int dsdGainCompensationDb,
) {
  final actualGain = (actualGainQ16 / 65536).clamp(0.0, 1.0).toDouble();
  if (actualGain <= 0) return 0;
  final factor = dbToLinear(replayGainDb + dsdGainCompensationDb);
  final baseGain = factor > 0 ? actualGain / factor : double.infinity;
  final safeBaseGain = baseGain.isNaN
      ? actualGain
      : baseGain.clamp(0.0, 1.0).toDouble();
  final volume = math.pow(safeBaseGain, 2 / 3).toDouble();
  return volume.isFinite ? volume.clamp(0.0, 1.0).toDouble() : 0;
}
