import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/fitlog_theme.dart';
import 'fitlog_bottom_nav_bar.dart';

enum FitLogNotificationKind { success, error, info, action }

class FitLogNotifications {
  const FitLogNotifications._();

  static const Key bannerKey = ValueKey<String>('fitlog_notification_banner');
  static const Key successKey = ValueKey<String>('fitlog_notification_success');
  static const Key errorKey = ValueKey<String>('fitlog_notification_error');
  static const Key actionKey = ValueKey<String>('fitlog_notification_action');
  static const Key actionButtonKey = ValueKey<String>(
    'fitlog_notification_action_button',
  );
  static final NavigatorObserver navigatorObserver =
      _FitLogNotificationNavigatorObserver();

  static const double _screenMargin = 16;
  static const double _edgeGap = 16;
  static const Duration _successDuration = Duration(milliseconds: 2600);
  static const Duration _infoDuration = Duration(milliseconds: 3200);
  static const Duration _errorDuration = Duration(milliseconds: 4800);
  static const Duration _actionDuration = Duration(milliseconds: 6500);

  static OverlayEntry? _currentEntry;
  static OverlayState? _currentOverlay;
  static Timer? _dismissTimer;

  static void success(BuildContext context, String message) {
    _show(
      context,
      message: message,
      kind: FitLogNotificationKind.success,
      duration: _successDuration,
    );
  }

  static void successAfterNavigation(BuildContext context, String message) {
    final target = _NotificationTarget.maybeOf(context);
    if (target == null) {
      success(context, message);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (target.overlay.mounted) {
        _showOnTarget(
          target,
          message: message,
          kind: FitLogNotificationKind.success,
          duration: _successDuration,
        );
      }
    });
  }

  static void error(
    BuildContext context,
    String message, {
    double additionalBottomOffset = 0,
  }) {
    _show(
      context,
      message: message,
      kind: FitLogNotificationKind.error,
      duration: _errorDuration,
      additionalBottomOffset: additionalBottomOffset,
    );
  }

  static void topError(BuildContext context, String message) {
    _show(
      context,
      message: message,
      kind: FitLogNotificationKind.error,
      duration: _errorDuration,
      topAlignedOverride: true,
    );
  }

  static void info(BuildContext context, String message) {
    _show(
      context,
      message: message,
      kind: FitLogNotificationKind.info,
      duration: _infoDuration,
    );
  }

  static void action(
    BuildContext context,
    String message, {
    required String actionLabel,
    required VoidCallback onPressed,
  }) {
    _show(
      context,
      message: message,
      kind: FitLogNotificationKind.action,
      duration: _actionDuration,
      actionLabel: actionLabel,
      onActionPressed: onPressed,
    );
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    final entry = _currentEntry;
    final overlay = _currentOverlay;
    _currentEntry = null;
    _currentOverlay = null;
    if (entry != null && (overlay?.mounted ?? false)) {
      entry.remove();
    }
  }

  static void handleAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      dismiss();
    }
  }

  static void _show(
    BuildContext context, {
    required String message,
    required FitLogNotificationKind kind,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool? topAlignedOverride,
    double additionalBottomOffset = 0,
  }) {
    final target = _NotificationTarget.maybeOf(context);
    if (target == null) {
      _showSnackBarFallback(
        context,
        message: message,
        kind: kind,
        actionLabel: actionLabel,
        onActionPressed: onActionPressed,
      );
      return;
    }

    _showOnTarget(
      target,
      message: message,
      kind: kind,
      duration: duration,
      actionLabel: actionLabel,
      onActionPressed: onActionPressed,
      topAlignedOverride: topAlignedOverride,
      additionalBottomOffset: additionalBottomOffset,
    );
  }

  static void _showOnTarget(
    _NotificationTarget target, {
    required String message,
    required FitLogNotificationKind kind,
    required Duration duration,
    String? actionLabel,
    VoidCallback? onActionPressed,
    bool? topAlignedOverride,
    double additionalBottomOffset = 0,
  }) {
    if (!target.overlay.mounted) {
      return;
    }

    dismiss();

    final topAligned =
        topAlignedOverride ??
        (kind == FitLogNotificationKind.success ||
            kind == FitLogNotificationKind.info);

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final mediaQuery = MediaQuery.of(overlayContext);
        final keyboardInset = mediaQuery.viewInsets.bottom;
        final bottomOffset = keyboardInset > 0
            ? keyboardInset + _edgeGap + additionalBottomOffset
            : FitLogBottomNavBar.fullScreenFootprintFor(overlayContext) +
                  _edgeGap +
                  additionalBottomOffset;
        final topOffset = mediaQuery.viewPadding.top + _edgeGap;

        return Positioned(
          left: _screenMargin,
          right: _screenMargin,
          top: topAligned ? topOffset : null,
          bottom: topAligned ? null : bottomOffset,
          child: Theme(
            data: target.theme,
            child: Directionality(
              textDirection: target.textDirection,
              child: Align(
                alignment: topAligned
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: _AnimatedNotificationBanner(
                  topAligned: topAligned,
                  child: _FitLogNotificationBanner(
                    kind: kind,
                    message: message,
                    fitTheme: target.fitTheme,
                    actionLabel: actionLabel,
                    onActionPressed: onActionPressed == null
                        ? null
                        : () {
                            dismiss();
                            onActionPressed();
                          },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    var hasMounted = false;
    entry.addListener(() {
      if (entry.mounted) {
        hasMounted = true;
        return;
      }
      if (!hasMounted || !identical(_currentEntry, entry)) {
        return;
      }
      _dismissTimer?.cancel();
      _dismissTimer = null;
      _currentEntry = null;
      _currentOverlay = null;
    });
    _currentEntry = entry;
    _currentOverlay = target.overlay;
    _dismissTimer = Timer(duration, dismiss);
    target.overlay.insert(entry);
  }

  static void _showSnackBarFallback(
    BuildContext context, {
    required String message,
    required FitLogNotificationKind kind,
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      return;
    }
    final fitTheme = context.fitLogTheme;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _styleFor(kind, fitTheme).backgroundColor,
          content: Text(message),
          action: actionLabel == null || onActionPressed == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onActionPressed),
        ),
      );
  }
}

class _NotificationTarget {
  const _NotificationTarget({
    required this.overlay,
    required this.theme,
    required this.fitTheme,
    required this.textDirection,
  });

  final OverlayState overlay;
  final ThemeData theme;
  final FitLogThemeData fitTheme;
  final TextDirection textDirection;

  static _NotificationTarget? maybeOf(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      return null;
    }
    return _NotificationTarget(
      overlay: overlay,
      theme: Theme.of(context),
      fitTheme: context.fitLogTheme,
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    );
  }
}

class _FitLogNotificationNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FitLogNotifications.dismiss();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FitLogNotifications.dismiss();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    FitLogNotifications.dismiss();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    FitLogNotifications.dismiss();
  }
}

