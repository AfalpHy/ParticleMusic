import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';
import 'package:particle_music/utils.dart';

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
          child: ListenableBuilder(
            listenable: Listenable.merge([
              buttonColor.valueNotifier,
              lyricsPageForegroundColor.valueNotifier,
              lyricsPageButtonColor.valueNotifier,
            ]),
            builder: (context, _) {
              final specificTextColor = colorManager.getSpecificTextColor();
              final specificButtonColor = colorManager.getSpecificButtonColor();
              return Column(
                children: [
                  Spacer(),
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        pickerTextStyle: TextStyle(
                          color: specificTextColor,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    child: CupertinoTimerPicker(
                      mode: CupertinoTimerPickerMode.hms,
                      onTimerDurationChanged: (Duration newDuration) {
                        currentDuration = newDuration;
                      },
                    ),
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
                          backgroundColor: specificButtonColor,
                          foregroundColor: specificTextColor,
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
                          backgroundColor: specificButtonColor,
                          foregroundColor: specificTextColor,
                        ),
                        child: Text(l10n.confirm),
                      ),

                      Spacer(),
                    ],
                  ),
                  Spacer(),
                ],
              );
            },
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
  bool inSetting, {
  double? iconSize,
}) {
  return ListenableBuilder(
    listenable: Listenable.merge([lyricsPageForegroundColor.valueNotifier]),
    builder: (context, _) {
      final specificTextColor = inSetting
          ? null
          : lyricsPageForegroundColor.value;

      return ListTile(
        leading: ImageIcon(
          timerImage,
          size: iconSize,
          color: inSetting ? null : lyricsPageForegroundColor.value,
        ),

        title: Text(
          l10n.sleepTimer,
          style: TextStyle(
            fontWeight: inSetting ? null : FontWeight.bold,
            color: specificTextColor,
          ),
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
                  final minutes = ((value % 3600) ~/ 60).toString().padLeft(
                    2,
                    '0',
                  );
                  final secs = (value % 60).toString().padLeft(2, '0');
                  return ValueListenableBuilder(
                    valueListenable: timedPause,
                    builder: (context, on, child) {
                      return value > 0 || on
                          ? Text(
                              '$hours:$minutes:$secs',
                              style: TextStyle(color: specificTextColor),
                            )
                          : SizedBox();
                    },
                  );
                },
              ),
              SizedBox(width: 10),
              MySwitch(
                valueNotifier: timedPause,
                onToggleCallBack: () {
                  tryVibrate();
                  if (timedPause.value) {
                    displayTimedPauseSetting(context);
                  } else {
                    pauseTimer?.cancel();
                    pauseTimer = null;
                    remainTimes.value = 0;
                  }
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget pauseAfterCTListTile(BuildContext context, AppLocalizations l10n) {
  return ValueListenableBuilder(
    valueListenable: displayLyricsPageNotifier,
    builder: (context, value, child) {
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
                        ValueListenableBuilder(
                          valueListenable:
                              lyricsPageForegroundColor.valueNotifier,
                          builder: (context, value, child) {
                            return Text(
                              l10n.pauseAfterCurrentTrack,
                              style: TextStyle(
                                color: colorManager.getSpecificTextColor(),
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 10),
                        MySwitch(valueNotifier: pauseAfterCompleted),
                      ],
                    ),
                  ),
                )
              : SizedBox();
        },
      );
    },
  );
}
