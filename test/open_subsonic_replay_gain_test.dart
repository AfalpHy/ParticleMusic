import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/my_audio_metadata.dart';

void main() {
  late Directory appSupportDirectory;

  setUpAll(() async {
    appSupportDirectory = await Directory.systemTemp.createTemp(
      'open_subsonic_replay_gain_test',
    );
    app.appSupportDir = appSupportDirectory;
  });

  tearDownAll(() async {
    await appSupportDirectory.delete(recursive: true);
  });

  test('OpenSubsonic replayGain 兼容数值和带 dB 的字符串', () {
    final song = MyAudioMetadata.fromOpenSonicMap({
      'id': 'song-id',
      'title': 'Song',
      'replayGain': {
        'trackGain': ' -6.75 dB ',
        'trackPeak': 0.95,
        'albumGain': 1.25,
        'albumPeak': '1.10',
      },
    }, app.SourceType.navidrome);

    expect(song.replayGainTrackGainDb, -6.75);
    expect(song.replayGainTrackPeak, 0.95);
    expect(song.replayGainAlbumGainDb, 1.25);
    expect(song.replayGainAlbumPeak, 1.1);
  });

  test('OpenSubsonic replayGain 忽略非法值、非有限值和非正峰值', () {
    final song = MyAudioMetadata.fromOpenSonicMap({
      'id': 'invalid-song-id',
      'title': 'Invalid Song',
      'replayGain': {
        'trackGain': 'NaN dB',
        'trackPeak': 0,
        'albumGain': double.infinity,
        'albumPeak': '-1',
      },
    }, app.SourceType.subsonic);

    expect(song.replayGainTrackGainDb, isNull);
    expect(song.replayGainTrackPeak, isNull);
    expect(song.replayGainAlbumGainDb, isNull);
    expect(song.replayGainAlbumPeak, isNull);
  });
}
