import 'package:flutter/widgets.dart';
import 'package:sylvakru/base/widgets/settings_list.dart';

class BigSettingsPanel extends StatefulWidget {
  const BigSettingsPanel({super.key});

  @override
  State<StatefulWidget> createState() => _BigSettingsPanelState();
}

class _BigSettingsPanelState extends State<BigSettingsPanel> {
  @override
  Widget build(BuildContext context) {
    return Padding(padding: .symmetric(vertical: 75), child: SettingsList());
  }
}
