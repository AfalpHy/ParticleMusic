import 'dart:convert';
import 'dart:io';

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

      final client = NavidromeClient(
        baseUrl: 'http://${server.address.address}:${server.port}',
        username: 'user',
        password: 'password',
      );
      client.dio.options.receiveTimeout = const Duration(seconds: 1);

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
    final song = MyAudioMetadata.fromNavidromeMap({
      'id': 'song-id',
      'title': 'Song',
      'suffix': 'flac',
    });

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
      final song = MyAudioMetadata.fromNavidromeMap({
        'id': 'retry-song-id',
        'title': 'Retry Song',
        'suffix': 'flac',
      });

      await library_data.Library().tryAddCache(song);

      expect(requestCount, 2);
      expect(song.cacheExist, isTrue);
      expect(await File(song.cachePath!).readAsBytes(), [1, 2, 3]);
    },
  );
}
