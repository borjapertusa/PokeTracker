import 'package:flutter/material.dart';

/// Muestra sprites locales/online y, opcionalmente, renderizados 3D de HOME.
/// Si el renderizado 3D no existe o no hay conexión, conserva el sprite 2D.
class Sprite extends StatelessWidget {
  final String? path;
  final double size;
  final bool pixel;
  final bool threeD;

  const Sprite(this.path,
      {this.size = 56, this.pixel = true, this.threeD = false, super.key});

  String? _homeUrl(String? source) {
    if (source == null) return null;
    // El repositorio PokeAPI usa el número de recurso de sprite como nombre.
    // No se fuerza una forma cosmética con sufijo a la forma base equivocada.
    final file = source.split('/').last;
    final match = RegExp(r'^(shiny_)?(female_)?(\d+)\.png$').firstMatch(file);
    if (match == null) return null;
    final shiny = match.group(1) != null;
    final female = match.group(2) != null;
    final id = match.group(3)!;
    final variant = shiny && female
        ? 'shiny-female'
        : shiny
            ? 'shiny'
            : female
                ? 'female'
                : null;
    final relative = variant == null ? '$id.png' : '$variant/$id.png';
    return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home/$relative';
  }

  String? _homeAssetPath(String? source) {
    if (source == null) return null;
    final file = source.split('/').last;
    return RegExp(r'^(shiny_)?(female_)?(\d+)\.png$').hasMatch(file)
        ? 'assets/sprites3d/$file'
        : null;
  }

  @override
  Widget build(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined);
    final p = path;
    final quality = pixel && !threeD ? FilterQuality.none : FilterQuality.medium;

    Widget fallback() {
      if (p == null) return const Icon(Icons.help_outline);
      return p.startsWith('http')
          ? Image.network(p, fit: BoxFit.contain, filterQuality: quality,
              errorBuilder: (_, __, ___) => broken)
          : Image.asset(p, fit: BoxFit.contain, filterQuality: quality,
              errorBuilder: (_, __, ___) => broken);
    }

    final home = threeD ? _homeUrl(p) : null;
    final local3d = threeD ? _homeAssetPath(p) : null;
    Widget network3d() => home == null
        ? fallback()
        : Image.network(
            home,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => fallback(),
          );

    return SizedBox(
      width: size,
      height: size,
      child: p == null
          ? const Icon(Icons.help_outline)
          : local3d == null
              ? fallback()
              : Image.asset(
                  local3d,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => network3d(),
                ),
    );
  }
}
