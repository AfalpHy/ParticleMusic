import 'package:flutter/material.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/portrait_view/pages/song_list_page.dart';

class SingleFolderPage extends StatelessWidget {
  final Folder folder;
  const SingleFolderPage({super.key, required this.folder});
  @override
  Widget build(BuildContext context) {
    return SongListPage(folder: folder);
  }
}
