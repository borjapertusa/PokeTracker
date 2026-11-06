import 'package:flutter/material.dart';
import 'models.dart';
import 'settings.dart';

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
    final m = RegExp(r'^(shiny_)?(female_)?(\d+)\.png$').firstMatch(file);
    if (m == null) return null;
    final shiny = m.group(1) != null;
    final id = m.group(3)!.padLeft(4, '0');
    return 'assets/sprites3d/${shiny ? 'shiny' : 'regular'}_$id.webp';
  }

  @override
  Widget build(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined);
    final p = path;
    final quality = pixel && !threeD ? FilterQuality.none : FilterQuality.medium;

    Widget fallback() {
      if (p == null) return const Icon(Icons.help_outline);
      if (p.startsWith('http')) {
        if (AppSettings.current?.offlineMode == true) return broken;
        return Image.network(p, fit: BoxFit.contain, filterQuality: quality,
            errorBuilder: (_, __, ___) => broken);
      }
      // Permite mostrar los sprites aunque el paquete no incluya la carpeta local.
      final file = p.split('/').last;
      final match = RegExp(r'^(shiny_)?(female_)?(\d+)\.png$').firstMatch(file);
      if (match != null) {
        final shiny = match.group(1) != null;
        final female = match.group(2) != null;
        final id = match.group(3)!;
        final suffix = shiny
            ? (female ? 'shiny/female/' : 'shiny/')
            : (female ? 'female/' : '');
        final url = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/$suffix$id.png';
        if (AppSettings.current?.offlineMode == true) {
          return Image.asset(p, fit: BoxFit.contain, filterQuality: quality,
              errorBuilder: (_, __, ___) => broken);
        }
        // PokéPC sirve los iconos HOME 3D en WebP; se usa como primera
        // alternativa visual y se conserva PokéAPI como respaldo.
        final pokepc = 'https://static.pokepc.net/images/pokemon/home3d-icon-xl/${shiny ? 'shiny' : 'regular'}/${id.padLeft(4, '0')}.webp?v=20260515';
        final localPokepc = _homeAssetPath(p);
        Widget networkPokepc() => Image.network(pokepc, fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => Image.asset(p, fit: BoxFit.contain,
              filterQuality: quality,
              errorBuilder: (_, __, ___) => Image.network(url, fit: BoxFit.contain,
                filterQuality: quality, errorBuilder: (_, __, ___) => broken)));
        return localPokepc == null ? networkPokepc() : Image.asset(localPokepc,
          fit: BoxFit.contain, filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => networkPokepc());
      }
      return Image.asset(p, fit: BoxFit.contain, filterQuality: quality,
          errorBuilder: (_, __, ___) => broken);
    }

    final home = threeD ? _homeUrl(p) : null;
    final local3d = threeD ? _homeAssetPath(p) : null;
    Widget network3d() => AppSettings.current?.offlineMode == true
        ? fallback()
        : home == null
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

/// Identificador visual consistente para cada edición/Pokédex.
/// Usa una placa con sigla propia, de modo que no depende de recursos remotos.
class GameIcon extends StatelessWidget {
  final Game game;
  final double size;
  const GameIcon(this.game, {super.key, this.size = 38});

  static const _codes = <String, String>{
    'home': 'HOME', 'red-blue': 'RB', 'yellow': 'AM',
    'gold-silver': 'OP', 'crystal': 'CR', 'ruby-sapphire': 'RS',
    'emerald': 'EM', 'firered-leafgreen': 'RF',
    'firered-leafgreen-switch': 'RFS', 'diamond-pearl': 'DP',
    'platinum': 'PT', 'heartgold-soulsilver': 'HG',
    'black-white': 'BN', 'black-2-white-2': 'B2', 'x-y': 'XY',
    'omega-ruby-alpha-sapphire': 'OR', 'sun-moon': 'SM',
    'ultra-sun-ultra-moon': 'US', 'lets-go': 'LG',
    'sword-shield': 'ES', 'isle-of-armor': 'IA',
    'crown-tundra': 'NC', 'bdsp': 'BD', 'legends-arceus': 'LA',
    'scarlet-violet': 'EP', 'teal-mask': 'MT', 'indigo-disk': 'DI',
    'legends-za': 'ZA', 'za-mega-dimension': 'MD', 'pokopia': 'PK',
    'pokopia-dlc': 'CC',
  };

  static const _palette = <Color>[
    Color(0xFFB84B4B), Color(0xFFE0B52F), Color(0xFFB18B3C),
    Color(0xFF6387C7), Color(0xFF4E9B75), Color(0xFF8A6CC2),
    Color(0xFFE18A45), Color(0xFF5D9EAD), Color(0xFFCB668B),
    Color(0xFF3F8F8A),
  ];

  @override
  Widget build(BuildContext context) {
    final customSource = game.custom ? game.id : null;
    final code = _codes[game.id] ?? _codes[game.iconId] ??
        (game.custom && customSource != null && customSource.startsWith('custom_')
            ? 'NAC'
            : game.name.substring(0, game.name.length >= 2 ? 2 : game.name.length).toUpperCase());
    final iconGame = game.iconId ?? game.id;
    final color = iconGame == 'home'
        ? const Color(0xFF477FB5)
        : (iconGame == 'pokopia' || iconGame == 'pokopia-dlc')
            ? const Color(0xFF6B9B78)
            : _palette[(game.gen.clamp(1, 10).toInt() - 1) % _palette.length];
    return Tooltip(
      message: game.name,
      child: Container(
        width: size,
        height: size * .78,
        decoration: BoxDecoration(
          color: color.withOpacity(.16),
          border: Border.all(color: color, width: 1.6),
          borderRadius: BorderRadius.circular(size * .18),
        ),
        child: Center(
          child: Text(
            code,
            maxLines: 1,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: code.length > 3 ? size * .22 : size * .29,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
        ),
      ),
    );
  }
}
