// lib/models/note_palette.dart

import 'package:flutter/material.dart';

/// Dark-mode memo background palette shared by the editor, the home cards and
/// the native Android widget (through [WidgetService]).
///
/// The colored entries are slightly lighter and less saturated than the
/// original values, so cards look a bit more vivid on the dark theme without
/// hurting the contrast against light text. The neutral entries (index 0 and
/// 15) keep blending with the app background.
const List<Color> kDarkNotePalette = [
  Color(0xFF1E1E1E), // Neutral (default)
  Color(0xFF633232), // Red
  Color(0xFF634B37), // Orange
  Color(0xFF635937), // Yellow / amber
  Color(0xFF39593F), // Green
  Color(0xFF395956), // Teal
  Color(0xFF374861), // Blue
  Color(0xFF433761), // Indigo
  Color(0xFF563761), // Purple
  Color(0xFF613754), // Pink
  Color(0xFF52463E), // Brown
  Color(0xFF434C50), // Blue grey
  Color(0xFF614E37), // Deep amber
  Color(0xFF465939), // Light green
  Color(0xFF38575E), // Cyan
  Color(0xFF2C2C2C), // Secondary dark grey
];
