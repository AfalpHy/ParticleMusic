import 'package:flutter/material.dart';
import 'package:particle_music/common_widgets/settings_list.dart';
import 'package:particle_music/portrait_view/custom_appbar_leading.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: customAppBarLeading(context),

        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SettingsList(iconSize: 30),
    );
  }
}
