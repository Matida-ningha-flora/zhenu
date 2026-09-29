import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

class AppTheme {
  static const double radius = 16;

  static ThemeData get lightTheme => _build(Brightness.light);
  static ThemeData get darkTheme => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // Clair : caramel sur ivoire. Sombre : caramel clair sur espresso.
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFE8A25E) : AppColors.primaryDeep,
      onPrimary: isDark ? const Color(0xFF3A1F08) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF5A3A1E) : AppColors.primarySoft,
      onPrimaryContainer:
          isDark ? const Color(0xFFFCE3C8) : AppColors.primaryDark,
      secondary: isDark ? const Color(0xFFEFC169) : AppColors.secondaryDeep,
      onSecondary: isDark ? const Color(0xFF3A2A05) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF4A3712) : AppColors.secondarySoft,
      onSecondaryContainer:
          isDark ? const Color(0xFFFBE7B5) : const Color(0xFF6B4A0B),
      error: isDark ? const Color(0xFFF2A08F) : AppColors.error,
      onError: isDark ? const Color(0xFF3B0D05) : Colors.white,
      surface: isDark ? AppColors.darkSurface : AppColors.surface,
      onSurface: isDark ? const Color(0xFFF3E9E1) : AppColors.textPrimary,
      onSurfaceVariant:
          isDark ? const Color(0xFFC4B1A3) : AppColors.textSecondary,
      surfaceContainerLowest: isDark ? AppColors.darkBackground : Colors.white,
      surfaceContainerLow:
          isDark ? const Color(0xFF251C19) : AppColors.background,
      surfaceContainer: isDark ? AppColors.darkCard : AppColors.surfaceMuted,
      surfaceContainerHigh:
          isDark ? const Color(0xFF47372F) : const Color(0xFFEDE3D7),
      surfaceContainerHighest:
          isDark ? const Color(0xFF524036) : const Color(0xFFE5D8C9),
      outline: isDark ? const Color(0xFF6B574B) : const Color(0xFFD2C0AE),
      outlineVariant: isDark ? AppColors.darkBorder : AppColors.border,
      shadow: Colors.black,
      inverseSurface: isDark ? const Color(0xFFF3E9E1) : AppColors.textPrimary,
      onInverseSurface: isDark ? AppColors.textPrimary : Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final text = GoogleFonts.interTextTheme(base.textTheme)
        .copyWith(
          headlineLarge: GoogleFonts.poppins(
              fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.4),
          headlineMedium: GoogleFonts.poppins(
              fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          headlineSmall: GoogleFonts.poppins(
              fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          titleLarge: GoogleFonts.poppins(
              fontSize: 19, fontWeight: FontWeight.w600, letterSpacing: -0.1),
          titleMedium:
              GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          titleSmall:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          bodyLarge: GoogleFonts.inter(fontSize: 16, height: 1.5),
          bodyMedium: GoogleFonts.inter(fontSize: 14, height: 1.45),
          bodySmall: GoogleFonts.inter(fontSize: 12.5, height: 1.4),
          labelLarge:
              GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
          labelMedium:
              GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
          labelSmall: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.6),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    final buttonText =
        GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600);
    const buttonSize = Size(64, 52);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );

    return base.copyWith(
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      }),
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.background,
      textTheme: text,
      primaryColor: scheme.primary,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor:
            isDark ? AppColors.darkBackground : AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: buttonSize,
          elevation: 0,
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonSize,
          shape: shape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonSize,
          shape: shape,
          textStyle: buttonText,
          side: BorderSide(color: scheme.outline),
          foregroundColor: scheme.onSurface,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle:
              GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: inputBorder(scheme.outlineVariant),
        enabledBorder: inputBorder(scheme.outlineVariant),
        focusedBorder: inputBorder(scheme.primary, 1.6),
        errorBorder: inputBorder(scheme.error),
        focusedErrorBorder: inputBorder(scheme.error, 1.6),
        labelStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant),
        hintStyle: GoogleFonts.inter(
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle:
            WidgetStateProperty.resolveWith((states) => GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: states.contains(WidgetState.selected)
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: states.contains(WidgetState.selected)
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            )),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          textStyle:
              GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
          selectedBackgroundColor: scheme.primaryContainer,
          selectedForegroundColor: scheme.onPrimaryContainer,
          side: BorderSide(color: scheme.outlineVariant),
          minimumSize: const Size(0, 44),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: BorderSide(color: scheme.outlineVariant),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 18),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        titleTextStyle: text.titleSmall,
        subtitleTextStyle:
            text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
          color: scheme.outlineVariant, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            GoogleFonts.inter(color: scheme.onInverseSurface, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: text.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.white : null),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? scheme.primary : null),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        labelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700),
        unselectedLabelStyle:
            GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        dividerColor: scheme.outlineVariant,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
      ),
    );
  }
}
