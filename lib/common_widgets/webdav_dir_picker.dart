import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class WebdavDirPicker extends StatefulWidget {
  const WebdavDirPicker({super.key});

  @override
  State<StatefulWidget> createState() => _WebdavDirPickerState();
}

class _WebdavDirPickerState extends State<WebdavDirPicker> {
  String currentPath = '/';
  List<String> directories = [];

  @override
  void initState() {
    super.initState();
    loadDirectories(currentPath);
  }

  Future<List<String>> listDirectories(String path) async {
    try {
      await webdavClient!.ping();
    } catch (e) {
      return [];
    }

    final files = await webdavClient!.readDir(path);
    // Keep only directories
    final directories = files
        .where((f) => f.isDir!)
        .map((f) => f.path!.substring(0, f.path!.length - 1))
        .toList();
    return directories;
  }

  void loadDirectories(String path) async {
    final dirs = await listDirectories(path);
    setState(() {
      currentPath = path;
      directories = dirs;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(currentPath, style: .new(fontWeight: .bold, fontSize: 18)),
          SizedBox(height: 10),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ListView.builder(
                itemCount: directories.length,
                itemBuilder: (context, index) {
                  final dir = directories[index];
                  return ListTile(
                    title: Text(dir.split('/').last),
                    leading: Icon(Icons.folder),
                    dense: true,
                    onTap: () {
                      loadDirectories(dir); // navigate into subdirectory
                    },
                  );
                },
              ),
            ),
          ),
          SizedBox(height: 10),

          Row(
            mainAxisAlignment: .center,
            children: [
              ElevatedButton(
                onPressed: () {
                  final last = currentPath.split('/').last;
                  loadDirectories(
                    currentPath.substring(0, currentPath.length - last.length),
                  );
                },
                child: Text('back'),
              ),
              SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, "WebDAV:$currentPath");
                },
                child: Text(AppLocalizations.of(context).confirm),
              ),
            ],
          ),
          SizedBox(height: 5),
        ],
      ),
    );
  }
}
