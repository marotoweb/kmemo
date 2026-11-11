// lib/ui/widgets/app_snackbar.dart

import 'package:flutter/material.dart';

/// Builds a snackbar with theme-aware colors so the message and the action
/// stay readable in both light and dark themes.
///
/// The old amber action color was hard to read on the light surface that the
/// dark theme uses for snackbars. Custom backgrounds (error/success) also get
/// a foreground computed from their brightness instead of relying on the
/// default snackbar text color.
SnackBar buildAppSnackBar(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
  Color? backgroundColor,
}) {
  final scheme = Theme.of(context).colorScheme;
  final hasCustomBackground = backgroundColor != null;
  final background = backgroundColor ?? scheme.inverseSurface;
  final foreground = hasCustomBackground
      ? (ThemeData.estimateBrightnessForColor(background) == Brightness.dark
            ? Colors.white
            : Colors.black87)
      : scheme.onInverseSurface;
  final actionColor = hasCustomBackground
      ? foreground
      : scheme.inversePrimary;

  return SnackBar(
    content: Text(message, style: TextStyle(color: foreground)),
    backgroundColor: background,
    duration: duration,
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(
            label: actionLabel,
            textColor: actionColor,
            onPressed: onAction,
          )
        : null,
  );
}
