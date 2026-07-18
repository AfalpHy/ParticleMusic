import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sylvakru/base/app.dart' as app;
import 'package:sylvakru/base/data/library.dart' deferred as library_data;
import 'package:sylvakru/base/my_audio_metadata.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';

Future<ServerSocket> _startSlowDownloadServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((socket) async {
    socket.add(
      ascii.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Length: 3\r\n'
            'Connection: close\r\n'
            '\r\n',
          ) +
          [1],
    );
    await socket.flush();
    await Future<void>.delayed(const Duration(seconds: 2));
    socket.add([2, 3]);
    await socket.close();
  });
  return server;
}

Future<ServerSocket> _startDroppedDownloadServer() async {
  final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((socket) async {
    socket.add(
      ascii.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Length: 4\r\n'
            'Connection: close\r\n'
            '\r\n',
          ) +
          [1, 2],
    );
    await socket.flush();
    socket.destroy();
  });
  return server;
}

class _TestNavidromeClient extends NavidromeClient {
  _TestNavidromeClient({required super.baseUrl})
    : super(username: 'user', password: 'password');

  void setReceiveTimeout(Duration timeout) {
    dio.options.receiveTimeout = timeout;
  }
}

void main() {
  late Directory appSupportDirectory;

  setUpAll(() async {
    appSupportDirectory = await Directory.systemTemp.createTemp(
      'sylvakru_app_support_test',
    );
    app.appSupportDir = appSupportDirectory;
    await logger.init();
  });

  tearDownAll(() async {
    await appSupportDirectory.delete(recursive: true);
  });

  test(
    'Navidrome download keeps waiting across a slow byte interval',
    () async {
      final server = await _startSlowDownloadServer();
      final directory = await Directory.systemTemp.createTemp(
        'sylvakru_cache_test',
      );
      addTearDown(() async {
        await server.close();
        await directory.delete(recursive: true);
      });

      final client = _TestNavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
      );
      client.setReceiveTimeout(const Duration(seconds: 1));

      final completed = await client.downloadSong(
        songId: 'song-id',
        savePath: '${directory.path}/song.part',
      );

      expect(completed, isTrue);
      expect(await File('${directory.path}/song.part').readAsBytes(), [
        1,
        2,
        3,
      ]);
    },
  );

  test('WebDAV download keeps waiting across a slow byte interval', () async {
    final server = await _startSlowDownloadServer();
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });

    final client = WebDavClient(
      baseUrl: 'http://${server.address.address}:${server.port}/library',
      username: 'user',
      password: 'password',
    );
    client.dio.options.receiveTimeout = const Duration(seconds: 1);

    final completed = await client.download(
      remotePath: '/song.flac',
      localPath: '${directory.path}/song.part',
    );

    expect(completed, isTrue);
    expect(await File('${directory.path}/song.part').readAsBytes(), [1, 2, 3]);
  });

  test('Emby download keeps waiting across a slow byte interval', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });

    server.listen((socket) async {
      socket.add(
        ascii.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: 3\r\n'
              'Connection: close\r\n'
              '\r\n',
            ) +
            [1],
      );
      await socket.flush();
      await Future<void>.delayed(const Duration(seconds: 2));
      socket.add([2, 3]);
      await socket.close();
    });

    final client = EmbyClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );
    client.dio.options.receiveTimeout = const Duration(seconds: 1);

    final completed = await client.downloadSong(
      itemId: 'song-id',
      savePath: '${directory.path}/song.part',
    );

    expect(completed, isTrue);
    expect(await File('${directory.path}/song.part').readAsBytes(), [1, 2, 3]);
  });

  test('Navidrome keeps a part file when download is interrupted', () async {
    final server = await _startDroppedDownloadServer();
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });
    final partPath = '${directory.path}/song.part';
    final client = NavidromeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );

    final completed = await client.downloadSong(
      songId: 'song-id',
      savePath: partPath,
    );

    expect(completed, isFalse);
    expect(File(partPath).existsSync(), isTrue);
  });

  test('WebDAV keeps a part file when download is interrupted', () async {
    final server = await _startDroppedDownloadServer();
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });
    final partPath = '${directory.path}/song.part';
    final client = WebDavClient(
      baseUrl: 'http://${server.address.address}:${server.port}/library',
      username: 'user',
      password: 'password',
    );

    final completed = await client.download(
      remotePath: '/song.flac',
      localPath: partPath,
    );

    expect(completed, isFalse);
    expect(File(partPath).existsSync(), isTrue);
  });

  test('Emby keeps a part file when download is interrupted', () async {
    final server = await _startDroppedDownloadServer();
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });
    final partPath = '${directory.path}/song.part';
    final client = EmbyClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );

    final completed = await client.downloadSong(
      itemId: 'song-id',
      savePath: partPath,
    );

    expect(completed, isFalse);
    expect(File(partPath).existsSync(), isTrue);
  });

  test('Navidrome cancellation keeps the part file', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final directory = await Directory.systemTemp.createTemp(
      'sylvakru_cache_test',
    );
    addTearDown(() async {
      await server.close();
      await directory.delete(recursive: true);
    });
    server.listen((socket) async {
      socket.add(
        ascii.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: 4\r\n'
              'Connection: close\r\n'
              '\r\n',
            ) +
            [1],
      );
      await socket.flush();
      await Future<void>.delayed(const Duration(seconds: 2));
      await socket.close();
    });
    final partPath = '${directory.path}/song.part';
    final cancelToken = CancelToken();
    final client = NavidromeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );

    final download = client.downloadSong(
      songId: 'song-id',
      savePath: partPath,
      cancelToken: cancelToken,
    );
    await Future<void>.delayed(const Duration(milliseconds: 100));
    cancelToken.cancel();

    expect(await download, isFalse);
    expect(File(partPath).existsSync(), isTrue);
  });

  test('incomplete cloud download remains a part file', () async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close();
    });

    server.listen((socket) async {
      socket.add(
        ascii.encode(
              'HTTP/1.1 200 OK\r\n'
              'Content-Length: 4\r\n'
              'Connection: close\r\n'
              '\r\n',
            ) +
            [1, 2],
      );
      await socket.flush();
      socket.destroy();
    });
    await library_data.loadLibrary();
    navidromeClient = NavidromeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );
    final song = MyAudioMetadata.fromOpenSonicMap({
      'id': 'song-id',
      'title': 'Song',
      'suffix': 'flac',
    }, app.SourceType.navidrome);

    final library = library_data.Library();
    final download = library.tryAddCache(song);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    library.cancelCacheDownload(song);
    await download;

    expect(song.cacheExist, isFalse);
    expect(File(song.cachePath!).existsSync(), isFalse);
    expect(File('${song.cachePath!}.part').existsSync(), isTrue);
  });

  test(
    'cloud cache retries a dropped download without promoting the part file',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      var requestCount = 0;

      server.listen((socket) async {
        requestCount++;
        socket.add(
          ascii.encode(
                'HTTP/1.1 200 OK\r\n'
                'Content-Length: 3\r\n'
                'Connection: close\r\n'
                '\r\n',
              ) +
              (requestCount == 1 ? [1] : [1, 2, 3]),
        );
        await socket.flush();
        if (requestCount == 1) {
          socket.destroy();
        } else {
          await socket.close();
        }
      });

      navidromeClient = NavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        username: 'user',
        password: 'password',
      );
      final song = MyAudioMetadata.fromOpenSonicMap({
        'id': 'retry-song-id',
        'title': 'Retry Song',
        'suffix': 'flac',
      }, app.SourceType.navidrome);

      await library_data.Library().tryAddCache(song);

      expect(requestCount, 2);
      expect(song.cacheExist, isTrue);
      expect(await File(song.cachePath!).readAsBytes(), [1, 2, 3]);
    },
  );

  test(
    'cloud cache supplements missing ReplayGain without replacing API values',
    () async {
      final dsd = _buildDsfWithReplayGain();
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      server.listen((socket) async {
        socket.add(
          ascii.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Length: ${dsd.length}\r\n'
            'Connection: close\r\n'
            '\r\n',
          ),
        );
        socket.add(dsd);
        await socket.flush();
        await socket.close();
      });

      await library_data.loadLibrary();
      navidromeClient = NavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        username: 'user',
        password: 'password',
      );
      final song = MyAudioMetadata.fromOpenSonicMap({
        'id': 'replay-gain-song-id',
        'title': 'ReplayGain Song',
        'suffix': 'dsf',
        'replayGain': {'trackGain': -3.5},
      }, app.SourceType.navidrome);

      await library_data.Library().tryAddCache(song);

      expect(song.cacheExist, isTrue);
      expect(song.replayGainTrackGainDb, -3.5);
      expect(song.replayGainTrackPeak, 0.9);
      expect(song.replayGainAlbumGainDb, -5.25);
      expect(song.replayGainAlbumPeak, 1.1);
    },
  );

  test(
    'existing cloud cache is scanned once to supplement ReplayGain',
    () async {
      await library_data.loadLibrary();
      final song = MyAudioMetadata.fromOpenSonicMap({
        'id': 'existing-replay-gain-cache',
        'title': 'Existing ReplayGain Cache',
        'suffix': 'dsf',
      }, app.SourceType.navidrome);
      final cacheFile = File(song.cachePath!);
      await cacheFile.parent.create(recursive: true);
      await cacheFile.writeAsBytes(_buildDsfWithReplayGain());
      song.cacheExist = true;

      final library = library_data.Library();
      await library.tryAddCache(song);

      expect(song.replayGainTrackGainDb, -7);
      expect(song.replayGainTrackPeak, 0.9);
      expect(song.replayGainAlbumGainDb, -5.25);
      expect(song.replayGainAlbumPeak, 1.1);
    },
  );

  test(
    'cloud cache does not publish ReplayGain when API values are complete',
    () async {
      final dsd = _buildDsfWithReplayGain();
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      server.listen((socket) async {
        socket.add(
          ascii.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Length: ${dsd.length}\r\n'
            'Connection: close\r\n'
            '\r\n',
          ),
        );
        socket.add(dsd);
        await socket.flush();
        await socket.close();
      });

      await library_data.loadLibrary();
      navidromeClient = NavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        username: 'user',
        password: 'password',
      );
      final song = MyAudioMetadata.fromOpenSonicMap({
        'id': 'complete-replay-gain-song-id',
        'title': 'Complete ReplayGain Song',
        'suffix': 'dsf',
        'replayGain': {
          'trackGain': -3.5,
          'trackPeak': 0.8,
          'albumGain': -4.5,
          'albumPeak': 0.7,
        },
      }, app.SourceType.navidrome);
      final library = library_data.Library();
      var eventCount = 0;
      library.replayGainMetadataChangedNotifier.addListener(() {
        eventCount++;
      });

      await library.tryAddCache(song);

      expect(song.replayGainTrackGainDb, -3.5);
      expect(song.replayGainTrackPeak, 0.8);
      expect(song.replayGainAlbumGainDb, -4.5);
      expect(song.replayGainAlbumPeak, 0.7);
      expect(eventCount, 0);
    },
  );

  test('ReplayGain metadata events can repeat for the same song', () async {
    await library_data.loadLibrary();
    final library = library_data.Library();
    final songIds = <String>[];
    library.replayGainMetadataChangedNotifier.addListener(() {
      final event = library.replayGainMetadataChangedNotifier.value;
      if (event != null) {
        songIds.add(event.songId);
      }
    });

    library.replayGainMetadataChangedNotifier.value =
        library_data.ReplayGainMetadataChangedEvent('same-song');
    library.replayGainMetadataChangedNotifier.value =
        library_data.ReplayGainMetadataChangedEvent('same-song');

    expect(songIds, ['same-song', 'same-song']);
  });

  test('播放前补齐 ReplayGain 不等待远端接口返回', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final requests = server.listen((_) {});
    addTearDown(() async {
      navidromeClient = null;
      await requests.cancel();
      await server.close(force: true);
    });

    await library_data.loadLibrary();
    navidromeClient = NavidromeClient(
      baseUrl: 'http://${server.address.address}:${server.port}',
      username: 'user',
      password: 'password',
    );
    final song = MyAudioMetadata.fromOpenSonicMap({
      'id': 'slow-replay-gain-song-id',
      'title': 'Slow ReplayGain Song',
      'suffix': 'flac',
    }, app.SourceType.navidrome);
    final library = library_data.Library();

    await library
        .supplementReplayGainForPlayback(song)
        .timeout(const Duration(milliseconds: 100));
  });

  test(
    'cloud cache remains available when metadata refresh cannot parse audio',
    () async {
      const bytes = [1, 2, 3, 4];
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close());
      server.listen((socket) async {
        socket.add(
          ascii.encode(
            'HTTP/1.1 200 OK\r\n'
            'Content-Length: ${bytes.length}\r\n'
            'Connection: close\r\n'
            '\r\n',
          ),
        );
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      });

      await library_data.loadLibrary();
      navidromeClient = NavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        username: 'user',
        password: 'password',
      );
      final song = MyAudioMetadata.fromOpenSonicMap({
        'id': 'invalid-metadata-song-id',
        'title': 'Invalid Metadata Song',
        'suffix': 'mp3',
      }, app.SourceType.navidrome);

      final library = library_data.Library();
      var eventCount = 0;
      library.replayGainMetadataChangedNotifier.addListener(() {
        eventCount++;
      });

      await library.tryAddCache(song);

      expect(song.cacheExist, isTrue);
      expect(File(song.cachePath!).existsSync(), isTrue);
      expect(await File(song.cachePath!).readAsBytes(), bytes);
      expect(eventCount, 0);
    },
  );
}

