import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/webdav_client.dart';

void setIOSFileProviderStorageIfNeed(String? iosPath) {
  if (iosFileProviderStorage == null && iosPath != null) {
    final tmp = iosPath.split('File Provider Storage/').first;
    iosFileProviderStorage = "${tmp}File Provider Storage/";
  }
}

bool isFileProviderStorePath(String path) {
  return path.contains('File Provider Storage/');
}

// full path to short path
String convertIOSPath(String path) {
  if (path.contains('File Provider Storage/')) {
    return path.split('File Provider Storage/').last;
  } else {
    path = path.substring(path.indexOf('Documents'));
    return path.replaceFirst('Documents', 'Sylvakru');
  }
}

// short path to full path
String revertIOSPath(String path) {
  if (path.startsWith('Sylvakru')) {
    return "${appDocsDir.parent.path}/${path.replaceFirst('Sylvakru', 'Documents')}";
  } else {
    if (iosFileProviderStorage == null) {
      return '';
    }
    return iosFileProviderStorage! + path;
  }
}

// full path to short path
String convertIOSSupportPath(String path) {
  return path.split('Application Support/').last;
}

// short path to full path
String revertIOSSupportPath(String path) {
  return "${appSupportDir.path}/$path";
}

void initFile(File file, bool isList) {
  if (!file.existsSync()) {
    file.createSync(recursive: true);
    file.writeAsStringSync(isList ? '[]' : '{}');
  }
}

/// Decodes [file] as a JSON list, resetting it to `[]` and returning an
/// empty list if the content is missing or corrupted (e.g. a crash mid-write)
/// instead of letting the exception crash startup.
List<dynamic> readJsonListFileSync(File file) {
  try {
    return jsonDecode(file.readAsStringSync()) as List<dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    file.writeAsStringSync('[]');
    return [];
  }
}

/// Async counterpart of [readJsonListFileSync].
Future<List<dynamic>> readJsonListFile(File file) async {
  try {
    return jsonDecode(await file.readAsString()) as List<dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    await file.writeAsString('[]');
    return [];
  }
}

/// Decodes [file] as a JSON map, resetting it to `{}` and returning an empty
/// map if the content is missing or corrupted, instead of letting the
/// exception crash startup.
Map<String, dynamic> readJsonMapFileSync(File file) {
  try {
    return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    file.writeAsStringSync('{}');
    return {};
  }
}

/// Async counterpart of [readJsonMapFileSync].
Future<Map<String, dynamic>> readJsonMapFile(File file) async {
  try {
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  } catch (e) {
    logger.output('Corrupted JSON file ${file.path}, resetting: $e');
    await file.writeAsString('{}');
    return {};
  }
}

String getFolderConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/folder_config';
}

String getPlaylistConfigPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/playlist_config';
}

String getCachesPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/caches';
}

String getPicturesPath(SourceType sourceType) {
  return '${appSupportDir.path}/${sourceType.name}/pictures';
}

final _httpClient = http.Client();

Future<String?> convertToRealPathIfNeed(String path) async {
  final request = http.Request('HEAD', Uri.parse(path))
    ..followRedirects = false
    ..headers.addAll(webdavClient?.headers ?? {});

  final response = await _httpClient.send(request);

  if (response.statusCode == 302) {
    final realLocation = response.headers['location'];
    if (realLocation != null) {
      return realLocation;
    }
  }
  return null;
}
