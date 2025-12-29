import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/desktop/panels/panel_manager.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/load_library.dart';
import 'package:smooth_corner/smooth_corner.dart';

ValueNotifier<bool> vibrationOnNoitifier = ValueNotifier(true);

ValueNotifier<bool> timedPause = ValueNotifier(false);
ValueNotifier<int> remainTimes = ValueNotifier(0);
ValueNotifier<bool> pauseAfterCompleted = ValueNotifier(false);
bool needPause = false;
Timer? pauseTimer;

final artistsIsListViewNotifier = ValueNotifier(true);
final artistsIsAscendingNotifier = ValueNotifier(true);
final artistsUseLargePictureNotifier = ValueNotifier(false);

final albumsIsAscendingNotifier = ValueNotifier(true);
final albumsUseLargePictureNotifier = ValueNotifier(false);

final playlistsUseLargePictureNotifier = ValueNotifier(true);

late Setting setting;

class Setting {
  final File file;
  Setting(this.file) {
    if (!(file.existsSync())) {
      saveSetting();
    }
  }

  Future<void> loadSetting() async {
    final content = await file.readAsString();

    final Map<String, dynamic> json =
        jsonDecode(content) as Map<String, dynamic>;

    artistsIsListViewNotifier.value =
        json['artistsIsList'] as bool? ?? artistsIsListViewNotifier.value;

    artistsIsAscendingNotifier.value =
        json['artistsIsAscend'] as bool? ?? artistsIsAscendingNotifier.value;

    artistsUseLargePictureNotifier.value =
        json['artistsUseLargePicture'] as bool? ??
        artistsUseLargePictureNotifier.value;

    albumsIsAscendingNotifier.value =
        json['albumsIsAscend'] as bool? ?? albumsIsAscendingNotifier.value;

    albumsUseLargePictureNotifier.value =
        json['albumsUseLargePicture'] as bool? ??
        albumsUseLargePictureNotifier.value;

    playlistsUseLargePictureNotifier.value =
        json['playlistsUseLargePicture'] as bool? ??
        playlistsUseLargePictureNotifier.value;

    vibrationOnNoitifier.value =
        json['vibrationOn'] as bool? ?? vibrationOnNoitifier.value;
  }

  void saveSetting() {
    file.writeAsStringSync(
      jsonEncode({
        'artistsIsList': artistsIsListViewNotifier.value,
        'artistsIsAscend': artistsIsAscendingNotifier.value,
        'artistsUseLargePicture': artistsUseLargePictureNotifier.value,

        'albumsIsAscend': albumsIsAscendingNotifier.value,
        'albumsUseLargePicture': albumsUseLargePictureNotifier.value,

        'playlistsUseLargePicture': playlistsUseLargePictureNotifier.value,

        'vibrationOn': vibrationOnNoitifier.value,
      }),
    );
  }

  void sortArtists() {
    artistMapEntryList.sort((a, b) {
      if (artistsIsAscendingNotifier.value) {
        return compareMixed(a.key, b.key);
      } else {
        return compareMixed(b.key, a.key);
      }
    });
  }

  void sortAlbums() {
    albumMapEntryList.sort((a, b) {
      if (albumsIsAscendingNotifier.value) {
        return compareMixed(a.key, b.key);
      } else {
        return compareMixed(b.key, a.key);
      }
    });
  }
}

void displayTimedPauseSetting(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      Duration currentDuration = Duration();
      final l10n = AppLocalizations.of(context);

      return mySheet(
        height: 350,
        Center(
          child: Column(
            children: [
              Spacer(),
              CupertinoTimerPicker(
                mode: CupertinoTimerPickerMode.hms, // hours, minutes, seconds
                onTimerDurationChanged: (Duration newDuration) {
                  currentDuration = newDuration;
                },
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      timedPause.value = false;
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: Colors.grey.shade50,
                      shadowColor: Colors.black54,
                      foregroundColor: Colors.black,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.cancel),
                  ),
                  SizedBox(width: 30),
                  ElevatedButton(
                    onPressed: () {
                      int time = 0;
                      time += currentDuration.inHours * 3600;
                      time += currentDuration.inMinutes % 60 * 60;
                      time += currentDuration.inSeconds % 60;
                      remainTimes.value = time;

                      pauseTimer ??= Timer.periodic(
                        const Duration(seconds: 1),
                        (_) {
                          if (remainTimes.value > 0) {
                            remainTimes.value--;
                          }
                          if (remainTimes.value == 0) {
                            pauseTimer!.cancel();
                            pauseTimer = null;
                            timedPause.value = false;

                            if (pauseAfterCompleted.value) {
                              needPause = true;
                            } else {
                              audioHandler.pause();
                            }
                          }
                        },
                      );

                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      elevation: 1,
                      backgroundColor: Colors.grey.shade50,
                      shadowColor: Colors.black54,
                      foregroundColor: Colors.black,
                      shape: SmoothRectangleBorder(
                        smoothness: 1,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(l10n.confirm),
                  ),

                  Spacer(),
                ],
              ),
              Spacer(),
            ],
          ),
        ),
      );
    },
  ).then((_) {
    if (remainTimes.value == 0) {
      timedPause.value = false;
    }
  });
}

