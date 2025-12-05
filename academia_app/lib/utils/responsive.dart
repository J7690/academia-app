import 'package:flutter/widgets.dart';

/// Global breakpoints for the app. All responsive layouts should rely on these
/// values to keep behavior consistent across screens.
class AppBreakpoints {
  static const double mobile = 600;
  static const double tablet = 1024;
  static const double desktop = 1440;
}

enum DeviceSize {
  mobile,
  tablet,
  desktop,
}

extension ResponsiveContext on BuildContext {
  Size get screenSize => MediaQuery.of(this).size;
  double get screenWidth => screenSize.width;
  double get screenHeight => screenSize.height;

  DeviceSize get deviceSize {
    final width = screenWidth;
    if (width < AppBreakpoints.mobile) {
      return DeviceSize.mobile;
    }
    if (width < AppBreakpoints.tablet) {
      return DeviceSize.tablet;
    }
    return DeviceSize.desktop;
  }

  bool get isMobile => deviceSize == DeviceSize.mobile;
  bool get isTablet => deviceSize == DeviceSize.tablet;
  bool get isDesktop => deviceSize == DeviceSize.desktop;
}

/// Generic responsive layout helper that lets a screen declare different
/// widget trees for mobile / tablet / desktop.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    if (width < AppBreakpoints.mobile) {
      return mobile(context);
    }

    if (width < AppBreakpoints.tablet) {
      return (tablet ?? mobile)(context);
    }

    return (desktop ?? tablet ?? mobile)(context);
  }
}
