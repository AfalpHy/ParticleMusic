import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

WebDavClient? webdavClient;

class WebDavFile {
  final String path;
  final String name;
  final bool isDirectory;
  final DateTime? modified;

  WebDavFile({
    required this.path,
    required this.name,
    required this.isDirectory,
    this.modified,
  });
}

class WebDavClient {
  final String baseUrl;
  final String username;
  final String password;

  late String _cleanBaseUrl;
  late String _initialPath;

  late final Dio dio;

  WebDavClient({
    required this.baseUrl,
    required this.username,
    required this.password,
  }) {
    _initialPath = Uri.parse(baseUrl).path;
    _initialPath = Uri.decodeFull(_initialPath);

    _cleanBaseUrl = baseUrl.substring(0, baseUrl.length - _initialPath.length);

    if (_initialPath.endsWith('/')) {
      _initialPath = _initialPath.substring(0, _initialPath.length - 1);
    }

    dio = Dio(
      BaseOptions(
        baseUrl: _cleanBaseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );

    _applyAuth();
  }

  String get cleanBaseUrl => _cleanBaseUrl;

  String get initialPath => _initialPath;

  void _applyAuth() {
    dio.options.headers['authorization'] =
        'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  Map<String, String> get headers {
    return Map<String, String>.from(dio.options.headers);
  }

  String _safeDecodeUri(String value) {
    try {
      return Uri.decodeFull(value);
    } catch (e) {
      logger.output('[WebDav] Decode uri error: $e');
      return value;
    }
  }

  Future<T?> _safeRequest<T>(
    String mark,
    Future<Response> Function() request,
    T? Function(Response response) parser,
  ) async {
    try {
      final response = await request();
      return parser(response);
    } on DioException catch (e) {
      logger.output(
        '[WebDav] [$mark] Dio error: ${e.message} '
        '(${e.response?.statusCode})',
      );

      if (e.response?.data != null) {
        logger.output(e.response!.data.toString());
      }

      return null;
    } catch (e) {
      logger.output('[WebDav] [$mark] Unknown error: $e');
      return null;
    }
  }

  Future<bool> _boolRequest(
    String mark,
    Future<Response> Function() request,
  ) async {
    return await _safeRequest(mark, request, (_) => true) ?? false;
  }

  Future<bool> ping() async {
    final result = await _safeRequest(
      'ping $_initialPath',
      () => dio.request(
        _initialPath,
        options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
      ),
      (response) {
        final code = response.statusCode ?? 0;
        return code >= 200 && code < 400;
      },
    );

    return result ?? false;
  }

  Future<List<WebDavFile>> list(String remotePath) async {
    remotePath = initialPath + remotePath;
    if (!remotePath.endsWith('/')) {
      remotePath += '/';
    }

    final result = await _safeRequest(
      'list $remotePath',
      () => dio.request(
        remotePath,
        data: '''
<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:">
  <d:allprop />
</d:propfind>
''',
        options: Options(
          method: 'PROPFIND',
          headers: {'Depth': '1', 'Content-Type': 'text/xml; charset=utf-8'},
        ),
      ),
      (response) {
        final document = XmlDocument.parse(response.data);

        final responses = document
            .findAllElements('*')
            .where((e) => e.name.local == 'response');

        final result = <WebDavFile>[];

        for (final item in responses) {
          try {
            final hrefElement = item.children
                .whereType<XmlElement>()
                .firstWhere((e) => e.name.local == 'href');

            String href = _safeDecodeUri(hrefElement.innerText);

            if (remotePath == href) {
              continue;
            }

            final isDir = item
                .findAllElements('*')
                .any((e) => e.name.local == 'collection');

            final modifiedElement = item
                .findAllElements('*')
                .where((e) => e.name.local == 'getlastmodified')
                .firstOrNull;

            DateTime? modified;

            if (modifiedElement != null) {
              try {
                modified = HttpDate.parse(modifiedElement.innerText).toLocal();
              } catch (e) {
                logger.output('[WebDav] Parse modified time error: $e');
              }
            }

            final cleanPath = href.endsWith('/')
                ? href.substring(0, href.length - 1)
                : href;

            final name = p.basename(cleanPath);
            result.add(
              WebDavFile(
                path: href,
                name: name,
                isDirectory: isDir,
                modified: modified,
              ),
            );
          } catch (e) {
            logger.output('[WebDav] Parse item error: $e');
          }
        }

        return result;
      },
    );

    return result ?? [];
  }

  Stream<WebDavFile> listStream(
    String remotePath, {
    bool recursive = false,
  }) async* {
    final files = await list(remotePath);

    for (final file in files) {
      yield file;

      if (recursive && file.isDirectory) {
        yield* listStream(
          file.path.substring(webdavClient!.initialPath.length),
          recursive: true,
        );
      }
    }
  }

  Future<List<String>> listSubDirectories(String root) async {
    try {
      final dirList = <String>[];
      final dirQueue = Queue<String>();

      dirQueue.add(root);

      while (dirQueue.isNotEmpty) {
        final dir = dirQueue.removeFirst();

        final fileList = await list(dir);

        for (final f in fileList) {
          if (f.isDirectory) {
            dirList.add(f.path);
            dirQueue.add(f.path);
          }
        }
      }

      return dirList;
    } catch (e) {
      logger.output('[WebDav] List sub directories error: $e');
      return [];
    }
  }

  Future<bool> download({
    required String remotePath,
    required String localPath,
    ProgressCallback? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    return _boolRequest(
      'download $remotePath',
      () => dio.download(
        remotePath,
        localPath,
        onReceiveProgress: onReceiveProgress,
        cancelToken: cancelToken,
        deleteOnError: false,
        options: Options(receiveTimeout: Duration.zero),
      ),
    );
  }

  Future<bool> upload({
    required String localPath,
    required String remotePath,
    ProgressCallback? onSendProgress,
  }) async {
    final file = File(localPath);
    final length = await file.length();

    return _boolRequest(
      'upload $localPath',

      () => dio.put(
        remotePath,
        data: file.openRead(),
        options: Options(headers: {Headers.contentLengthHeader: length}),
        onSendProgress: onSendProgress,
      ),
    );
  }

  Future<bool> mkdir(String remotePath) async {
    return _boolRequest(
      'mkdir $remotePath',

      () => dio.request(remotePath, options: Options(method: 'MKCOL')),
    );
  }

  Future<bool> delete(String remotePath) async {
    return _boolRequest('delete $remotePath', () => dio.delete(remotePath));
  }

  String _buildDestinationUrl(String destination) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    final cleanDest = destination.startsWith('/')
        ? destination.substring(1)
        : destination;
    return '$cleanBase$cleanDest';
  }

  Future<bool> move({
    required String source,
    required String destination,
  }) async {
    return _boolRequest(
      'move ${source}to $destination',
      () => dio.request(
        source,
        options: Options(
          method: 'MOVE',
          headers: {'Destination': _buildDestinationUrl(destination)},
        ),
      ),
    );
  }

  Future<bool> copy({
    required String source,
    required String destination,
  }) async {
    return _boolRequest(
      'copy ${source}to $destination',

      () => dio.request(
        source,
        options: Options(
          method: 'COPY',
          headers: {'Destination': _buildDestinationUrl(destination)},
        ),
      ),
    );
  }
}
