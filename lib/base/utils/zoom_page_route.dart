import 'package:material_ui/material_ui.dart';

class ZoomPageRoute<T> extends PageRoute<T> {
  ZoomPageRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      const ZoomPageTransitionsBuilder().delegatedTransition;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const ZoomPageTransitionsBuilder().buildTransitions(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  bool get opaque => true;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 600);
}
