import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/portrait_view/my_search_field.dart';

class MyLicensePage extends StatefulWidget {
  const MyLicensePage({super.key});

  @override
  State<StatefulWidget> createState() => _MyLicensePageState();
}

class _MyLicensePageState extends State<MyLicensePage> {
  final Map<String, List<LicenseEntry>> package2Licenses = {};
  final ValueNotifier<List<String>> packagesNotifier = ValueNotifier([]);
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
    packagesNotifier.value =
        package2Licenses.keys
            .where((e) => e.contains(textController.text))
            .toList()
          ..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          search(context),
          Expanded(child: _content()),
        ],
      ),
    );
  }

  PreferredSizeWidget search(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
      actions: [
        MySearchField(
          hintText: AppLocalizations.of(context).searchLicenses,
          textController: textController,
        ),
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
          child: ValueListenableBuilder(
            valueListenable: packagesNotifier,
            builder: (context, packages, child) {
              return ListView.builder(
                itemCount: packages.length,
                itemBuilder: (context, index) {
                  final pkg = packages[index];

                  return ValueListenableBuilder(
                    valueListenable: updateColorNotifier,
                    builder: (context, value, child) {
                      return ExpansionTile(
                        title: Text(pkg),
                        children: [
                          SizedBox(
                            height: 400,
                            child: _buildLicenseDetail(pkg),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLicenseDetail(String selectedPackage) {
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
