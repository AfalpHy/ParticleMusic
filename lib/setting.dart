import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/audio_handler.dart';
import 'package:particle_music/common.dart';
import 'package:smooth_corner/smooth_corner.dart';

ValueNotifier<bool> timedPause = ValueNotifier(false);
ValueNotifier<int> remainTimes = ValueNotifier(0);
ValueNotifier<bool> pauseAfterCompleted = ValueNotifier(false);
bool needPause = false;
Timer? pauseTimer;

void displayTimedPauseSetting(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      Duration currentDuration = Duration();

      return mySheet(
        height: 400,
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
