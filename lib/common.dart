import 'dart:async';

import 'package:flutter/widgets.dart';

late bool hasVibration;
ValueNotifier<bool> timedShutdown = ValueNotifier(false);
ValueNotifier<int> remainTimes = ValueNotifier(0);
Timer? shutDownTimer;
