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
}

// 测试直接用换底公式表达规范中的峰值限制。
double log10(double value) => math.log(value) / math.ln10;
