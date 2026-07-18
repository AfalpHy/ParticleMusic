import 'dart:io';

import 'package:flutter/material.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

const String versionNumber = '3.4.6';

late final Directory appDocsDir;
late final Directory appSupportDir;
late final Directory tmpDir;

final isMobile = Platform.isAndroid || Platform.isIOS;

late final ScreenRadius? screenRadius;

enum ThemeType { vivid, light, dark, custom }

final mainPageThemeNotifier = ValueNotifier(ThemeType.vivid);
final lyricsPageThemeNotifier = ValueNotifier(ThemeType.vivid);

final ValueNotifier<Locale?> localeNotifier = ValueNotifier(null);

enum SourceType { local, webdav, subsonic, navidrome, emby }

final ValueNotifier<String?> fontFamilyNotifier = ValueNotifier(null);

final List<String> importedFonts = [];

final isPremiumNotifier = ValueNotifier(true);

enum ViewMode { normal, mini, bigPicture }

final viewModeNotifier = ValueNotifier(ViewMode.normal);
