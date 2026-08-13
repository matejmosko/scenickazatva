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
/// Only the AppBar follows the festival colors; the bottom navigation bar
/// always uses the fixed javisko.sk colors (see [buildFestivalTheme]).
class FestivalChrome {
  final Color appBarBackground;
  final Color appBarForeground;

  const FestivalChrome({
    required this.appBarBackground,
    required this.appBarForeground,
  });
}

FestivalChrome? festivalChromeFor(Festival? festival) {
  if (!isFestivalConfigured(festival)) return null;
  final appBarBackground =
      parseFestivalColor(festival!.festivalBackgroundColor, darkColor);
  final appBarForeground =
      parseFestivalColor(festival.festivalForegroundColor, lightColor);
  return FestivalChrome(
    appBarBackground: appBarBackground,
    appBarForeground: appBarForeground,
  );
}

bool _isLightColor(Color color) => color.computeLuminance() > 0.5;

/// Builds the app theme. The AppBar takes on the festival colors when
/// [festival] is configured (see [isFestivalConfigured]); otherwise it uses
/// the static dark chrome from `ColorScheme.dart`. The bottom navigation bar
/// always uses the fixed javisko.sk colors (black background, gold selected
/// item, white foreground) and never follows the festival.
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
  final isAppBarLight = _isLightColor(appBarBackground);

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    fontFamily: 'Space Grotesk',
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      toolbarHeight: 48,
      iconTheme: IconThemeData(color: appBarForeground),
      backgroundColor: appBarBackground,
      foregroundColor: appBarForeground,
      systemOverlayStyle: SystemUiOverlayStyle(
        // Transparent so the AppBar background paints behind the status bar
        // and blends with the system UI (matches the M3 default). Ignored on
        // Android 15+ where edge-to-edge is enforced.
        statusBarColor: Colors.transparent,
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
      backgroundColor: const Color(0xFF000000),
      indicatorColor: Colors.transparent,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(color: selected ? accentColor : Colors.white);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          color: selected ? accentColor : Colors.white,
          fontSize: 12.0,
        );
      }),
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
