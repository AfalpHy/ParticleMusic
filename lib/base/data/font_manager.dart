import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/path.dart';

final fontManager = FontManager();

class FontManager {
  late File _fontMapFile;
  Map<String, List<String>> _fontMap = {};

  FontManager() {
    _fontMapFile = File("${appSupportDir.path}/fonts/font_map.json");
    initFile(_fontMapFile, false);

    _fontMap = readJsonMapFileSync(
      _fontMapFile,
    ).map((key, value) => MapEntry(key, List<String>.from(value)));
  }

  Future<void> loadFonts() async {
    for (final entry in _fontMap.entries) {
      final name = entry.key;
      final fontPathList = entry.value;
      final loader = FontLoader(name);

      for (final fontPath in fontPathList) {
        final fontFile = File("${appSupportDir.path}/fonts/$fontPath");
        if (!fontFile.existsSync()) {
          continue;
        }
        final bytes = fontFile.readAsBytesSync();
        loader.addFont(Future.value(ByteData.view(bytes.buffer)));
      }
      await loader.load();
      importedFonts.add(name);
    }
  }

  Future<void> addFonts(String name, List<String> paths) async {
    for (String path in paths) {
      File originFile = File(path);
      path = basename(path);
      originFile.copySync("${appSupportDir.path}/fonts/$path");
      _fontMap
          .putIfAbsent(name, () {
            return [];
          })
          .add(path);
    }

    await _fontMapFile.writeAsString(json.encode(_fontMap));
  }

  Future<void> deleteFonts(String name) async {
    if (_fontMap[name] == null) {
      return;
    }
    for (final path in _fontMap[name]!) {
      final tmp = File("${appSupportDir.path}/fonts/$path");
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
    _fontMap.remove(name);
    importedFonts.remove(name);
    await _fontMapFile.writeAsString(json.encode(_fontMap));
  }
}
