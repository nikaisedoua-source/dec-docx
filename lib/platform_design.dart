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
          accent: const Color(0xFF0A84FF),
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
          accent: const Color(0xFF007AFF),
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
          accent: const Color(0xFF0078D4),
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
          accent: const Color(0xFF9141AC),
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

  bool get isWindows => platform == TargetPlatform.windows;
  bool get isMacOS => platform == TargetPlatform.macOS;
  bool get isLinux => platform == TargetPlatform.linux;
}
