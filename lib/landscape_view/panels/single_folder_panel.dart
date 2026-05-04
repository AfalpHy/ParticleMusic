import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/song_list_panel.dart';
import 'package:particle_music/folder.dart';

class SingleFolderPanel extends StatelessWidget {
  final Folder folder;

  const SingleFolderPanel({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return SongListPanel(folder: folder);
  }
}
