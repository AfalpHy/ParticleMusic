import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/mobile/widgets/my_sheet.dart';
import 'package:particle_music/utils.dart';
import 'package:smooth_corner/smooth_corner.dart';

void displayTimedPauseSetting(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      Duration currentDuration = Duration();
      final l10n = AppLocalizations.of(context);

      return MySheet(
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
                      backgroundColor: buttonColor,
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
                      backgroundColor: buttonColor,
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

Widget sleepTimerListTile(
  BuildContext context,
  AppLocalizations l10n,
  bool inSetting,
) {
  return ListTile(
    leading: ImageIcon(
      timerImage,
      color: inSetting ? iconColor : Colors.black,
      size: inSetting ? 30 : null,
    ),

    title: Text(
      l10n.sleepTimer,
      style: TextStyle(fontWeight: inSetting ? null : FontWeight.bold),
    ),
    trailing: SizedBox(
      width: 150,
      child: Row(
        children: [
          Spacer(),
          ValueListenableBuilder(
            valueListenable: remainTimes,
            builder: (context, value, child) {
              final hours = (value ~/ 3600).toString().padLeft(2, '0');
              final minutes = ((value % 3600) ~/ 60).toString().padLeft(2, '0');
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
              return MySwitch(
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
  );
}

Widget pauseAfterCTListTile(BuildContext context, AppLocalizations l10n) {
  return ValueListenableBuilder(
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
                        return MySwitch(
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
  );
}
