import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/folder.dart';
import 'package:particle_music/landscape_view/panels/single_folder_panel.dart';
import 'package:particle_music/portrait_view/pages/single_folder_page.dart';

class SingleFolderLayer extends StatelessWidget {
  final Folder folder;

  const SingleFolderLayer({super.key, required this.folder});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return SingleFolderPage(folder: folder);
        } else {
          return SingleFolderPanel(folder: folder);
        }
      },
    );
  }
}
