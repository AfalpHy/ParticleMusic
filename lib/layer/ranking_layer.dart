import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/landscape_view/panels/ranking_panel.dart';
import 'package:particle_music/portrait_view/pages/ranking_page.dart';

class RankingLayer extends StatelessWidget {
  const RankingLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (isMobile && orientation == Orientation.portrait) {
          return RankingPage();
        } else {
          return RankingPanel();
        }
      },
    );
  }
}
