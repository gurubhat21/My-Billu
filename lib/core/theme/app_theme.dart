import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary palette - Deep Indigo (default)
  static const Color primary = Color(0xFF4F46E5);
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark = Color(0xFF3730A3);

  // Accent - Teal
  static const Color accent = Color(0xFF14B8A6);
  static const Color accentLight = Color(0xFF5EEAD4);

  // Surface colors - Dark theme
  static const Color darkBg = Color(0xFF0F0F1A);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF222240);
  static const Color darkCardHover = Color(0xFF2A2A4A);

  // Surface colors - Light theme
  static const Color lightBg = Color(0xFFF8F9FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1F3F8);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Text
  static const Color darkTextPrimary = Color(0xFFF1F5F9);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color lightTextPrimary = Color(0xFF1E293B);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFF06B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [warning, Color(0xFFF97316)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

// ══════════════════════════════════════════════════════
// THEME PALETTE DEFINITION
// ══════════════════════════════════════════════════════

class ThemePalette {
  final String id;
  final String name;
  final IconData icon;
  final bool isDark;
  final Color primary;
  final Color accent;
  final Color bg;
  final Color surface;
  final Color card;
  final Color textPrimary;
  final Color textSecondary;
  final Color previewColor; // for theme selector UI

  const ThemePalette({
    required this.id,
    required this.name,
    required this.icon,
    required this.isDark,
    required this.primary,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.card,
    required this.textPrimary,
    required this.textSecondary,
    required this.previewColor,
  });
}

class AppTheme {
  // ══════════════════════════════════════════════════════
  // ALL AVAILABLE THEMES
  // ══════════════════════════════════════════════════════

  static const List<ThemePalette> allThemes = [
    // 1. Default Purple (current dark theme)
    ThemePalette(
      id: 'default_purple',
      name: 'Purple Night',
      icon: Icons.auto_awesome,
      isDark: true,
      primary: Color(0xFF4F46E5),
      accent: Color(0xFF14B8A6),
      bg: Color(0xFF0F0F1A),
      surface: Color(0xFF1A1A2E),
      card: Color(0xFF222240),
      textPrimary: Color(0xFFF1F5F9),
      textSecondary: Color(0xFF94A3B8),
      previewColor: Color(0xFF4F46E5),
    ),

    // 2. Neon Blue
    ThemePalette(
      id: 'neon_blue',
      name: 'Neon Blue',
      icon: Icons.bolt,
      isDark: true,
      primary: Color(0xFF00D4FF),
      accent: Color(0xFF0099FF),
      bg: Color(0xFF0A0E1A),
      surface: Color(0xFF111827),
      card: Color(0xFF1A2332),
      textPrimary: Color(0xFFE0F7FF),
      textSecondary: Color(0xFF7DD3FC),
      previewColor: Color(0xFF00D4FF),
    ),

    // 3. Neon Red
    ThemePalette(
      id: 'neon_red',
      name: 'Neon Red',
      icon: Icons.local_fire_department,
      isDark: true,
      primary: Color(0xFFFF3366),
      accent: Color(0xFFFF6B9D),
      bg: Color(0xFF120A0D),
      surface: Color(0xFF1C1015),
      card: Color(0xFF2A1520),
      textPrimary: Color(0xFFFFF0F3),
      textSecondary: Color(0xFFFDA4AF),
      previewColor: Color(0xFFFF3366),
    ),

    // 4. Neon Black (AMOLED)
    ThemePalette(
      id: 'neon_black',
      name: 'AMOLED Black',
      icon: Icons.dark_mode,
      isDark: true,
      primary: Color(0xFF00FF88),
      accent: Color(0xFF00CC6A),
      bg: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      card: Color(0xFF141414),
      textPrimary: Color(0xFFE8E8E8),
      textSecondary: Color(0xFF888888),
      previewColor: Color(0xFF00FF88),
    ),

    // 5. Neon White (Clean Light)
    ThemePalette(
      id: 'neon_white',
      name: 'Neon White',
      icon: Icons.light_mode,
      isDark: false,
      primary: Color(0xFF6C5CE7),
      accent: Color(0xFFA29BFE),
      bg: Color(0xFFFAFAFF),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFF0EEFF),
      textPrimary: Color(0xFF2D3436),
      textSecondary: Color(0xFF636E72),
      previewColor: Color(0xFF6C5CE7),
    ),

    // 6. Neon Green (Matrix)
    ThemePalette(
      id: 'neon_green',
      name: 'Matrix Green',
      icon: Icons.terminal,
      isDark: true,
      primary: Color(0xFF39FF14),
      accent: Color(0xFF00E676),
      bg: Color(0xFF050A05),
      surface: Color(0xFF0A140A),
      card: Color(0xFF122012),
      textPrimary: Color(0xFFD4FFCC),
      textSecondary: Color(0xFF66BB6A),
      previewColor: Color(0xFF39FF14),
    ),

    // 7. Ocean
    ThemePalette(
      id: 'ocean',
      name: 'Deep Ocean',
      icon: Icons.water,
      isDark: true,
      primary: Color(0xFF00BCD4),
      accent: Color(0xFF26C6DA),
      bg: Color(0xFF051622),
      surface: Color(0xFF0A2336),
      card: Color(0xFF123044),
      textPrimary: Color(0xFFE0F7FA),
      textSecondary: Color(0xFF80CBC4),
      previewColor: Color(0xFF00BCD4),
    ),

    // 8. Sunset
    ThemePalette(
      id: 'sunset',
      name: 'Sunset Glow',
      icon: Icons.wb_twilight,
      isDark: true,
      primary: Color(0xFFFF6B35),
      accent: Color(0xFFFFB347),
      bg: Color(0xFF1A0E08),
      surface: Color(0xFF261810),
      card: Color(0xFF33201A),
      textPrimary: Color(0xFFFFF3E0),
      textSecondary: Color(0xFFFFAB76),
      previewColor: Color(0xFFFF6B35),
    ),

    // 9. Royal Gold
    ThemePalette(
      id: 'royal_gold',
      name: 'Royal Gold',
      icon: Icons.workspace_premium,
      isDark: true,
      primary: Color(0xFFFFD700),
      accent: Color(0xFFFFC107),
      bg: Color(0xFF0D0B06),
      surface: Color(0xFF1A1608),
      card: Color(0xFF252010),
      textPrimary: Color(0xFFFFF8E1),
      textSecondary: Color(0xFFBDA54C),
      previewColor: Color(0xFFFFD700),
    ),

    // 10. Cherry Blossom (Light Pink)
    ThemePalette(
      id: 'cherry_blossom',
      name: 'Cherry Blossom',
      icon: Icons.spa,
      isDark: false,
      primary: Color(0xFFE91E63),
      accent: Color(0xFFFF4081),
      bg: Color(0xFFFFF5F7),
      surface: Color(0xFFFFFFFF),
      card: Color(0xFFFCE4EC),
      textPrimary: Color(0xFF37474F),
      textSecondary: Color(0xFF78909C),
      previewColor: Color(0xFFE91E63),
    ),
  ];

  static ThemePalette getPalette(String id) {
    return allThemes.firstWhere((t) => t.id == id, orElse: () => allThemes.first);
  }

  // ══════════════════════════════════════════════════════
  // BUILD THEME FROM PALETTE
  // ══════════════════════════════════════════════════════

  static ThemeData buildTheme(ThemePalette p) {
    final brightness = p.isDark ? Brightness.dark : Brightness.light;
    final baseTextTheme = p.isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme;
    final dividerColor = p.isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    final inputBorderColor = p.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: p.primary,
        onPrimary: contrastText(p.primary),
        secondary: p.accent,
        onSecondary: contrastText(p.accent),
        surface: p.surface,
        onSurface: p.textPrimary,
        error: AppColors.error,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: p.bg,
      textTheme: GoogleFonts.interTextTheme(baseTextTheme).copyWith(
        headlineLarge: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: p.textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: p.textPrimary),
        titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w500, color: p.textPrimary),
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: p.textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: p.textSecondary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: p.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: p.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: p.isDark ? BorderSide.none : BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: p.bg,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: p.textPrimary),
        iconTheme: IconThemeData(color: p.textPrimary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.primary,
          foregroundColor: contrastText(p.primary),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.primary,
          side: BorderSide(color: p.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: inputBorderColor)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.error)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.inter(color: p.textSecondary, fontSize: 14),
        labelStyle: TextStyle(color: p.textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: p.primary,
        foregroundColor: contrastText(p.primary),
        elevation: 4,
      ),
      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: p.surface,
        selectedItemColor: p.primary,
        unselectedItemColor: p.textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: p.isDark ? 0 : 8,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12),
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      drawerTheme: DrawerThemeData(backgroundColor: p.surface),
      dialogTheme: DialogThemeData(backgroundColor: p.surface),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.card,
        contentTextStyle: TextStyle(color: p.textPrimary),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        labelStyle: TextStyle(color: p.textPrimary),
        side: BorderSide(color: p.primary.withValues(alpha: 0.3)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.primary : p.textSecondary),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? p.primary.withValues(alpha: 0.4) : p.card),
      ),
    );
  }

  /// Get contrasting text color (black or white) based on luminance
  static Color contrastText(Color color) {
    return color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  // ══════════════════════════════════════════════════════
  // BACKWARD COMPAT - keep old getters working
  // ══════════════════════════════════════════════════════

  static ThemeData get darkTheme => buildTheme(allThemes.first);
  static ThemeData get lightTheme => buildTheme(allThemes[4]); // Neon White
}