Uint8List _buildDsfWithReplayGain() {
  final frames = BytesBuilder();
  const tags = {
    'REPLAYGAIN_TRACK_GAIN': '-7.0 dB',
    'REPLAYGAIN_TRACK_PEAK': '0.9',
    'REPLAYGAIN_ALBUM_GAIN': '-5.25 dB',
    'REPLAYGAIN_ALBUM_PEAK': '1.1',
  };
  tags.forEach((description, value) {
    final body = <int>[
      3,
      ...utf8.encode(description),
      0,
      ...utf8.encode(value),
    ];
    frames.add('TXXX'.codeUnits);
    frames.add(_intBe(body.length));
    frames.add([0, 0]);
    frames.add(body);
  });
  final frameBytes = frames.toBytes();
  final id3 = BytesBuilder()
    ..add('ID3'.codeUnits)
    ..add([3, 0, 0])
    ..add(_syncsafe(frameBytes.length))
    ..add(frameBytes);
  final id3Bytes = id3.toBytes();
  const metadataOffset = 28 + 52 + 12 + 16;
  final builder = BytesBuilder()
    ..add('DSD '.codeUnits)
    ..add(_longLe(28))
    ..add(_longLe(metadataOffset + id3Bytes.length))
    ..add(_longLe(metadataOffset))
    ..add('fmt '.codeUnits)
    ..add(_longLe(52))
    ..add(_intLe(1))
    ..add(_intLe(0))
    ..add(_intLe(2))
    ..add(_intLe(2))
    ..add(_intLe(2822400))
    ..add(_intLe(1))
    ..add(_longLe(2822400))
    ..add(_intLe(4096))
    ..add(_intLe(0))
    ..add('data'.codeUnits)
    ..add(_longLe(28))
    ..add(Uint8List(16))
    ..add(id3Bytes);
  return builder.toBytes();
}

List<int> _syncsafe(int value) => [
  (value >> 21) & 0x7f,
  (value >> 14) & 0x7f,
  (value >> 7) & 0x7f,
  value & 0x7f,
];

List<int> _intLe(int value) => [
  value & 0xff,
  (value >> 8) & 0xff,
  (value >> 16) & 0xff,
  (value >> 24) & 0xff,
];

List<int> _longLe(int value) => [
  for (var index = 0; index < 8; index++) (value >> (index * 8)) & 0xff,
];

List<int> _intBe(int value) => [
  (value >> 24) & 0xff,
  (value >> 16) & 0xff,
  (value >> 8) & 0xff,
  value & 0xff,
];
