import 'dart:convert';
import 'dart:io';

import 'package:particle_music/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

class SingleInstance {
  static RandomAccessFile? _lock;

  static Future<void> start() async {
    logger.output('Single instance init');

    final dir = await getApplicationSupportDirectory();
    final lockFile = File('${dir.path}/particle_music.lock');
    if (!lockFile.existsSync()) {
      lockFile.createSync();
    }

    final portFile = File('${dir.path}/particle_music.port');
    if (!portFile.existsSync()) {
      portFile.createSync();
    }

    bool isPrimary = true;
    int? existingPort;
    try {
      _lock = await lockFile.open(mode: FileMode.write);
      await _lock!.lock();
    } catch (_) {
      logger.output('A process already exists');

      isPrimary = false;
      // Read port from file
      final lines = await portFile.readAsLines();

      if (lines.isNotEmpty) {
        existingPort = int.tryParse(lines.first);
      }
    }

    if (!isPrimary) {
      if (existingPort != null) {
        try {
          final socket = await Socket.connect(
            InternetAddress.loopbackIPv4,
            existingPort,
          );
          socket.write('particle_music_show_window');
          await socket.flush();
          await socket.close();
          logger.output('Successfully contacted the main instance');
        } catch (e) {
          logger.output('Failed to contact main instance: $e');
        }
      }

      exit(0);
    }

    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;

    // Save port
    portFile.writeAsStringSync('$port');

    // Handle incoming messages
    server.listen((client) async {
      final msg = await utf8.decodeStream(client);
      if (msg.contains('particle_music_show_window')) {
        await windowManager.show();
        await windowManager.focus();
      }
      client.destroy();
    });

    logger.output('Single instance server start');
  }

  static Future<void> end() async {
    await _lock?.unlock();
  }
}
