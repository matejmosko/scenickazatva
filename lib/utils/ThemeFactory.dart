import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scenickazatva_app/models/ColorScheme.dart';
import 'package:scenickazatva_app/models/Festival.dart';

/// Parses a hex color string ("#RRGGBB", "RRGGBB", "AARRGGBB") into a [Color].
/// Returns [fallback] when the string is empty or unparseable.
Color parseFestivalColor(String? colorString, Color fallback) {
  if (colorString == null || colorString.isEmpty) return fallback;
  try {
    String cleanHex = colorString.replaceAll('#', '');
    if (cleanHex.length == 6) cleanHex = "FF$cleanHex";
    return Color(int.parse(cleanHex, radix: 16));
  } catch (_) {
    return fallback;
  }
}

/// Whether [festival] carries an explicit theming configuration worth applying.
///
/// The empty/"default" festival instance used before settings load, and any
/// festival whose color fields are still the model defaults, keep the app's
/// static chrome instead of switching to festival colors.
bool isFestivalConfigured(Festival? festival) {
  if (festival == null) return false;
  if (festival.id.isEmpty || festival.id == 'default') return false;
  final hasColors =
      (festival.festivalBackgroundColor.isNotEmpty &&
          festival.festivalBackgroundColor != 'ffffffff') ||
      (festival.festivalForegroundColor.isNotEmpty &&
          festival.festivalForegroundColor != 'ff000000') ||
      (festival.festivalThirdColor.isNotEmpty &&
          festival.festivalThirdColor != 'ff000000');
  return hasColors;
}

/// Chrome colors resolved from a configured festival. Returns null when the
/// festival is not configured, signalling the caller to use the static theme.
class FestivalChrome {
  final Color appBarBackground;
  final Color appBarForeground;
  final Color navBarBackground;
  final Color navBarIndicator;
  final Color navBarLabel;

  const FestivalChrome({
    required this.appBarBackground,
    required this.appBarForeground,
    required this.navBarBackground,
    required this.navBarIndicator,
    required this.navBarLabel,
  });
}

FestivalChrome? festivalChromeFor(Festival? festival) {
  if (!isFestivalConfigured(festival)) return null;
  final appBarBackground =
      parseFestivalColor(festival!.festivalBackgroundColor, darkColor);
  final appBarForeground =
      parseFestivalColor(festival.festivalForegroundColor, lightColor);
  final accent = parseFestivalColor(festival.festivalThirdColor, accentColor);
  return FestivalChrome(
    appBarBackground: appBarBackground,
    appBarForeground: appBarForeground,
    navBarBackground: appBarBackground,
    navBarIndicator: accent,
    navBarLabel: appBarForeground,
  );
}

bool _isLightColor(Color color) => color.computeLuminance() > 0.5;

/// Builds the app theme. When [festival] is configured (see
/// [isFestivalConfigured]) the AppBar and NavigationBar take on the festival's
/// background/foreground/third colors; otherwise the static gold/dark chrome
/// from `ColorScheme.dart` is used.
ThemeData buildFestivalTheme({
  required Brightness brightness,
  required double fontSizeFactor,
  Festival? festival,
}) {
  final isDark = brightness == Brightness.dark;
  final chrome = isDark ? null : festivalChromeFor(festival);
  final colorScheme = isDark ? darkColorScheme : lightColorScheme;
  final textColor = isDark ? lightColor : darkColor;

  final appBarBackground = chrome?.appBarBackground ?? darkColor;
  final appBarForeground = chrome?.appBarForeground ?? lightColor;
  final navBarBackground =
      chrome?.navBarBackground ?? (isDark ? colorScheme.surface : accentColor);
  final navBarIndicator = chrome?.navBarIndicator ??
      (isDark ? accentColor.withValues(alpha: 0.3) : accentColorDarker);
  final navBarLabel = chrome?.navBarLabel ?? (isDark ? lightColor : darkColor);
  final isAppBarLight = _isLightColor(appBarBackground);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Space Grotesk',
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      iconTheme: IconThemeData(color: appBarForeground),
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarIconBrightness:
            isAppBarLight ? Brightness.dark : Brightness.light,
        statusBarBrightness:
            isAppBarLight ? Brightness.light : Brightness.dark,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Space Grotesk',
        fontSize: 20.0,
        fontWeight: FontWeight.bold,
        color: appBarForeground,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: navBarBackground,
      indicatorColor: navBarIndicator,
      indicatorShape: const BeveledRectangleBorder(),
      labelTextStyle: WidgetStateProperty.all(
        TextStyle(
          color: navBarLabel,
          fontSize: 12.0,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? colorScheme.surfaceContainerHighest : lightColor,
      elevation: isDark ? 0 : 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    listTileTheme: ListTileThemeData(
      textColor: isDark ? lightColor : darkColorLighter,
      titleTextStyle: TextStyle(
        fontFamily: 'Space Grotesk',
        fontVariations: const [FontVariation('wght', 700)],
        color: isDark ? lightColor : darkColor,
        fontSize: 18.0 * fontSizeFactor,
      ),
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
          fontSize: 24.0 * fontSizeFactor,
          fontVariations: const [FontVariation('wght', 700)],
          color: textColor),
      displayMedium: TextStyle(
          fontSize: 18.0 * fontSizeFactor,
          fontStyle: FontStyle.italic,
          color: textColor),
      displaySmall: TextStyle(
          fontSize: 16.0 * fontSizeFactor,
          fontWeight: FontWeight.bold,
          color: textColor),
      titleLarge: TextStyle(fontSize: 19.0 * fontSizeFactor, color: textColor),
      titleMedium: TextStyle(
          fontSize: 16.0 * fontSizeFactor,
          fontWeight: FontWeight.w600,
          color: textColor),
      bodyLarge: TextStyle(fontSize: 14.0 * fontSizeFactor, color: textColor),
      bodyMedium: TextStyle(fontSize: 14.0 * fontSizeFactor, color: textColor),
      bodySmall: TextStyle(fontSize: 12.0 * fontSizeFactor, color: textColor),
    ),
  );
}
