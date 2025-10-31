import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SettingPlane extends StatelessWidget {
  const SettingPlane({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
          TitleBar(),
          SizedBox(height: 30),
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Text(
                    'Setting',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(height: 30),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SmoothClipRRect(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Color.fromARGB(255, 235, 240, 245),
                      child: ListTile(
                        leading: Icon(
                          Icons.info_outline_rounded,
                          color: mainColor,
                        ),
                        title: const Text('Open Source Licenses'),
                        onTap: () {
                          planeManager.pushPlane(-2);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class LicensePagePlane extends StatelessWidget {
  const LicensePagePlane({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
          TitleBar(),
          Expanded(
            child: Theme(
              data: ThemeData(
                colorScheme: ColorScheme.light(
                  surface: Color.fromARGB(255, 235, 240, 245),
                ),
                listTileTheme: ListTileThemeData(
                  selectedColor: Color.fromARGB(255, 75, 200, 200),
                ),
                appBarTheme: const AppBarTheme(
                  scrolledUnderElevation: 0,
                  centerTitle: true,
                ),
              ),
              child: const LicensePage(
                applicationName: 'Particle Music',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2025 AfalpHy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
