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
  bool isLoading = false;
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
    setState(() {
      isLoading = true;
    });
    final dirs = await listDirectories(path);
    setState(() {
      isLoading = false;
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
          Stack(
            children: [
              IconButton(
                onPressed: () {
                  final last = currentPath.split('/').last;
                  loadDirectories(
                    currentPath.substring(0, currentPath.length - last.length),
                  );
                },
                icon: Icon(Icons.arrow_back_ios_rounded),
              ),
              Center(
                child: Column(
                  children: [
                    SizedBox(height: 5),
                    Text(
                      currentPath,
                      style: .new(fontWeight: .bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 10),

          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: iconColor))
                : ListView.builder(
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
          SizedBox(height: 10),

          Row(
            mainAxisAlignment: .end,
            children: [
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
