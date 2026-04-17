import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:particle_music/common.dart';

class BookmarkService {
  static const _channel = MethodChannel('com.afalphy.bookmark_manager');
  static const _fileName = 'directory_inventory.txt';

  static late File file;
  static late Map<String, dynamic> _inventory;

  static Future<void> init() async {
    file = File('${appSupportDir.path}/$_fileName');

    if (!await file.exists()) {
      _inventory = {};
      return;
    }

    final content = await file.readAsString();
    _inventory = jsonDecode(content) as Map<String, dynamic>;
  }

  // Saves a new directory bookmark associated with a specific ID
  static Future<bool> saveDirectoryAndActive(String id, String path) async {
    try {
      final String bookmark = await _channel.invokeMethod(
        'getBookmarkFromPath',
        {'path': path},
      );

      // Update the map with the new bookmark
      _inventory[id] = bookmark;

      await file.writeAsString(jsonEncode(_inventory));

      await _channel.invokeMethod('activateAndGetPath', {'bookmark': bookmark});
    } on PlatformException catch (e) {
      logger.output(e.toString());
      return false;
    }
    return true;
  }

  static Future<bool> active(String path) async {
    try {
      final String bookmark = await _channel.invokeMethod(
        'getBookmarkFromPath',
        {'path': path},
      );

      await _channel.invokeMethod('activateAndGetPath', {'bookmark': bookmark});
    } on PlatformException catch (e) {
      logger.output(e.toString());
      return false;
    }
    return true;
  }

  // Activates a specific directory by ID and returns its accessible URL
  static Future<String?> getUrlById(String id) async {
    try {
      final String? bookmark = _inventory[id];

      if (bookmark != null) {
        final String securePath = await _channel.invokeMethod(
          'activateAndGetPath',
          {'bookmark': bookmark},
        );
        return securePath;
      }
    } catch (e) {
      logger.output(e.toString());
    }
    return null;
  }
}
