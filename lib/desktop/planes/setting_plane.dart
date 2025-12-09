import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/plane_manager.dart';
import 'package:particle_music/desktop/title_bar.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

class SettingPlane extends StatefulWidget {
  const SettingPlane({super.key});

  @override
  State<StatefulWidget> createState() => SettingPlaneState();
}

class SettingPlaneState extends State<SettingPlane> {
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
                          'Settings',
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
                        title: const Text('Reload'),
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
                        title: const Text('Select Music Folders'),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              return Dialog(
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

class LicensePagePlane extends StatefulWidget {
  const LicensePagePlane({super.key});

  @override
  State<StatefulWidget> createState() => LicensePagePlaneState();
}

class LicensePagePlaneState extends State<LicensePagePlane> {
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
                applicationVersion: '1.0.2',
                applicationLegalese: '© 2025 AfalpHy',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
