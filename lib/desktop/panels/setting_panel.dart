import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

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
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Color.fromARGB(255, 235, 240, 245),

      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 64,
                    child: Center(
                      child: ListTile(
                        leading: Icon(
                          Icons.settings_outlined,
                          size: 35,
                          color: mainColor,
                        ),
                        title: Text(
                          l10n.settings,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  child: Divider(
                    thickness: 1,
                    height: 1,
                    color: Colors.grey.shade300,
                  ),
                ),
                SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SmoothClipRRect(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Color.fromARGB(255, 235, 240, 245),
                      child: ListTile(
                        leading: ImageIcon(reloadImage, color: mainColor),
                        title: Text(l10n.reload),
                        onTap: () async {
                          if (await showConfirmDialog(
                            context,
                            'Reload Action',
                          )) {
                            libraryLoader.reload();
                          }
                        },
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SmoothClipRRect(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Color.fromARGB(255, 235, 240, 245),
                      child: ListTile(
                        leading: ImageIcon(folderImage, color: mainColor),
                        title: Text(l10n.selectMusicFolder),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                backgroundColor: Color.fromARGB(
                                  255,
                                  235,
                                  240,
                                  245,
                                ),
                                shape: SmoothRectangleBorder(
                                  smoothness: 1,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SizedBox(
                                  height: 500,
                                  width: 400,
                                  child: Column(
                                    children: [
                                      SizedBox(height: 10),
                                      Text(
                                        'Folders',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: ValueListenableBuilder(
                                          valueListenable:
                                              foldersChangeNotifier,
                                          builder: (_, _, _) {
                                            return ListView.builder(
                                              itemCount: folderPaths.length,
                                              itemBuilder: (_, index) {
                                                return ListTile(
                                                  title: Text(
                                                    folderPaths[index],
                                                  ),

                                                  trailing: IconButton(
                                                    onPressed: () {
                                                      libraryLoader
                                                          .removeFolder(
                                                            folderPaths[index],
                                                          );
                                                    },
                                                    icon: Icon(
                                                      Icons.clear_rounded,
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          Spacer(),
                                          ElevatedButton(
                                            onPressed: () async {
                                              final result = await FilePicker
                                                  .platform
                                                  .getDirectoryPath();
                                              if (result != null) {
                                                if (!folderPaths.contains(
                                                  result,
                                                )) {
                                                  libraryLoader.addFolder(
                                                    result,
                                                  );
                                                } else if (context.mounted) {
                                                  showCenterMessage(
                                                    context,
                                                    'The folder already exists',
                                                    duration: 2000,
                                                  );
                                                }
                                              }
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              padding: EdgeInsets.all(10),
                                            ),
                                            child: Text('Add Folder'),
                                          ),
                                          SizedBox(width: 20),
                                          ElevatedButton(
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.white,
                                              foregroundColor: Colors.black,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              padding: EdgeInsets.all(10),
                                            ),
                                            child: Text('Complete'),
                                          ),
                                          Spacer(),
                                        ],
                                      ),
                                      SizedBox(height: 10),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SmoothClipRRect(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Color.fromARGB(255, 235, 240, 245),
                      child: ListTile(
                        leading: ImageIcon(infoImage, color: mainColor),
                        title: Text(l10n.openSourceLicense),
                        onTap: () {
                          panelManager.pushPanel(-2);
                        },
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: SmoothClipRRect(
                    smoothness: 1,
                    borderRadius: BorderRadius.circular(15),
                    child: Material(
                      color: Color.fromARGB(255, 235, 240, 245),
                      child: ListTile(
                        leading: ImageIcon(infoImage, color: mainColor),
                        title: Text(l10n.language),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
                                backgroundColor: Color.fromARGB(
                                  255,
                                  235,
                                  240,
                                  245,
                                ),
                                shape: SmoothRectangleBorder(
                                  smoothness: 1,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: SizedBox(
                                  height: 300,
                                  width: 100,
                                  child: ValueListenableBuilder(
                                    valueListenable: localeNotifier,
                                    builder: (context, value, child) {
                                      final l10n = AppLocalizations.of(context);

                                      return ListView(
                                        children: [
                                          ListTile(
                                            title: Text(l10n.followSystem),
                                            onTap: () {
                                              localeNotifier.value = null;
                                            },
                                            trailing: value == null
                                                ? Icon(Icons.check)
                                                : null,
                                          ),
                                          ListTile(
                                            title: Text('English'),
                                            onTap: () {
                                              localeNotifier.value = Locale(
                                                'en',
                                              );
                                            },
                                            trailing: value == Locale('en')
                                                ? Icon(Icons.check)
                                                : null,
                                          ),
                                          ListTile(
                                            title: Text('中文'),
                                            onTap: () {
                                              localeNotifier.value = Locale(
                                                'zh',
                                              );
                                            },
                                            trailing: value == Locale('zh')
                                                ? Icon(Icons.check)
                                                : null,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          );
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
