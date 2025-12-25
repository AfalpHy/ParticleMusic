import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
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
                    child: const Text("Cancel"),
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
                    child: const Text("Confirm"),
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
