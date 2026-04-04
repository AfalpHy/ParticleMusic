import 'package:flutter/material.dart';
import 'package:particle_music/landscape_view/panels/license_panel.dart';
import 'package:particle_music/portrait_view/pages/my_license_page.dart';

class LicenseLayer extends StatelessWidget {
  const LicenseLayer({super.key});

  @override
  Widget build(BuildContext context) {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return MyLicensePage();
        } else {
          return LicensePanel();
        }
      },
    );
  }
}
