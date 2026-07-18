import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';

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

  test('Navidrome getSong 返回当前歌曲的 ReplayGain', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      expect(request.uri.path, '/rest/getSong.view');
      expect(request.uri.queryParameters['id'], 'song-id');
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'subsonic-response': {
            'status': 'ok',
            'song': {
              'id': 'song-id',
              'title': 'Song',
              'replayGain': {'trackGain': -7.25, 'trackPeak': 0.91},
            },
          },
        }),
      );
      await request.response.close();
    });
    final client = NavidromeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );

    final songMap = await client.getSong('song-id');
    final song = MyAudioMetadata.fromOpenSonicMap(
      songMap!,
      app.SourceType.navidrome,
    );

    expect(song.replayGainTrackGainDb, -7.25);
    expect(song.replayGainTrackPeak, 0.91);
  });
}