class SettingsList extends StatelessWidget {
  const SettingsList({super.key});

  Widget paddingForDesktop(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: SmoothClipRRect(
        smoothness: 1,
        borderRadius: BorderRadius.circular(15),
        child: Material(
          color: Color.fromARGB(255, 235, 240, 245),
          child: child,
        ),
      ),
    );
  }

  Widget reloadListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        reloadImage,
        color: mainColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.reload),
      onTap: () async {
        if (await showConfirmDialog(context, l10n.reload)) {
          await libraryLoader.reload();
        }
      },
    );
  }

  Widget selectMusicFoldersListTile(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return ListTile(
      leading: ImageIcon(
        folderImage,
        color: mainColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.selectMusicFolder),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Color.fromARGB(255, 235, 240, 245),
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
                      l10n.folders,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                    Expanded(
                      child: ValueListenableBuilder(
                        valueListenable: foldersChangeNotifier,
                        builder: (_, _, _) {
                          return ListView.builder(
                            itemCount: folderPaths.length,
                            itemBuilder: (_, index) {
                              return ListTile(
                                title: Text(folderPaths[index]),

                                trailing: IconButton(
                                  onPressed: () {
                                    libraryLoader.removeFolder(
                                      folderPaths[index],
                                    );
                                  },
                                  icon: Icon(Icons.clear_rounded),
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
                            String? result = await FilePicker.platform
                                .getDirectoryPath();
                            if (result == null) {
                              return;
                            }

                            if (Platform.isIOS) {
                              if (result.contains(appDocs.path)) {
                                result = result.substring(
                                  result.indexOf('Documents'),
                                );
                                result = result.replaceFirst(
                                  'Documents',
                                  'Particle Music',
                                );
                              } else if (context.mounted) {
                                showCenterMessage(
                                  context,
                                  'No access permission',
                                  duration: 2000,
                                );
                                return;
                              }
                            }
                            if (folderPaths.contains(result) &&
                                context.mounted) {
                              showCenterMessage(
                                context,
                                'The folder already exists',
                                duration: 2000,
                              );
                              return;
                            }
                            libraryLoader.addFolder(result);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.all(10),
                          ),
                          child: Text(l10n.addFolder),
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
                              borderRadius: BorderRadius.circular(5),
                            ),
                            padding: EdgeInsets.all(10),
                          ),
                          child: Text(l10n.complete),
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
    );
  }

  Widget languageListTile(BuildContext context, AppLocalizations l10n) {
    return ListTile(
      leading: ImageIcon(
        infoImage,
        color: mainColor,
        size: isMobile ? 30 : null,
      ),
      title: Text(l10n.language),
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Color.fromARGB(255, 235, 240, 245),
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
                          trailing: value == null ? Icon(Icons.check) : null,
                        ),
                        ListTile(
                          title: Text('English'),
                          onTap: () {
                            localeNotifier.value = Locale('en');
                          },
                          trailing: value == Locale('en')
                              ? Icon(Icons.check)
                              : null,
                        ),
                        ListTile(
                          title: Text('中文'),
                          onTap: () {
                            localeNotifier.value = Locale('zh');
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return ListView(
      physics: ClampingScrollPhysics(),
      children: [
        if (!isMobile)
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),

        if (!isMobile)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),

            child: Divider(
              thickness: 1,
              height: 1,
              color: Colors.grey.shade300,
            ),
          ),

        isMobile
            ? ListTile(
                leading: ImageIcon(infoImage, color: mainColor, size: 30),
                title: Text(
                  l10n.openSourceLicense,
                  style: TextStyle(fontSize: 15),
                ),
                onTap: () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(
                      builder: (_) => Theme(
                        data: ThemeData(
                          colorScheme: ColorScheme.light(
                            surface: Colors
                                .grey
                                .shade50, // <- this is what LicensePage uses
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
                  );
                },
              )
            : paddingForDesktop(
                ListTile(
                  leading: ImageIcon(infoImage, color: mainColor),
                  title: Text(
                    l10n.openSourceLicense,
                    style: TextStyle(fontSize: 15),
                  ),
                  onTap: () {
                    panelManager.pushPanel(-2);
                  },
                ),
              ),

        isMobile
            ? selectMusicFoldersListTile(context, l10n)
            : paddingForDesktop(selectMusicFoldersListTile(context, l10n)),

        isMobile
            ? reloadListTile(context, l10n)
            : paddingForDesktop(reloadListTile(context, l10n)),

        isMobile
            ? languageListTile(context, l10n)
            : paddingForDesktop(languageListTile(context, l10n)),

        if (isMobile)
          ListTile(
            leading: ImageIcon(vibrationImage, color: mainColor, size: 30),
            title: Text(l10n.vibration),
            trailing: ValueListenableBuilder(
              valueListenable: vibrationOnNoitifier,
              builder: (context, value, child) {
                return SizedBox(
                  width: 50,
                  child: FlutterSwitch(
                    width: 45,
                    height: 20,
                    toggleSize: 15,
                    activeColor: mainColor,
                    inactiveColor: Colors.grey.shade300,
                    value: value,
                    onToggle: (value) {
                      tryVibrate();
                      vibrationOnNoitifier.value = value;
                      setting.saveSetting();
                    },
                  ),
                );
              },
            ),
          ),

        if (isMobile)
          ListTile(
            leading: ImageIcon(timerImage, color: mainColor, size: 30),

            title: Text(l10n.sleepTimer),
            trailing: SizedBox(
              width: 150,
              child: Row(
                children: [
                  Spacer(),
                  ValueListenableBuilder(
                    valueListenable: remainTimes,
                    builder: (context, value, child) {
                      final hours = (value ~/ 3600).toString().padLeft(2, '0');
                      final minutes = ((value % 3600) ~/ 60).toString().padLeft(
                        2,
                        '0',
                      );
                      final secs = (value % 60).toString().padLeft(2, '0');
                      return ValueListenableBuilder(
                        valueListenable: timedPause,
                        builder: (context, on, child) {
                          return value > 0 || on
                              ? Text('$hours:$minutes:$secs')
                              : SizedBox();
                        },
                      );
                    },
                  ),
                  SizedBox(width: 10),
                  ValueListenableBuilder(
                    valueListenable: timedPause,
                    builder: (context, value, child) {
                      return FlutterSwitch(
                        width: 45,
                        height: 20,
                        toggleSize: 15,
                        activeColor: mainColor,
                        inactiveColor: Colors.grey.shade300,
                        value: value,
                        onToggle: (value) async {
                          tryVibrate();
                          timedPause.value = value;
                          if (value) {
                            displayTimedPauseSetting(context);
                          } else {
                            pauseTimer?.cancel();
                            pauseTimer = null;
                            remainTimes.value = 0;
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        if (isMobile)
          ValueListenableBuilder(
            valueListenable: timedPause,
            builder: (_, value, _) {
              return value
                  ? ListTile(
                      trailing: SizedBox(
                        width: 200,
                        child: Row(
                          children: [
                            Spacer(),
                            Text(l10n.pauseAfterCurrentTrack),
                            SizedBox(width: 10),
                            ValueListenableBuilder(
                              valueListenable: pauseAfterCompleted,
                              builder: (_, value, _) {
                                return FlutterSwitch(
                                  width: 45,
                                  height: 20,
                                  toggleSize: 15,
                                  activeColor: mainColor,
                                  inactiveColor: Colors.grey.shade300,
                                  value: value,
                                  onToggle: (value) {
                                    tryVibrate();
                                    pauseAfterCompleted.value = value;
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  : SizedBox();
            },
          ),
      ],
    );
  }
}
