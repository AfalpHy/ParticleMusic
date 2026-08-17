import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smooth_corner/smooth_corner.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/services/color_manager.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/base/widgets/my_divider.dart';
import 'package:sylvakru/l10n/generated/app_localizations.dart';
import 'package:sylvakru/landscape_view/title_bar.dart';
import 'package:sylvakru/layer/about_layer.dart';
import 'package:sylvakru/layer/layers_manager.dart';
import 'package:sylvakru/portrait_view/custom_appbar_leading.dart';
import 'package:sylvakru/portrait_view/my_search_field.dart';

part '../portrait_view/pages/license_page.dart';
part '../landscape_view/panels/license_panel.dart';

class LicenseLayer extends StatefulWidget {
  const LicenseLayer({super.key});

  @override
  State<StatefulWidget> createState() => _LicenseLayerState();
}

class _LicenseLayerState extends State<LicenseLayer> {
  final Map<String, List<LicenseEntry>> package2Licenses = {};
  List<String> packages = [];
  final textController = TextEditingController();
  final ValueNotifier<bool> isSearchNotifier = ValueNotifier(false);

  String? selectedPackage;

  @override
  void initState() {
    super.initState();
    _loadLicenses();
    textController.addListener(update);
  }

  @override
  void dispose() {
    textController.removeListener(update);
    super.dispose();
  }

  void _loadLicenses() async {
    await for (final license in LicenseRegistry.licenses) {
      for (final pkg in license.packages) {
        package2Licenses.putIfAbsent(pkg, () => []).add(license);
      }
    }

    update();
  }

  void update() {
    packages =
        package2Licenses.keys
            .where(
              (e) =>
                  e.toLowerCase().contains(textController.text.toLowerCase()),
            )
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    selectedPackage = packages.isNotEmpty ? packages.first : null;
    rebuild();
  }

  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (isTooNarrow(context)) {
      return pageView(context);
    }
    return ValueListenableBuilder(
      valueListenable: aboutVisibleNotifier,
      builder: (context, value, child) {
        return Opacity(opacity: value ? 0 : 1, child: panelView(context));
      },
    );
  }

  Widget buildLicenseDetail(String selectedPackage) {
    final licenses = package2Licenses[selectedPackage]!;

    return ListView.separated(
      itemCount: licenses.length,
      separatorBuilder: (_, _) =>
          MyDivider(height: 1, thickness: 0.5, color: dividerColor),
      itemBuilder: (context, index) {
        final license = licenses[index];

        final text = license.paragraphs.map((p) => p.text).join('\n\n');

        return Padding(padding: const EdgeInsets.all(12), child: Text(text));
      },
    );
  }
}
