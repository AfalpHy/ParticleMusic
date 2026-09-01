import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/emby_client.dart';
import 'package:sylvakru/base/services/logger.dart';
import 'package:sylvakru/base/services/navidrome_client.dart';
import 'package:sylvakru/base/services/stream_client.dart';
import 'package:sylvakru/base/services/webdav_client.dart';
import 'package:sylvakru/layer/premium_layer.dart';

final config = Config();

class Config {
  late final File file;

  String? navidromeBaseUrl;
  String? navidromeUsername;
  String? navidromePassword;

  String? embyBaseUrl;
  String? embyUsername;
  String? embyPassword;

  static const _secureStorage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );

  Future<void> load() async {
    if (kReleaseMode && Platform.isIOS) {
      final isPremiumTmp = await _trySecureRead('isPremium');
      if (isPremiumTmp != 'true') {
        isPremiumNotifier.value = false;
        final now = DateTime.now();
        try {
          final trialBeginMs = await _secureStorage.read(key: 'trialBeginMs');
          if (trialBeginMs == null) {
            if (await _trySecureWrite(
              'trialBeginMs',
              now.millisecondsSinceEpoch.toString(),
            )) {
              trialRemainingMinNotifier.value = 4320; // 3 days
            }
          } else {
            final trialBeginTime = DateTime.fromMillisecondsSinceEpoch(
              int.tryParse(trialBeginMs) ?? 0,
            );
            final diff = now.difference(trialBeginTime);
            if (diff.inMinutes < 4320) {
              trialRemainingMinNotifier.value = 4320 - diff.inMinutes;
            }
          }
          if (trialRemainingMinNotifier.value > 0) {
            isPremiumNotifier.value = true;
            Timer.periodic(Duration(minutes: 1), (timer) {
              if (trialRemainingMinNotifier.value <= 0) {
                timer.cancel();
                return;
              }
              trialRemainingMinNotifier.value--;
            });
          }
        } catch (e) {
          logger.output(e.toString());
        }
      }

      if (!isPremiumNotifier.value) {
        viewModeNotifier.value = .normal;
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

    final navidromeMap = map['navidrome'] as Map<String, dynamic>?;
    if (navidromeMap != null) {
      navidromeBaseUrl = navidromeMap['baseUrl'];
      navidromeUsername = navidromeMap['username'];

      navidromePassword = await _trySecureRead('navidrome_password');
      navidromePassword ??= navidromeMap['password'];
      navidromePassword ??= '';
    }

    final embyMap = map['emby'] as Map<String, dynamic>?;
    if (embyMap != null) {
      embyBaseUrl = embyMap['baseUrl'];
      embyUsername = embyMap['username'];

      embyPassword = await _trySecureRead('emby_password');
      embyPassword ??= embyMap['password'];
      embyPassword ??= '';
    }

    final tmpSourceType = map['sourceType'] as String?;
    if (tmpSourceType != null) {
      sourceType = SourceType.values.firstWhere((e) => e.name == tmpSourceType);
    } else {
      if (webdavClient != null) {
        sourceType = .webdav;
      } else if (navidromeMap != null) {
        sourceType = .navidrome;
      } else if (embyMap != null) {
        sourceType = .emby;
      }
    }

    isStreamSource = sourceType == .navidrome || sourceType == .emby;
    isNotStreamSource = !isStreamSource;

    if (sourceType == .navidrome && navidromeMap != null) {
      streamClient = NavidromeClient(
        baseUrl: navidromeBaseUrl!,
        username: navidromeUsername!,
        password: navidromePassword!,
      );
    } else if (sourceType == .emby && embyMap != null) {
      streamClient = EmbyClient(
        baseUrl: embyBaseUrl!,
        username: embyUsername!,
        password: embyPassword!,
      );
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
    bool navidromeSecured = true;
    bool embySecured = true;

    if (webdavClient != null) {
      webdavSecured = await _trySecureWrite(
        'webdav_password',
        webdavClient!.password,
      );
    }

    if (navidromePassword != null) {
      navidromeSecured = await _trySecureWrite(
        'navidrome_password',
        navidromePassword!,
      );
    }

    if (embyPassword != null) {
      embySecured = await _trySecureWrite('emby_password', embyPassword!);
    }

    await file.writeAsString(
      jsonEncode({
        'sourceType': sourceType.name,

        if (webdavClient != null)
          'webdav': {
            'baseUrl': webdavClient!.baseUrl,
            'username': webdavClient!.username,
            if (!webdavSecured) 'password': webdavClient!.password,
          },

        if (navidromeBaseUrl != null)
          'navidrome': {
            'baseUrl': navidromeBaseUrl,
            'username': navidromeUsername,
            if (!navidromeSecured) 'password': navidromePassword,
          },

        if (embyBaseUrl != null)
          'emby': {
            'baseUrl': embyBaseUrl,
            'username': embyUsername,
            if (!embySecured) 'password': embyPassword,
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
      if (map[key] != null && map[key]['password'] != null) {
        return true;
      }
    }
    return false;
  }
}
