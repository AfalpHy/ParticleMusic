import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/subsonic_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';

final config = Config();

class Config {
  late final File file;

  static const _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<void> load() async {
    if (Platform.isIOS) {
      final isPremiumTmp = await _secureStorage.read(key: 'isPremium');
      if (isPremiumTmp != 'true') {
        isPremiumNotifier.value = false;
      }
    }

    file = File("${appSupportDir.path}/config.json");
    if (!(file.existsSync())) {
      return;
    }

    final content = await file.readAsString();

    final Map<String, dynamic> map =
        jsonDecode(content) as Map<String, dynamic>;

    final webdavMap = map['webdav'] as Map<String, dynamic>?;
    if (webdavMap != null) {
      String? securePassword = await _secureStorage.read(
        key: 'webdav_password',
      );
      securePassword ??= webdavMap['password'];
      securePassword ??= '';

      webdavClient = WebDavClient(
        baseUrl: webdavMap['baseUrl'],
        username: webdavMap['username'],
        password: securePassword,
      );
    }

    final subsonicMap = map['subsonic'] as Map<String, dynamic>?;
    if (subsonicMap != null) {
      String? securePassword = await _secureStorage.read(
        key: 'subsonic_password',
      );
      securePassword ??= subsonicMap['password'];
      securePassword ??= '';

      subsonicClient = SubsonicClient(
        baseUrl: subsonicMap['baseUrl'],
        username: subsonicMap['username'],
        password: securePassword,
      );
    }

    final navidromeMap = map['navidrome'] as Map<String, dynamic>?;
    if (navidromeMap != null) {
      String? securePassword = await _secureStorage.read(
        key: 'navidrome_password',
      );
      securePassword ??= navidromeMap['password'];
      securePassword ??= '';

      navidromeClient = NavidromeClient(
        baseUrl: navidromeMap['baseUrl'],
        username: navidromeMap['username'],
        password: securePassword,
      );
    }

    final embyMap = map['emby'] as Map<String, dynamic>?;
    if (embyMap != null) {
      String? securePassword = await _secureStorage.read(key: 'emby_password');
      securePassword ??= embyMap['password'];
      securePassword ??= '';

      embyClient = EmbyClient(
        baseUrl: embyMap['baseUrl'],
        username: embyMap['username'],
        password: securePassword,
      );
      await embyClient!.login();
    }

    if (_hasPlainTextPassword(map)) {
      await save();
    }
  }

  Future<void> savePremium() async {
    await _secureStorage.write(key: 'isPremium', value: 'true');
  }

  Future<void> save() async {
    if (webdavClient != null) {
      await _secureStorage.write(
        key: 'webdav_password',
        value: webdavClient!.password,
      );
    }
    if (subsonicClient != null) {
      await _secureStorage.write(
        key: 'subsonic_password',
        value: subsonicClient!.password,
      );
    }
    if (navidromeClient != null) {
      await _secureStorage.write(
        key: 'navidrome_password',
        value: navidromeClient!.password,
      );
    }
    if (embyClient != null) {
      await _secureStorage.write(
        key: 'emby_password',
        value: embyClient!.password,
      );
    }

    await file.writeAsString(
      jsonEncode({
        if (webdavClient != null)
          'webdav': {
            'baseUrl': webdavClient!.baseUrl,
            'username': webdavClient!.username,
          },

        if (subsonicClient != null)
          'subsonic': {
            'baseUrl': subsonicClient!.baseUrl,
            'username': subsonicClient!.username,
          },

        if (navidromeClient != null)
          'navidrome': {
            'baseUrl': navidromeClient!.baseUrl,
            'username': navidromeClient!.username,
          },

        if (embyClient != null)
          'emby': {
            'baseUrl': embyClient!.baseUrl,
            'username': embyClient!.username,
          },
      }),
    );
  }

  bool _hasPlainTextPassword(Map<String, dynamic> map) {
    for (var key in ['webdav', 'navidrome', 'emby']) {
      if (map[key] != null &&
          map[key]['password'] != null &&
          map[key]['password'].toString().isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
