import 'package:flutter/material.dart';

// Built using https://m3.material.io/theme-builder#/custom

Color darkColor = Color(0xFF050404);
Color darkColorLighter = Colors.black87;
Color lightColor = Colors.white;
Color lightColorDarker = Colors.white;
Color accentColor = Color(0xffCCA965);
Color accentColorDarker = Color(0xbbCCA965);
Color buttonColor = Color(0xbb914DFF);
Color lightColorTransparent = Colors.white54;
Color festivalBackgroundColor = Colors.white;
Color festivalForegroundColor = Colors.black;
Color festivalThirdColor = Colors.white;

var lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: accentColor,
  onPrimary: Colors.white,
  primaryContainer: lightColorDarker,
  onPrimaryContainer: darkColor,
  secondary: lightColorDarker,
  onSecondary: darkColor,
  secondaryContainer: accentColor,
  onSecondaryContainer: lightColorDarker,
  tertiary: lightColorDarker,
  onTertiary: darkColorLighter,
  tertiaryContainer: lightColorDarker,
  onTertiaryContainer: darkColor,
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  surface: lightColorDarker,
  onSurface: darkColor,
  surfaceContainerHighest: lightColorDarker,
  onSurfaceVariant: darkColor,
  outline: darkColorLighter,
  onInverseSurface: lightColorDarker,
  inverseSurface: accentColorDarker,
  inversePrimary: darkColor,
  shadow: Color(0xFF000000),
  surfaceTint: Colors.transparent,
  outlineVariant: accentColor,
  scrim: Color(0xFF000000),
);

var darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: accentColor,
  onPrimary: darkColor,
  primaryContainer: Color(0xFF1A1A1A),
  onPrimaryContainer: accentColor,
  secondary: Color(0xFF2D2D2D),
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFF3D3D3D),
  onSecondaryContainer: Colors.white,
  tertiary: accentColor,
  onTertiary: darkColor,
  tertiaryContainer: Color(0xFF262626),
  onTertiaryContainer: accentColor,
  error: Color(0xFFCF6679),
  errorContainer: Color(0xFFB00020),
  onError: Colors.black,
  onErrorContainer: Colors.white,
  surface: Color(0xFF121212),
  onSurface: Colors.white,
  surfaceContainerHighest: Color(0xFF1E1E1E),
  onSurfaceVariant: Colors.white70,
  outline: Colors.white30,
  onInverseSurface: darkColor,
  inverseSurface: Colors.white,
  inversePrimary: accentColor,
  shadow: Color(0xFF000000),
  surfaceTint: Colors.transparent,
  outlineVariant: accentColor,
  scrim: Color(0xFF000000),
);

/* Color darkColor = Colors.black87;
Color darkColorLighter = Colors.blueGrey;
Color lightColor = Colors.white;
Color lightColorDarker = Color(0xFFF0F0F0);
Color accentColor = Color(0xFF18003a);
Color accentColorDarker = Color(0xFF513582);
Color lightColorTransparent = Colors.white54;

var lightColorScheme = ColorScheme(
  brightness: Brightness.light,
  primary: accentColor,
  onPrimary: darkColor,
  primaryContainer: lightColor,
  onPrimaryContainer: darkColor,
  secondary: lightColor,
  onSecondary: darkColor,
  secondaryContainer: accentColor,
  onSecondaryContainer: lightColor,
  tertiary: darkColor,
  onTertiary: darkColor,
  tertiaryContainer: lightColor,
  onTertiaryContainer: darkColor,
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: lightColorDarker,
  onBackground: darkColor,
  surface: lightColor,
  onSurface: darkColor,
  surfaceVariant: darkColorLighter,
  onSurfaceVariant: darkColorLighter,
  outline: darkColorLighter,
  onInverseSurface: lightColorDarker,
  inverseSurface: accentColorDarker,
  inversePrimary: darkColor,
  shadow: Color(0xFF000000),
  surfaceTint: lightColor,
  outlineVariant: accentColor,
  scrim: Color(0xFF000000),
);

var darkColorScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: accentColor,
  onPrimary: darkColor,
  primaryContainer: darkColor,
  onPrimaryContainer: lightColor,
  secondary: darkColor,
  onSecondary: lightColor,
  secondaryContainer: accentColor,
  onSecondaryContainer: lightColor,
  tertiary: lightColor,
  onTertiary: darkColor,
  tertiaryContainer: lightColor,
  onTertiaryContainer: darkColor,
  error: Color(0xFFBA1A1A),
  errorContainer: Color(0xFFFFDAD6),
  onError: Color(0xFFFFFFFF),
  onErrorContainer: Color(0xFF410002),
  background: darkColor,
  onBackground: lightColor,
  surface: lightColor,
  onSurface: darkColor,
  surfaceVariant: darkColorLighter,
  onSurfaceVariant: darkColorLighter,
  outline: darkColorLighter,
  onInverseSurface: lightColorDarker,
  inverseSurface: accentColorDarker,
  inversePrimary: darkColor,
  shadow: Color(0xFF000000),
  surfaceTint: lightColor,
  outlineVariant: accentColor,
  scrim: Color(0xFF000000),
);
 */