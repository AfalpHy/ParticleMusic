import 'package:flutter/material.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/setting.dart';

class SettingPanel extends StatefulWidget {
  const SettingPanel({super.key});

  @override
  State<StatefulWidget> createState() => SettingPanelState();
}

class SettingPanelState extends State<SettingPanel> {
  late Widget searchField;

  @override
  void initState() {
    super.initState();

    searchField = titleSearchField('Search Setting');
    titleSearchFieldStack.add(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
  }

  @override
  void dispose() {
    titleSearchFieldStack.remove(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(children: [Expanded(child: SettingsList())]),
    );
  }
}

class LicensePagePanel extends StatefulWidget {
  const LicensePagePanel({super.key});

  @override
  State<StatefulWidget> createState() => LicensePagePanelState();
}

class LicensePagePanelState extends State<LicensePagePanel> {
  late Widget searchField;

  @override
  void initState() {
    super.initState();

    searchField = titleSearchField('Search Licenses');
    titleSearchFieldStack.add(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
  }

  @override
  void dispose() {
    titleSearchFieldStack.remove(searchField);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateTitleSearchField.value++;
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
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
                applicationVersion: '1.0.4',
                applicationLegalese: '© 2025 AfalpHy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
