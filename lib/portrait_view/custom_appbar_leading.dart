import 'dart:io';

import 'package:flutter/material.dart';
import 'package:particle_music/layer/layers_manager.dart';

Widget customAppBarLeading(BuildContext context) {
  return IconButton(
    icon: Icon(
      Platform.isAndroid ? Icons.menu : Icons.arrow_back_ios_new_rounded,
    ),
    onPressed: () => Platform.isAndroid
        ? Scaffold.of(context).openDrawer()
        : layersManager.popLayer(),
  );
}
