import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A tinted glass treatment with an opaque fallback for accessibility.
class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, required this.tint,
    this.radius = 26, this.padding = EdgeInsets.zero});

  final Widget child;
  final Color tint;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final opaque = media.highContrast || media.disableAnimations;
    final light = tint.computeLuminance() > 0.5;
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.alphaBlend(Colors.white.withValues(alpha: light ? 0.18 : 0.10), tint.withValues(alpha: opaque ? 1 : 0.90)),
            tint.withValues(alpha: opaque ? 1 : 0.78),
          ],
        ),
        border: Border.all(color: opaque
            ? (light ? Colors.black54 : Colors.white70)
            : Colors.white.withValues(alpha: light ? 0.65 : 0.30)),
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: opaque ? surface : BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: surface,
      ),
    );
  }
}