class _AnimatedNotificationBanner extends StatelessWidget {
  const _AnimatedNotificationBanner({
    required this.topAligned,
    required this.child,
  });

  final bool topAligned;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        final dy = (topAligned ? -10 : 10) * (1 - value);
        return Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, dy), child: child),
        );
      },
      child: child,
    );
  }
}

class _FitLogNotificationBanner extends StatelessWidget {
  const _FitLogNotificationBanner({
    required this.kind,
    required this.message,
    required this.fitTheme,
    this.actionLabel,
    this.onActionPressed,
  });

  final FitLogNotificationKind kind;
  final String message;
  final FitLogThemeData fitTheme;
  final String? actionLabel;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(kind, fitTheme);
    final textTheme = Theme.of(context).textTheme;
    final messageStyle = (textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
        .copyWith(
          color: style.textColor,
          fontWeight: FontWeight.w700,
          height: 1.3,
        );
    final actionTextStyle =
        (textTheme.labelLarge ?? const TextStyle(fontSize: 14)).copyWith(
          color: fitTheme.primaryDeep,
          fontWeight: FontWeight.w800,
        );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Material(
        key: _keyFor(kind),
        color: Colors.transparent,
        child: Semantics(
          liveRegion: true,
          label: message,
          child: Container(
            key: FitLogNotifications.bannerKey,
            constraints: BoxConstraints(
              maxHeight: math.min(
                MediaQuery.sizeOf(context).height * 0.34,
                220,
              ),
            ),
            decoration: BoxDecoration(
              color: style.backgroundColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: style.borderColor),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: fitTheme.shadow.withValues(
                    alpha: fitTheme.isDark ? 0.28 : 0.10,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Icon(style.icon, color: style.iconColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(message, style: messageStyle)),
                  if (actionLabel != null && onActionPressed != null) ...[
                    const SizedBox(width: 10),
                    TextButton(
                      key: FitLogNotifications.actionButtonKey,
                      onPressed: onActionPressed,
                      style: TextButton.styleFrom(
                        foregroundColor: fitTheme.primaryDeep,
                        textStyle: actionTextStyle,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(actionLabel!),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Key _keyFor(FitLogNotificationKind kind) {
    switch (kind) {
      case FitLogNotificationKind.success:
        return FitLogNotifications.successKey;
      case FitLogNotificationKind.error:
        return FitLogNotifications.errorKey;
      case FitLogNotificationKind.info:
        return const ValueKey<String>('fitlog_notification_info');
      case FitLogNotificationKind.action:
        return FitLogNotifications.actionKey;
    }
  }
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.icon,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final IconData icon;
}

_NotificationStyle _styleFor(
  FitLogNotificationKind kind,
  FitLogThemeData fitTheme,
) {
  switch (kind) {
    case FitLogNotificationKind.success:
      return _NotificationStyle(
        backgroundColor: fitTheme.primarySoftSelected,
        borderColor: fitTheme.primaryBright.withValues(alpha: 0.46),
        textColor: fitTheme.primaryDeep,
        iconColor: fitTheme.primary,
        icon: Icons.check_circle_rounded,
      );
    case FitLogNotificationKind.error:
      return _NotificationStyle(
        backgroundColor: fitTheme.warningSurface,
        borderColor: fitTheme.warningBorder,
        textColor: fitTheme.warningText,
        iconColor: fitTheme.warningText,
        icon: Icons.error_outline_rounded,
      );
    case FitLogNotificationKind.info:
      return _NotificationStyle(
        backgroundColor: fitTheme.surfaceElevated,
        borderColor: fitTheme.outline,
        textColor: fitTheme.textPrimary,
        iconColor: fitTheme.primary,
        icon: Icons.info_outline_rounded,
      );
    case FitLogNotificationKind.action:
      return _NotificationStyle(
        backgroundColor: fitTheme.surfaceElevated,
        borderColor: fitTheme.outline,
        textColor: fitTheme.textPrimary,
        iconColor: fitTheme.primary,
        icon: Icons.touch_app_outlined,
      );
  }
}
