import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/setting.dart';

class SettingPanel extends StatefulWidget {
  const SettingPanel({super.key});

  @override
  State<StatefulWidget> createState() => SettingPanelState();
}

class SettingPanelState extends State<SettingPanel> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: colorChangeNotifier,
      builder: (context, value, child) {
        return SettingsList();
      },
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
  Widget build(BuildContext context) {
    return Column(
      children: [
        TitleBar(),
        Expanded(child: contentWidget(context)),
      ],
    );
  }

  Widget contentWidget(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Theme(
            data: ThemeData(
              colorScheme: ColorScheme.light(surface: commonColor),
              listTileTheme: ListTileThemeData(selectedColor: textColor),
              appBarTheme: const AppBarTheme(
                scrolledUnderElevation: 0,
                centerTitle: true,
              ),
            ),
            child: const LicensePage(
              applicationName: 'Particle Music',
              applicationVersion: '1.0.9',
              applicationLegalese: '© 2025-2026 AfalpHy',
            ),
          ),
        ),
      ],
    );
  }
}
