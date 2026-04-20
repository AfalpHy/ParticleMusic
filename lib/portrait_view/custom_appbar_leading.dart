import 'dart:io';

import 'package:flutter/material.dart';

Widget customAppBarLeading(BuildContext context) {
  return IconButton(
    icon: Icon(Platform.isAndroid ? Icons.menu : null),
    onPressed: () =>
        Platform.isAndroid ? Scaffold.of(context).openDrawer() : null,
  );
}
