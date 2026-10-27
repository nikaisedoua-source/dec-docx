import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'platform_design.dart';

/// A tinted glass treatment with an opaque fallback for accessibility.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    required this.tint,
    this.radius = 26,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final Color tint;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final platformDesign = PlatformDesign.current();
    final opaque = media.highContrast || media.disableAnimations;
    final light = tint.computeLuminance() > 0.5;
    final effectiveTint = tint.withValues(
      alpha: opaque ? 1 : (light ? .94 : .88),
    );
    final edgeColor = opaque
        ? (light ? Colors.black54 : Colors.white70)
        : (light
              ? Colors.black.withValues(alpha: .065)
              : Colors.white.withValues(alpha: .2));
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(
              Colors.white.withValues(alpha: light ? .48 : .12),
              effectiveTint,
            ),
            effectiveTint.withValues(alpha: opaque ? 1 : (light ? .94 : .82)),
          ],
        ),
        border: Border.all(color: edgeColor, width: 1),
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: opaque
          ? surface
          : BackdropFilter(
              filter: ui.ImageFilter.blur(
                sigmaX: platformDesign.glassBlurSigma,
                sigmaY: platformDesign.glassBlurSigma,
              ),
              child: surface,
            ),
    );
  }
}
