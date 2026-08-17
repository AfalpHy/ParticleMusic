import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/layer/settings_layer.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';
import 'package:url_launcher/url_launcher.dart';

part '../portrait_view/pages/about_page.dart';
part '../landscape_view/panels/about_panel.dart';

final aboutVisibleNotifier = ValueNotifier(true);

class AboutLayer extends StatefulWidget {
  const AboutLayer({super.key});

  @override
  State<StatefulWidget> createState() => _AboutLayerState();
}

class _AboutLayerState extends State<AboutLayer> {
  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return pageView(context);
    }

    return ListenableBuilder(
      listenable: Listenable.merge([
        settingsVisibleNotifier,
        aboutVisibleNotifier,
      ]),
      builder: (context, _) {
        return Opacity(
          opacity: !settingsVisibleNotifier.value && aboutVisibleNotifier.value
              ? 1
              : 0,
          child: panelView(context),
        );
      },
    );
  }

  void pushLicense() {
    layersManager.pushDetail('settings', 'license');
  }

  void openPrivacy() {
    launchUrl(Uri.parse("https://www.sylvakru.com/privacy_en.html"));
  }

  void openGitHub() {
    launchUrl(Uri.parse("https://github.com/AfalpHy/sylvakru"));
  }

  Widget buildTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      shape: SmoothRectangleBorder(smoothness: 1, borderRadius: .circular(10)),
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget content() {
    final l10n = AppLocalizations.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 500),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Center(
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 72,
              height: 72,
            ),
          ),

          const SizedBox(height: 12),

          ValueListenableBuilder(
            valueListenable: highlightTextColor.valueNotifier,
            builder: (_, color, _) {
              return Center(
                child: Text(
                  l10n.sylvakru,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          Center(child: Text(versionNumber)),

          const SizedBox(height: 16),

          buildTile(
            icon: Icons.description_outlined,
            title: l10n.openSourceLicense,
            onTap: pushLicense,
          ),

          buildTile(
            icon: Icons.privacy_tip_outlined,
            title: l10n.privacyPolicy,
            onTap: openPrivacy,
          ),

          buildTile(icon: Icons.code, title: 'GitHub', onTap: openGitHub),

          Center(
            child: const Text(
              '© 2025-2026 AfalpHy',
              style: .new(fontWeight: .bold),
            ),
          ),

          if (Platform.isIOS && l10n.sylvakru == '森露')
            Center(
              child: TextButton(
                onPressed: () {
                  launchUrl(Uri.parse('https://beian.miit.gov.cn'));
                },
                child: Text(
                  'ICP备案信息: 闽ICP备2026021691号-2A >',
                  style: TextStyle(color: textColor.value, fontWeight: .bold),
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
