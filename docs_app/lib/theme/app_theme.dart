import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Stripe / Linear-style docs theme.
///
/// Two near-monochrome palettes (one light, one dark) with a single accent
/// pulled from Linear's brand purple. Typography is Inter + JetBrains Mono.
class AppTheme {
  static const Color _accent = Color(0xFF5E6AD2); // Linear-ish indigo

  // --- Light palette ----------------------------------------------------
  static const Color _lBg = Color(0xFFFAFAFA);
  static const Color _lSurface = Color(0xFFFFFFFF);
  static const Color _lSurfaceMuted = Color(0xFFF4F4F5);
  static const Color _lBorder = Color(0xFFE4E4E7);
  static const Color _lText = Color(0xFF09090B);
  static const Color _lTextMuted = Color(0xFF52525B);
  static const Color _lTextSubtle = Color(0xFF71717A);

  // --- Dark palette -----------------------------------------------------
  static const Color _dBg = Color(0xFF0B0B0E);
  static const Color _dSurface = Color(0xFF121216);
  static const Color _dSurfaceMuted = Color(0xFF18181C);
  static const Color _dBorder = Color(0xFF26262C);
  static const Color _dText = Color(0xFFFAFAFA);
  static const Color _dTextMuted = Color(0xFFA1A1AA);
  static const Color _dTextSubtle = Color(0xFF71717A);

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: _accent,
        secondary: _accent,
        surface: _lSurface,
        onSurface: _lText,
        surfaceContainerHighest: _lSurfaceMuted,
        outline: _lBorder,
      ),
      scaffoldBackgroundColor: _lBg,
      dividerColor: _lBorder,
      textTheme: _textTheme(_lText, _lTextMuted),
      iconTheme: const IconThemeData(color: _lTextMuted, size: 18),
      extensions: const [
        DocsTokens(
          background: _lBg,
          surface: _lSurface,
          surfaceMuted: _lSurfaceMuted,
          border: _lBorder,
          text: _lText,
          textMuted: _lTextMuted,
          textSubtle: _lTextSubtle,
          accent: _accent,
        ),
      ],
    );
  }

  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _accent,
        secondary: _accent,
        surface: _dSurface,
        onSurface: _dText,
        surfaceContainerHighest: _dSurfaceMuted,
        outline: _dBorder,
      ),
      scaffoldBackgroundColor: _dBg,
      dividerColor: _dBorder,
      textTheme: _textTheme(_dText, _dTextMuted),
      iconTheme: const IconThemeData(color: _dTextMuted, size: 18),
      extensions: const [
        DocsTokens(
          background: _dBg,
          surface: _dSurface,
          surfaceMuted: _dSurfaceMuted,
          border: _dBorder,
          text: _dText,
          textMuted: _dTextMuted,
          textSubtle: _dTextSubtle,
          accent: _accent,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color text, Color textMuted) {
    final inter = GoogleFonts.interTextTheme();
    return inter.copyWith(
      displayLarge: inter.displayLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.2,
        height: 1.1,
      ),
      headlineLarge: inter.headlineLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.15,
        fontSize: 36,
      ),
      headlineMedium: inter.headlineMedium?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.25,
        fontSize: 24,
      ),
      headlineSmall: inter.headlineSmall?.copyWith(
        color: text,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.3,
        fontSize: 18,
      ),
      bodyLarge: inter.bodyLarge?.copyWith(
        color: text,
        fontSize: 15.5,
        height: 1.65,
        letterSpacing: -0.1,
      ),
      bodyMedium: inter.bodyMedium?.copyWith(
        color: textMuted,
        fontSize: 14,
        height: 1.6,
      ),
      bodySmall: inter.bodySmall?.copyWith(color: textMuted, fontSize: 13, height: 1.55),
      labelLarge: inter.labelLarge?.copyWith(
        color: text,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
      labelMedium: inter.labelMedium?.copyWith(color: textMuted, fontSize: 12),
      labelSmall: inter.labelSmall?.copyWith(color: textMuted, fontSize: 11),
    );
  }

  static TextStyle mono({Color? color, double size = 13, FontWeight weight = FontWeight.w400}) {
    return GoogleFonts.jetBrainsMono(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: 1.6,
      letterSpacing: 0,
    );
  }
}

/// Custom palette tokens exposed via [ThemeExtension]. Use:
///   `Theme.of(context).extension<DocsTokens>()!`
class DocsTokens extends ThemeExtension<DocsTokens> {
  const DocsTokens({
    required this.background,
    required this.surface,
    required this.surfaceMuted,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textSubtle,
    required this.accent,
  });

  final Color background;
  final Color surface;
  final Color surfaceMuted;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color textSubtle;
  final Color accent;

  @override
  DocsTokens copyWith({
    Color? background,
    Color? surface,
    Color? surfaceMuted,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? textSubtle,
    Color? accent,
  }) {
    return DocsTokens(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceMuted: surfaceMuted ?? this.surfaceMuted,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      textSubtle: textSubtle ?? this.textSubtle,
      accent: accent ?? this.accent,
    );
  }

  @override
  DocsTokens lerp(ThemeExtension<DocsTokens>? other, double t) {
    if (other is! DocsTokens) return this;
    return DocsTokens(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSubtle: Color.lerp(textSubtle, other.textSubtle, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}

/// Quick accessor for [DocsTokens] inside widget builds.
extension DocsTokensContext on BuildContext {
  DocsTokens get tokens => Theme.of(this).extension<DocsTokens>()!;
}
