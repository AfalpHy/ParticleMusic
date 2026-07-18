import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/logger.dart';
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
      final isPremiumTmp = await _trySecureRead('isPremium');
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
      String? securePassword = await _trySecureRead('webdav_password');
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
      String? securePassword = await _trySecureRead('subsonic_password');
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
      String? securePassword = await _trySecureRead('navidrome_password');
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
      String? securePassword = await _trySecureRead('emby_password');
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
    await _trySecureWrite('isPremium', 'true');
  }

  Future<void> save() async {
    // Secure storage (keyring/Keychain) can fail to write - e.g. no Secret
    // Service running on some Linux setups - and previously that failure was
    // silently ignored while the plaintext password was still stripped from
    // config.json, permanently losing the credential on the next load. Keep
    // the plaintext as a fallback in that one field until a write actually
    // succeeds, instead of losing it outright.
    bool webdavSecured = true;
    bool subsonicSecured = true;
    bool navidromeSecured = true;
    bool embySecured = true;

    if (webdavClient != null) {
      webdavSecured = await _trySecureWrite(
        'webdav_password',
        webdavClient!.password,
      );
    }
    if (subsonicClient != null) {
      subsonicSecured = await _trySecureWrite(
        'subsonic_password',
        subsonicClient!.password,
      );
    }
    if (navidromeClient != null) {
      navidromeSecured = await _trySecureWrite(
        'navidrome_password',
        navidromeClient!.password,
      );
    }
    if (embyClient != null) {
      embySecured = await _trySecureWrite(
        'emby_password',
        embyClient!.password,
      );
    }

    await file.writeAsString(
      jsonEncode({
        if (webdavClient != null)
          'webdav': {
            'baseUrl': webdavClient!.baseUrl,
            'username': webdavClient!.username,
            if (!webdavSecured) 'password': webdavClient!.password,
          },

        if (subsonicClient != null)
          'subsonic': {
            'baseUrl': subsonicClient!.baseUrl,
            'username': subsonicClient!.username,
            if (!subsonicSecured) 'password': subsonicClient!.password,
          },

        if (navidromeClient != null)
          'navidrome': {
            'baseUrl': navidromeClient!.baseUrl,
            'username': navidromeClient!.username,
            if (!navidromeSecured) 'password': navidromeClient!.password,
          },

        if (embyClient != null)
          'emby': {
            'baseUrl': embyClient!.baseUrl,
            'username': embyClient!.username,
            if (!embySecured) 'password': embyClient!.password,
          },
      }),
    );
  }

  Future<String?> _trySecureRead(String key) async {
    try {
      return await _secureStorage.read(key: key);
    } catch (e) {
      logger.output('Failed to read "$key" from secure storage: $e');
      return null;
    }
  }

  Future<bool> _trySecureWrite(String key, String value) async {
    try {
      await _secureStorage.write(key: key, value: value);
      return true;
    } catch (e) {
      logger.output('Failed to write "$key" to secure storage: $e');
      return false;
    }
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
