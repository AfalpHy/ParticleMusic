import 'dart:io';
import 'package:particle_music/common.dart';

final logger = Logger();

String formatForFileName(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');

  return '${t.year}_'
      '${two(t.month)}_'
      '${two(t.day)}_'
      '${two(t.hour)}_'
      '${two(t.minute)}_'
      '${two(t.second)}';
}

class Logger {
  late File _file;

  Future<void> init() async {
    final time = formatForFileName(DateTime.now());
    _file = File('${appSupportDir.path}/logs/$time.log');
    _file.createSync(recursive: true);
  }

  void output(String msg) {
    final time = DateTime.now().toIso8601String();

    _file.writeAsStringSync(
      '[$time] $msg\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}
