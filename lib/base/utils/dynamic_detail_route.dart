import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:sylvakru/base/app.dart';
import 'package:sylvakru/base/utils/media_query.dart';
import 'package:sylvakru/layer/layers_manager.dart';

class DynamicDetailRoute extends PageRoute with MaterialRouteTransitionMixin {
  DynamicDetailRoute({required this.builder, required this.label});

  final WidgetBuilder builder;
  final String label;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: isMobile ? 400 : 500);

  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: isMobile ? 400 : 500);

  @override
  Widget buildContent(BuildContext context) => builder(context);

  @override
  final bool maintainState = true;

  @override
  String get debugLabel => '${super.debugLabel}(${settings.name})';

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get opaque => false;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      (context, animation, secondaryAnimation, allowSnapshotting, child) {
        if (!Platform.isIOS || !isTooNarrow(context)) {
          return child;
        }

        final tween = Tween(end: const Offset(-1 / 3, 0), begin: Offset.zero);

        final isGesture = navigator?.userGestureInProgress == true;
        if (isGesture) {
          return SlideTransition(
            position: secondaryAnimation.drive(tween),
            transformHitTests: false,
            child: child,
          );
        }
        final animation = CurvedAnimation(
          parent: secondaryAnimation,
          curve: Curves.linearToEaseOut,
          reverseCurve: Curves.easeInToLinear,
        );
        final Animation<Offset> delegatedPositionAnimation = animation.drive(
          tween,
        );
        animation.dispose();

        return SlideTransition(
          position: delegatedPositionAnimation,
          transformHitTests: false,
          child: child,
        );
      };

  @override
  bool didPop(result) {
    if (navigator?.userGestureInProgress == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        layersManager.popDetail(label, executePop: false);
      });
    }
    return super.didPop(result);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (isTooNarrow(context)) {
      if (Platform.isIOS) {
        return super.buildTransitions(
          context,
          animation,
          secondaryAnimation,
          child,
        );
      }
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: Offset(-1.0, 0.0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    }
    return child;
  }
}
