import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';

class TvDirPicker extends StatefulWidget {
  const TvDirPicker({super.key});

  @override
  State<StatefulWidget> createState() => _TvDirPickerState();
}

class _TvDirPickerState extends State<TvDirPicker> {
  final String root = '/storage/emulated/0';
  String currentPath = '/storage/emulated/0';
  List<String> directories = [];
  bool isLoading = false;
  @override
  void initState() {
    super.initState();
    loadDirectories(currentPath);
  }

  Future<List<String>> listDirectories(String path) async {
    Directory top = Directory(path);
    // Keep only directories
    final directories = await top
        .list()
        .where((f) => f is Directory)
        .map((f) => f.path)
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
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (currentPath == root) {
                    return;
                  }
                  final last = currentPath.split('/').last;
                  currentPath = currentPath.substring(
                    0,
                    currentPath.length - last.length - 1,
                  );
                  loadDirectories(currentPath);
                },
                icon: Icon(Icons.arrow_back_ios_rounded),
              ),
              Text(
                currentPath == root ? root : currentPath.split('/').last,
                style: .new(fontWeight: .bold, fontSize: 18),
              ),
            ],
          ),
          SizedBox(height: 10),

          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: iconColor.value),
                  )
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
              ValueListenableBuilder(
                valueListenable: buttonColor.valueNotifier,
                builder: (context, value, child) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context, currentPath);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: value),
                    child: Text(AppLocalizations.of(context).confirm),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: 5),
        ],
      ),
    );
  }
}
