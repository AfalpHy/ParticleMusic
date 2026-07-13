import 'dart:io';
import 'dart:math' as math;

import 'package:audio_tags_lofty/audio_tags_lofty.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/replay_gain.dart';
import 'package:sylvakru/base/services/usb_audio_preferences.dart';

void main() {
  late Directory appSupportDirectory;

  setUpAll(() async {
    appSupportDirectory = await Directory.systemTemp.createTemp(
      'replay_gain_test',
    );
    app.appSupportDir = appSupportDirectory;
  });

  tearDownAll(() async {
    await appSupportDirectory.delete(recursive: true);
  });

  MyAudioMetadata metadata({
    double? trackGain,
    double? trackPeak,
    double? albumGain,
    double? albumPeak,
  }) {
    return MyAudioMetadata(
      AudioMetadata(
        replayGainTrackGainDb: trackGain,
        replayGainTrackPeak: trackPeak,
        replayGainAlbumGainDb: albumGain,
        replayGainAlbumPeak: albumPeak,
      ),
      id: 'replay-gain-test',
    );
  }

  test('关闭 ReplayGain 时返回零增益且没有来源', () {
    final result = replayGainFor(
      metadata(trackGain: -6, trackPeak: 0.9),
      ReplayGainMode.off,
    );

    expect(result.gainDb, 0);
    expect(result.peak, isNull);
    expect(result.source, isNull);
  });

  test('音轨模式优先使用音轨增益和同组峰值', () {
    final result = replayGainFor(
      metadata(trackGain: -6, trackPeak: 0.9, albumGain: -3, albumPeak: 0.8),
      ReplayGainMode.track,
    );

    expect(result.gainDb, -6);
    expect(result.peak, 0.9);
    expect(result.source, ReplayGainMode.track);
  });

  test('音轨增益缺失时回退到专辑增益和同组峰值', () {
    final result = replayGainFor(
      metadata(trackPeak: 0.7, albumGain: -4, albumPeak: 0.8),
      ReplayGainMode.track,
    );

    expect(result.gainDb, -4);
    expect(result.peak, 0.8);
    expect(result.source, ReplayGainMode.album);
  });

  test('专辑模式优先专辑并在缺失时反向回退音轨', () {
    final preferred = replayGainFor(
      metadata(trackGain: -5, trackPeak: 0.9, albumGain: -3, albumPeak: 0.8),
      ReplayGainMode.album,
    );
    final fallback = replayGainFor(
      metadata(trackGain: -5, trackPeak: 0.9, albumPeak: 0.8),
      ReplayGainMode.album,
    );

    expect(preferred.source, ReplayGainMode.album);
    expect(preferred.gainDb, -3);
    expect(preferred.peak, 0.8);
    expect(fallback.source, ReplayGainMode.track);
    expect(fallback.gainDb, -5);
    expect(fallback.peak, 0.9);
  });

  test('首选增益存在但峰值缺失时不借用另一组峰值', () {
    final result = replayGainFor(
      metadata(trackGain: 3, albumGain: -4, albumPeak: 2),
      ReplayGainMode.track,
    );

    expect(result.gainDb, 3);
    expect(result.peak, isNull);
    expect(result.source, ReplayGainMode.track);
  });

  test('忽略非有限增益并回退到另一组', () {
    for (final invalidGain in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final result = replayGainFor(
        metadata(trackGain: invalidGain, albumGain: -4, albumPeak: 0.8),
        ReplayGainMode.track,
      );

      expect(result.gainDb, -4);
      expect(result.source, ReplayGainMode.album);
    }
  });

  test('两组都没有有效增益时返回零增益且没有来源', () {
    final result = replayGainFor(
      metadata(trackGain: double.nan, albumGain: double.infinity),
      ReplayGainMode.track,
    );

    expect(result.gainDb, 0);
    expect(result.peak, isNull);
    expect(result.source, isNull);
  });

  test('元数据更新只为当前歌曲重新计算 ReplayGain', () {
    final currentSong = metadata(trackGain: -6, trackPeak: 0.9);

    final refreshed = replayGainForMetadataUpdate(
      currentSong: currentSong,
      updatedSongId: currentSong.id,
      mode: ReplayGainMode.track,
    );
    final ignored = replayGainForMetadataUpdate(
      currentSong: currentSong,
      updatedSongId: 'another-song',
      mode: ReplayGainMode.track,
    );

    expect(refreshed, isNotNull);
    expect(refreshed!.gainDb, -6);
    expect(refreshed.source, ReplayGainMode.track);
    expect(ignored, isNull);
  });

  test('缓存标签只补齐缺失的有效 ReplayGain 字段并报告变化', () {
    final song = metadata(trackGain: -3.5);
    final cachedMetadata = AudioMetadata(
      replayGainTrackGainDb: -7,
      replayGainTrackPeak: 0.9,
      replayGainAlbumGainDb: -5.25,
      replayGainAlbumPeak: 1.1,
    );

    expect(supplementReplayGainMetadata(song, cachedMetadata), isTrue);
    expect(song.replayGainTrackGainDb, -3.5);
    expect(song.replayGainTrackPeak, 0.9);
    expect(song.replayGainAlbumGainDb, -5.25);
    expect(song.replayGainAlbumPeak, 1.1);
    expect(supplementReplayGainMetadata(song, cachedMetadata), isFalse);
  });

  test('缓存标签没有有效 ReplayGain 字段时不报告变化', () {
    final song = metadata();

    expect(
      supplementReplayGainMetadata(
        song,
        AudioMetadata(
          replayGainTrackGainDb: double.nan,
          replayGainTrackPeak: 0,
          replayGainAlbumGainDb: double.infinity,
          replayGainAlbumPeak: -1,
        ),
      ),
      isFalse,
    );
    expect(song.replayGainTrackGainDb, isNull);
    expect(song.replayGainTrackPeak, isNull);
    expect(song.replayGainAlbumGainDb, isNull);
    expect(song.replayGainAlbumPeak, isNull);
  });

  test('忽略非正或非有限峰值', () {
    for (final invalidPeak in [
      0.0,
      -1.0,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final result = replayGainFor(
        metadata(trackGain: 2, trackPeak: invalidPeak),
        ReplayGainMode.track,
      );

      expect(result.gainDb, 2);
      expect(result.peak, isNull);
    }
  });

  test('有效峰值按峰值上限限制正增益', () {
    final result = replayGainFor(
      metadata(trackGain: 6, trackPeak: 0.8),
      ReplayGainMode.track,
    );

    expect(result.gainDb, closeTo(-20 * log10(0.8), 0.000001));
    expect(result.peak, 0.8);
  });

  test('没有峰值时结合用户线性增益限制最终输出不超过一', () {
    const userLinearGain = 0.8;
    final limitedGain = replayGainWithinOutputHeadroom(6, userLinearGain);

    expect(userLinearGain * dbToLinear(limitedGain), closeTo(1, 0.000001));
  });

  test('零用户增益不限制 ReplayGain', () {
    expect(replayGainWithinOutputHeadroom(6, 0), 6);
  });

  test('分贝正确转换为线性增益', () {
    expect(dbToLinear(0), 1);
    expect(dbToLinear(6), closeTo(1.995262, 0.000001));
    expect(dbToLinear(-6), closeTo(0.501187, 0.000001));
  });

  test('极端有限正分贝转换后保持有限', () {
    final linearGain = dbToLinear(double.maxFinite);
    final mutedGain = 0.0 * linearGain;

    expect(linearGain, double.maxFinite);
    expect(linearGain.isFinite, isTrue);
    expect(mutedGain, 0);
    expect(mutedGain.isFinite, isTrue);
  });

  test('非有限分贝转换为安全的有限线性增益', () {
    for (final entry in {
      double.nan: 1.0,
      double.infinity: double.maxFinite,
      double.negativeInfinity: 0.0,
    }.entries) {
      final linearGain = dbToLinear(entry.key);
      final mutedGain = 0.0 * linearGain;

      expect(linearGain, entry.value);
      expect(linearGain.isFinite, isTrue);
      expect(mutedGain, 0);
      expect(mutedGain.isFinite, isTrue);
    }
  });

  test('USB硬件实际增益反推用户音量并移除增益偏移', () {
    int actualGain(double volume, double offsetDb) =>
        (usbExclusiveDigitalVolumeGain(volume) * dbToLinear(offsetDb) * 65536)
            .round();

    expect(usbUserVolumeFromHardwareGain(0, 0, 0), 0);
    expect(
      usbUserVolumeFromHardwareGain(actualGain(0.5, 0), 0, 0),
      closeTo(0.5, 0.0001),
    );
    expect(
      usbUserVolumeFromHardwareGain(actualGain(0.4, 6), 6, 0),
      closeTo(0.4, 0.0001),
    );
    expect(
      usbUserVolumeFromHardwareGain(actualGain(0.8, -6), -6, 0),
      closeTo(0.8, 0.0001),
    );
    expect(
      usbUserVolumeFromHardwareGain(actualGain(0.5, 3), 0, 3),
      closeTo(0.5, 0.0001),
    );
    expect(usbUserVolumeFromHardwareGain(999999, 0, 0), 1);
    expect(usbUserVolumeFromHardwareGain(-1, 0, 0), 0);
    for (final offset in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ]) {
      final value = usbUserVolumeFromHardwareGain(32768, offset, 0);
      expect(value.isFinite, isTrue);
      expect(value, inInclusiveRange(0, 1));
    }
  });
}

// 测试直接用换底公式表达规范中的峰值限制。
double log10(double value) => math.log(value) / math.ln10;
