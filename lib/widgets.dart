import 'package:flutter/material.dart';

/// Muestra un sprite local (assets/sprites/...) o, como respaldo, uno online (http).
class Sprite extends StatelessWidget {
  final String? path;
  final double size;
  final bool pixel;
  const Sprite(this.path, {this.size = 56, this.pixel = true, super.key});

  @override
  Widget build(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined);
    final p = path;
    final quality = pixel ? FilterQuality.none : FilterQuality.medium;
    return SizedBox(
      width: size,
      height: size,
      child: p == null
          ? const Icon(Icons.help_outline)
          : p.startsWith('http')
              ? Image.network(p,
                  fit: BoxFit.contain,
                  filterQuality: quality,
                  errorBuilder: (_, __, ___) => broken)
              : Image.asset(p,
                  fit: BoxFit.contain,
                  filterQuality: quality,
                  errorBuilder: (_, __, ___) => broken),
    );
  }
}
