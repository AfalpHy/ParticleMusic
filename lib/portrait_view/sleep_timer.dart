import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:particle_music/color_manager.dart';
import 'package:particle_music/common.dart';
import 'package:particle_music/common_widgets/my_switch.dart';
import 'package:particle_music/l10n/generated/app_localizations.dart';
import 'package:particle_music/common_widgets/my_sheet.dart';

void displayTimedPauseSetting(BuildContext context) {
  pauseTimer?.cancel();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    builder: (context) {
      Duration currentDuration = Duration(seconds: remainTimesNotifier.value);
      final l10n = AppLocalizations.of(context);

      return MySheet(
        height: 350,
        ListenableBuilder(
          listenable: Listenable.merge([
            buttonColor.valueNotifier,
            lyricsPageForegroundColor.valueNotifier,
            lyricsPageButtonColor.valueNotifier,
          ]),
          builder: (context, _) {
            final specificTextColor = colorManager.getSpecificTextColor();
            final specificButtonColor = colorManager.getSpecificButtonColor();
            return Column(
              mainAxisAlignment: .center,
              children: [
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    MySwitch(
                      trueText: l10n.pauseAfterCurrentTrack,
                      falseText: l10n.pauseAfterCurrentTrack,
                      valueNotifier: pauseAfterCompletedNotifier,
                    ),
                  ],
                ),
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
                    initialTimerDuration: Duration(
                      seconds: remainTimesNotifier.value,
                    ),
                    onTimerDurationChanged: (Duration newDuration) {
                      currentDuration = newDuration;
                    },
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: .center,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        sleepTimerOnNotifier.value = false;
                        remainTimesNotifier.value = 0;
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: specificButtonColor,
                        foregroundColor: specificTextColor,
                      ),
                      child: Text(l10n.close),
                    ),
                    SizedBox(width: 30),
                    ElevatedButton(
                      onPressed: () {
                        int time = 0;
                        time += currentDuration.inHours * 3600;
                        time += currentDuration.inMinutes % 60 * 60;
                        time += currentDuration.inSeconds % 60;
                        remainTimesNotifier.value = time;

                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: specificButtonColor,
                        foregroundColor: specificTextColor,
                      ),
                      child: Text(l10n.confirm),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    },
  ).then((_) {
    if (remainTimesNotifier.value == 0) {
      sleepTimerOnNotifier.value = false;
    } else {
      sleepTimerOnNotifier.value = true;

      pauseTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (remainTimesNotifier.value > 0) {
          remainTimesNotifier.value--;
        }
        if (remainTimesNotifier.value == 0) {
          pauseTimer?.cancel();
          sleepTimerOnNotifier.value = false;

          if (pauseAfterCompletedNotifier.value) {
            needPause = true;
          } else {
            audioHandler.pause();
          }
        }
      });
    }
  });
}

Widget sleepTimerListTile(
  BuildContext context,
  AppLocalizations l10n, {
  double? iconSize,
}) {
  return ListTile(
    leading: ImageIcon(timerImage, size: iconSize),

    title: Text(l10n.sleepTimer),
    onTap: () {
      displayTimedPauseSetting(context);
    },
    trailing: Transform.translate(
      offset: Offset(-5, 0),
      child: remainTimesText(),
    ),
  );
}

Widget remainTimesText({Color? textColor}) {
  return ValueListenableBuilder(
    valueListenable: remainTimesNotifier,
    builder: (context, value, child) {
      final hours = (value ~/ 3600).toString().padLeft(2, '0');
      final minutes = ((value % 3600) ~/ 60).toString().padLeft(2, '0');
      final secs = (value % 60).toString().padLeft(2, '0');
      return value > 0
          ? Text('$hours:$minutes:$secs', style: TextStyle(color: textColor))
          : SizedBox();
    },
  );
}
