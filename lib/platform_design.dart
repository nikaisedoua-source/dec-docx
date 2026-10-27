import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Design tokens that let the same document workflow speak each host system's
/// visual language without changing the document editor itself.
class PlatformDesign {
  const PlatformDesign._({
    required this.platform,
    required this.label,
    required this.accent,
    required this.surfaceRadius,
    required this.controlRadius,
    required this.toolbarRadius,
    required this.fontFamily,
    required this.isAppleMobile,
    required this.isDesktop,
  });

  factory PlatformDesign.forTarget(TargetPlatform platform) =>
      switch (platform) {
        TargetPlatform.iOS => PlatformDesign._(
          platform: platform,
          label: 'iPhone',
          accent: const Color(0xFF0063CC),
          surfaceRadius: 22,
          controlRadius: 12,
          toolbarRadius: 24,
          fontFamily: null,
          isAppleMobile: true,
          isDesktop: false,
        ),
        TargetPlatform.macOS => PlatformDesign._(
          platform: platform,
          label: 'macOS',
          accent: const Color(0xFF0062D5),
          surfaceRadius: 14,
          controlRadius: 9,
          toolbarRadius: 14,
          fontFamily: null,
          isAppleMobile: false,
          isDesktop: true,
        ),
        TargetPlatform.windows => PlatformDesign._(
          platform: platform,
          label: 'Windows',
          accent: const Color(0xFF0067B9),
          surfaceRadius: 8,
          controlRadius: 6,
          toolbarRadius: 8,
          fontFamily: 'Segoe UI',
          isAppleMobile: false,
          isDesktop: true,
        ),
        TargetPlatform.linux => PlatformDesign._(
          platform: platform,
          label: 'Linux',
          accent: const Color(0xFF7A368C),
          surfaceRadius: 12,
          controlRadius: 8,
          toolbarRadius: 12,
          fontFamily: 'Cantarell',
          isAppleMobile: false,
          isDesktop: true,
        ),
        _ => PlatformDesign._(
          platform: platform,
          label: 'Android',
          accent: const Color(0xFF6750A4),
          surfaceRadius: 18,
          controlRadius: 14,
          toolbarRadius: 18,
          fontFamily: 'Inter',
          isAppleMobile: false,
          isDesktop: false,
        ),
      };

  factory PlatformDesign.current() =>
      PlatformDesign.forTarget(defaultTargetPlatform);

  final TargetPlatform platform;
  final String label;
  final Color accent;
  final double surfaceRadius;
  final double controlRadius;
  final double toolbarRadius;
  final String? fontFamily;
  final bool isAppleMobile;
  final bool isDesktop;

  double get contentMaxWidth => switch (platform) {
    TargetPlatform.macOS => 1360,
    TargetPlatform.windows => 1400,
    TargetPlatform.linux => 1320,
    TargetPlatform.iOS => 760,
    _ => 1200,
  };

  double get wideLayoutBreakpoint => switch (platform) {
    TargetPlatform.macOS => 1080,
    TargetPlatform.windows => 1120,
    TargetPlatform.linux => 1040,
    _ => 920,
  };

  double horizontalInset(double width) => switch (width) {
    < 480 => 16,
    < 900 => 24,
    _ => isDesktop ? 32 : 24,
  };

  double get pageTopInset => isDesktop ? 24 : 14;
  double get sectionGap => isDesktop ? 20 : 14;
  double get panelPadding => isDesktop ? 22 : (isAppleMobile ? 18 : 16);
  double get nestedRadius => switch (platform) {
    TargetPlatform.iOS => 18,
    TargetPlatform.macOS => 12,
    TargetPlatform.windows => 6,
    TargetPlatform.linux => 10,
    _ => 12,
  };
  double get buttonRadius => switch (platform) {
    TargetPlatform.iOS => 16,
    TargetPlatform.macOS => 11,
    TargetPlatform.windows => 6,
    TargetPlatform.linux => 10,
    _ => 14,
  };
  double get inputFontSize => isAppleMobile ? 16 : (isDesktop ? 14 : 15);
  double get bodyFontSize => isAppleMobile ? 16 : (isDesktop ? 14 : 15);
  double get sectionTitleSize => isDesktop ? 18 : 17;
  double get toolbarHorizontalPadding => isDesktop ? 16 : 12;
  double get toolbarVerticalPadding => isDesktop ? 10 : 8;
  double get glassBlurSigma => switch (platform) {
    TargetPlatform.iOS => 18,
    TargetPlatform.macOS => 20,
    TargetPlatform.windows => 16,
    TargetPlatform.linux => 8,
    _ => 12,
  };

  bool get isWindows => platform == TargetPlatform.windows;
  bool get isMacOS => platform == TargetPlatform.macOS;
  bool get isLinux => platform == TargetPlatform.linux;
}
