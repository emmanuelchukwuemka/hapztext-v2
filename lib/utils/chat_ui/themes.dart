import 'package:flutter/material.dart';

class AppThemes {
  static final ThemeData defaultDark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.teal,
    scaffoldBackgroundColor: const Color(0xFF0F0F0F),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1A1A),
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    cardColor: const Color(0xFF1E1E1E),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
      secondary: Colors.tealAccent,
      surface: const Color(0xFF1A1A1A),
    ),
  );

  static final ThemeData blueGradient = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.blue.shade400,
    scaffoldBackgroundColor: const Color(0xFF0A0E14),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF151921),
      elevation: 0,
    ),
    cardColor: const Color(0xFF1C222D),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
      secondary: Colors.blueAccent,
      surface: const Color(0xFF151921),
    ),
  );

  static final ThemeData purpleNeon = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.purpleAccent,
    scaffoldBackgroundColor: const Color(0xFF0F051D),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A0A2E),
      elevation: 0,
    ),
    cardColor: const Color(0xFF251040),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
      secondary: Colors.pinkAccent,
      surface: const Color(0xFF1A0A2E),
    ),
  );

  static final ThemeData greenDark = ThemeData(
    brightness: Brightness.dark,
    primaryColor: Colors.greenAccent,
    scaffoldBackgroundColor: const Color(0xFF051005),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF0A1F0A),
      elevation: 0,
    ),
    cardColor: const Color(0xFF0F2D0F),
    colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark).copyWith(
      secondary: Colors.lightGreenAccent,
      surface: const Color(0xFF0A1F0A),
    ),
  );

  static ThemeData getThemeFromIndex(int index) {
    switch (index) {
      case 1:
        return blueGradient;
      case 2:
        return purpleNeon;
      case 3:
        return greenDark;
      default:
        return defaultDark;
    }
  }

  static Color getBubbleColor(int themeIndex, bool isMe) {
    switch (themeIndex) {
      case 1:
        return isMe ? Colors.blue.shade600 : Colors.blueGrey.shade900;
      case 2:
        return isMe ? Colors.purple.shade600 : Colors.deepPurple.shade900;
      case 3:
        return isMe ? Colors.green.shade600 : Colors.teal.shade900;
      default:
        return isMe ? Colors.teal.shade600 : Colors.grey.shade900;
    }
  }

  static List<Color> getBubbleGradient(int themeIndex, bool isMe) {
    if (!isMe) {
      return [const Color(0xFF2A2A2A), const Color(0xFF1F1F1F)];
    }
    switch (themeIndex) {
      case 1:
        return [Colors.blue.shade400, Colors.blue.shade700];
      case 2:
        return [Colors.purple.shade400, Colors.purple.shade700];
      case 3:
        return [Colors.green.shade400, Colors.green.shade700];
      default:
        return [Colors.teal.shade400, Colors.teal.shade700];
    }
  }

  static List<Color> getBackgroundGradient(int themeIndex) {
    switch (themeIndex) {
      case 1:
        return [const Color(0xFF0A0E14), const Color(0xFF151921)];
      case 2:
        return [const Color(0xFF0F051D), const Color(0xFF1A0A2E)];
      case 3:
        return [const Color(0xFF051005), const Color(0xFF0A1F0A)];
      default:
        return [const Color(0xFF0F0F0F), const Color(0xFF1A1A1A)];
    }
  }
}
