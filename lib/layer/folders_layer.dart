import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/folders_panel.dart';
import 'package:particle_music/portrait_view/pages/folders_page.dart';

class FoldersLayer extends StatelessWidget {
  const FoldersLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return FoldersPage();
        } else {
          return FoldersPanel();
        }
      },
    );
  }
}
