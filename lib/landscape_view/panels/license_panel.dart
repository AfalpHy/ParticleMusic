import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/landscape_view/title_bar.dart';
import 'package:smooth_corner/smooth_corner.dart';

class LicensePanel extends StatefulWidget {
  const LicensePanel({super.key});

  @override
  State<StatefulWidget> createState() => _LicensePanelState();
}

class _LicensePanelState extends State<LicensePanel> {
  final Map<String, List<LicenseEntry>> package2Licenses = {};
  String? selectedPackage;
  List<String> packages = [];
  final textController = TextEditingController();

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
    setState(() {
      packages =
          package2Licenses.keys
              .where((e) => e.contains(textController.text))
              .toList()
            ..sort();
      selectedPackage = packages.isNotEmpty ? packages.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        TitleBar(
          searchField: TitleSearchField(
            key: ValueKey(l10n.searchLicenses),
            hintText: l10n.searchLicenses,
            textController: textController,
          ),
        ),
        Expanded(child: _content()),
      ],
    );
  }

  Widget _content() {
    return Column(
      children: [
        Text('Particle Music', style: .new(fontWeight: .bold, fontSize: 24)),
        Text(versionNumber),
        SizedBox(height: 15),
        Text('© 2025-2026 AfalpHy'),

        SizedBox(height: 15),
        Text('Powered by Flutter'),
        SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ListView.builder(
                    itemCount: packages.length,
                    itemBuilder: (context, index) {
                      final pkg = packages[index];

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Material(
                          color: Colors.transparent,
                          shape: SmoothRectangleBorder(
                            smoothness: 1,
                            borderRadius: .all(.circular(10)),
                          ),
                          clipBehavior: .antiAlias,
                          child: ValueListenableBuilder(
                            valueListenable: updateColorNotifier,
                            builder: (context, value, child) {
                              return ListTile(
                                tileColor: pkg == selectedPackage
                                    ? selectedItemColor
                                    : null,
                                title: Text(pkg),
                                onTap: () {
                                  setState(() {
                                    selectedPackage = pkg;
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                ValueListenableBuilder(
                  valueListenable: updateColorNotifier,
                  builder: (context, value, child) {
                    return VerticalDivider(
                      width: 1,
                      thickness: 0.5,
                      color: dividerColor,
                    );
                  },
                ),

                Expanded(flex: 5, child: _buildLicenseDetail()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseDetail() {
    if (selectedPackage == null) {
      return SizedBox();
    }

    final licenses = package2Licenses[selectedPackage]!;

    return ListView.separated(
      itemCount: licenses.length,
      separatorBuilder: (_, _) => ValueListenableBuilder(
        valueListenable: updateColorNotifier,
        builder: (context, value, child) {
          return Divider(height: 1, thickness: 0.5, color: dividerColor);
        },
      ),
      itemBuilder: (context, index) {
        final license = licenses[index];

        final text = license.paragraphs.map((p) => p.text).join('\n\n');

        return Padding(padding: const EdgeInsets.all(12), child: Text(text));
      },
    );
  }
}
