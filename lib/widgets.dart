import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'models.dart';
import 'settings.dart';
import 'pokepc_local_repository.dart';

/// Muestra sprites locales/online y, opcionalmente, renderizados 3D de HOME.
/// Si el renderizado 3D no existe o no hay conexión, conserva el sprite 2D.
class Sprite extends StatelessWidget {
  final String? path;
  final double size;
  final bool pixel;
  final bool threeD;

  const Sprite(this.path,
      {this.size = 56, this.pixel = true, this.threeD = false, super.key});

  // Compiladas una sola vez (antes se creaban en cada build de cada sprite).
  static final _pngRe = RegExp(r'^(shiny_)?(female_)?(\d+)\.png$');
  static final _tokenRe =
      RegExp(r'^pokepc(-shiny)?:([0-9]{4}(?:-[a-z0-9-]+)?)$');

  String? _homeUrl(String? source) {
    if (source == null) return null;
    // El repositorio PokeAPI usa el número de recurso de sprite como nombre.
    // No se fuerza una forma cosmética con sufijo a la forma base equivocada.
    final file = source.split('/').last;
    final match = _pngRe.firstMatch(file);
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

  File? _homeDataFile(String? source) {
    if (source == null) return null;

    // Los registros importados desde PokéPC ya contienen el `nid` explícito:
    // pokepc:0003, pokepc:0003-f, pokepc-shiny:0678-f… El CDN nombra los
    // iconos por nid, no por el identificador de PokéAPI.
    final token = _tokenRe.firstMatch(source);
    if (token != null) {
      final shiny = token.group(1) != null;
      final nid = token.group(2)!;
      return PokepcLocalRepository.file(
        'sprites/home3d/${shiny ? 'shiny' : 'regular'}/$nid.webp',
      );
    }

    // Compatibilidad con las rutas antiguas de PokeAPI.
    final file = source.split('/').last;
    final m = _pngRe.firstMatch(file);
    if (m == null) return null;
    final shiny = m.group(1) != null;
    final id = m.group(3)!.padLeft(4, '0');
    return PokepcLocalRepository.file(
      'sprites/home3d/${shiny ? 'shiny' : 'regular'}/$id.webp',
    );
  }

  /// Origen del GIF animado de este sprite (o null si no se conoce).
  _AnimatedSource? _animatedSource(String? source) {
    if (source == null) return null;
    final legacy = _tokenRe.hasMatch(source)
        ? AnimatedSprites.legacyPath(source)
        : source;
    if (legacy == null) return null;
    final m = _pngRe.firstMatch(legacy.split('/').last);
    if (m == null) return null; // formas con sufijo: sin GIF conocido
    final key =
        '${m.group(1) != null ? 'shiny/' : ''}${m.group(2) != null ? 'female/' : ''}${m.group(3)}.gif';
    return _AnimatedSource(key, '${AnimatedSprites.baseUrl}$key');
  }

  @override
  Widget build(BuildContext context) {
    final fixed = _buildStatic(context);
    if (!threeD || AppSettings.current?.animatedSprites != true) return fixed;
    final src = _animatedSource(path);
    if (src == null) return fixed;
    return _AnimatedGif(
      key: ValueKey(src.key),
      source: src,
      size: size,
      decodeWidth:
          (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 1024),
      fallback: fixed,
    );
  }

  Widget _buildStatic(BuildContext context) {
    const broken = Icon(Icons.broken_image_outlined);
    // En modo 2D, un sprite de PokéPC se sustituye por su sprite clásico (si
    // esa forma no lo tiene, se mantiene el render de HOME).
    final raw = path;
    final String? p = (raw != null && !threeD && _tokenRe.hasMatch(raw))
        ? (AnimatedSprites.legacyPath(raw) ?? raw)
        : raw;
    final isPokepcToken = p != null && _tokenRe.hasMatch(p);
    // Decodificar a la resolución a la que se muestra (no la del archivo).
    final decodeWidth =
        (size * MediaQuery.devicePixelRatioOf(context)).ceil().clamp(16, 1024);
    final quality = pixel && !threeD ? FilterQuality.none : FilterQuality.medium;
    final homeFile = _homeDataFile(p);

    Widget fallback() {
      if (p == null || isPokepcToken) return const Icon(Icons.help_outline);
      if (p.startsWith('http')) {
        if (AppSettings.current?.offlineMode == true) return broken;
        return Image.network(p, fit: BoxFit.contain, filterQuality: quality,
            errorBuilder: (_, __, ___) => broken);
      }
      final file = p.split('/').last;
      final match = _pngRe.firstMatch(file);
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
        return Image.asset(p, fit: BoxFit.contain, filterQuality: quality,
            errorBuilder: (_, __, ___) => Image.network(url, fit: BoxFit.contain,
              filterQuality: quality, errorBuilder: (_, __, ___) => broken));
      }
      return Image.asset(p, fit: BoxFit.contain, filterQuality: quality,
          errorBuilder: (_, __, ___) => broken);
    }

    // Los sprites identificados por PokéPC deben usar HOME 3D siempre:
    // no dependen del antiguo ajuste threeDSprites, que por defecto está apagado.
    final useLocalHome = isPokepcToken || threeD;
    if (p == null) {
      return SizedBox(width: size, height: size, child: const Icon(Icons.help_outline));
    }
    if (useLocalHome && homeFile != null) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.file(
          homeFile,
          fit: BoxFit.contain,
          cacheWidth: decodeWidth,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => isPokepcToken ? broken : fallback(),
        ),
      );
    }
    if (isPokepcToken) {
      return SizedBox(width: size, height: size, child: broken);
    }
    final home = threeD ? _homeUrl(p) : null;
    if (home != null && AppSettings.current?.offlineMode != true) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(home, fit: BoxFit.contain,
            cacheWidth: decodeWidth,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => fallback()),
      );
    }
    return SizedBox(width: size, height: size, child: fallback());
  }

}

class _AnimatedSource {
  final String key, url;
  const _AnimatedSource(this.key, this.url);
}

/// Sprites animados (GIF de Pokémon Showdown, alojados en el repositorio de
/// sprites de PokéAPI). Se descargan al verlos por primera vez y se guardan en
/// `data/sprite-cache/showdown`, fuera de la carpeta del dataset para que una
/// actualización del contenido local no los borre.
class AnimatedSprites {
  AnimatedSprites._();

  static const baseUrl =
      'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/showdown/';

  // Token de PokéPC (pokepc:0003, pokepc-shiny:0003…) -> ruta del sprite 2D
  // clásico de esa misma forma. De ahí salen también los GIF de PokéAPI.
  static final Map<String, String> _legacyByToken = {};

  /// Ruta 2D clásica equivalente a un token de PokéPC (null si no existe).
  static String? legacyPath(String token) => _legacyByToken[token];

  /// Enlaza los sprites de PokéPC con los clásicos usando los ids de entrada
  /// del catálogo antiguo, que se conservaron al migrar.
  static void registerCatalog(List<Species> pokepc, List<Species> legacy) {
    final legacyById = {
      for (final s in legacy)
        for (final e in s.entries) e.id: e,
    };
    for (final s in pokepc) {
      for (final e in s.entries) {
        final old = legacyById[e.id];
        if (old == null) continue;
        if (e.sprite != null && old.sprite != null) {
          _legacyByToken[e.sprite!] = old.sprite!;
        }
        if (e.shiny != null && old.shiny != null) {
          _legacyByToken[e.shiny!] = old.shiny!;
        }
      }
    }
  }

  static File cacheFile(String key) {
    final dir = PokepcLocalRepository.root.parent.path;
    final sep = Platform.pathSeparator;
    return File('$dir${sep}sprite-cache${sep}showdown${sep}${key.replaceAll('/', sep)}');
  }

  static final Set<String> _missing = {}; // 404: no se vuelve a intentar
  static final Map<String, Future<File?>> _pending = {};
  static int _active = 0;
  static final List<Completer<void>> _queue = [];

  static Future<void> _acquire() async {
    if (_active < 4) {
      _active++;
      return;
    }
    final c = Completer<void>();
    _queue.add(c);
    await c.future;
  }

  static void _release() {
    if (_queue.isNotEmpty) {
      _queue.removeAt(0).complete();
    } else {
      _active--;
    }
  }

  static Future<File?> resolve(_AnimatedSource src) {
    final existing = _pending[src.key];
    if (existing != null) return existing;
    final future = _load(src);
    _pending[src.key] = future;
    future.then((r) {
      if (r == null) _pending.remove(src.key); // permite reintentar sin conexión
    });
    return future;
  }

  static Future<File?> _load(_AnimatedSource src) async {
    final file = cacheFile(src.key);
    try {
      if (await file.exists() && await file.length() > 0) return file;
    } catch (_) {}
    if (_missing.contains(src.key)) return null;
    if (AppSettings.current?.offlineMode == true) return null;
    await _acquire();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse(src.url));
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode == 404) {
        _missing.add(src.key);
        await response.drain<void>();
        return null;
      }
      if (response.statusCode != 200) {
        await response.drain<void>();
        return null;
      }
      final builder = await response
          .fold<BytesBuilder>(BytesBuilder(copy: false), (b, d) => b..add(d))
          .timeout(const Duration(seconds: 30));
      final bytes = builder.takeBytes();
      // Un GIF válido empieza por «GIF8».
      if (bytes.length < 6 ||
          String.fromCharCodes(bytes.sublist(0, 4)) != 'GIF8') {
        _missing.add(src.key);
        return null;
      }
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
      _release();
    }
  }
}

class _AnimatedGif extends StatefulWidget {
  final _AnimatedSource source;
  final double size;
  final int decodeWidth;
  final Widget fallback;
  const _AnimatedGif({
    super.key,
    required this.source,
    required this.size,
    required this.decodeWidth,
    required this.fallback,
  });

  @override
  State<_AnimatedGif> createState() => _AnimatedGifState();
}

class _AnimatedGifState extends State<_AnimatedGif> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final f = await AnimatedSprites.resolve(widget.source);
    if (mounted && f != null) setState(() => _file = f);
  }

  @override
  Widget build(BuildContext context) {
    final f = _file;
    if (f == null) return widget.fallback; // mientras se descarga: render 3D
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Image.file(
        f,
        fit: BoxFit.contain,
        cacheWidth: widget.decodeWidth,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => widget.fallback,
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
    final coded = _coded(context);
    final keys = GameTiles.keysFor(game.iconId ?? game.id);
    if (keys.isEmpty) return coded;
    return Tooltip(
      message: game.name,
      child: _GameTileImage(
        key: ValueKey(keys.join('|')),
        keys: keys,
        guess: GameTiles.isGuess(game.iconId ?? game.id),
        size: size,
        fallback: coded,
      ),
    );
  }

  /// Icono de siglas (sirve de respaldo mientras baja el icono de PokéPC).
  Widget _coded(BuildContext context) {
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
          color: color.withValues(alpha: .16),
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


/// Iconos de juego de PokéPC (`gametiles`). Las claves reales (p. ej. `frlg-fr`)
/// se descubren en el índice local del dataset; se descargan al verlos y se
/// guardan en `data/sprite-cache/gametiles`.
class GameTiles {
  GameTiles._();

  static const baseUrl = 'https://static.pokepc.net/images/games/gametiles/';
  static Map<String, List<String>> _prefixes = {};
  static List<String> _localIds = const [];
  static Map<String, String> _names = {}; // id -> nombre inglés
  static final Map<String, List<String>> _keys = {};
  static final Set<String> _missing = {};
  static final Map<String, Future<File?>> _pending = {};

  static Future<void> load() async {
    try {
      final raw = await rootBundle.loadString('assets/data/game_tiles.json');
      final games = (jsonDecode(raw) as Map)['games'] as Map;
      _prefixes = {
        for (final e in games.entries)
          e.key.toString(): (e.value as List).map((x) => x.toString()).toList(),
      };
    } catch (_) {}
    try {
      final f = PokepcLocalRepository.file('indices/games.json');
      if (await f.exists()) {
        _localIds = (jsonDecode(await f.readAsString()) as List)
            .map((x) => x.toString())
            .toList();
      }
    } catch (_) {}
    // Nombres de los juegos (i18n del dataset), por si el id no basta.
    _names = {};
    _enNames.clear();
    for (final locale in const ['es-es', 'es', 'eng', 'en', 'en-us', 'en-gb']) {
      try {
        final f = PokepcLocalRepository.file('i18n/$locale/games.json');
        if (!await f.exists()) continue;
        var raw = jsonDecode(await f.readAsString());
        if (raw is Map && raw['games'] is Map) raw = raw['games'];
        if (raw is Map) {
          raw.forEach((k, v) {
            String? name;
            if (v is Map) {
              name = (v['name'] ?? v['title'] ?? v['shortName'] ?? v['label'])?.toString();
            } else {
              name = v?.toString();
            }
            if (name == null || name.isEmpty) return;
            final shown = name;
            _names.putIfAbsent(k.toString(), () => shown);
            // Para buscar por nombre se usa el inglés (o, si falta, cualquiera).
            if (locale.startsWith('en') || !_enNames.containsKey(k.toString())) {
              _enNames[k.toString()] = _norm(name);
            }
          });
        }
      } catch (_) {}
    }
    _keys.clear();
  }

  static final Map<String, String> _enNames = {};
  static final Set<String> _guessed = {};

  /// Minúsculas y sin signos: «Legends: Z-A» y «Legends Z–A» coinciden.
  static String _norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// true si las claves de ese juego son suposiciones (sin índice local que las
  /// confirme): se prueban una a una y vale la primera que exista.
  static bool isGuess(String gameId) {
    allKeysFor(gameId);
    return _guessed.contains(gameId);
  }

  /// Nombre legible de un id de versión (o el propio id si no se conoce).
  static String nameOf(String id) => _names[id] ?? id.toUpperCase();

  /// Ordena ids de versión según el orden del dataset (los desconocidos, al final).
  static List<String> sortIds(Iterable<String> ids) {
    final order = {for (var i = 0; i < _localIds.length; i++) _localIds[i]: i};
    final list = ids.toList();
    list.sort((a, b) => (order[a] ?? 1 << 20).compareTo(order[b] ?? 1 << 20));
    return list;
  }

  /// Claves de icono (como mucho dos: pareja de versiones) de un juego.
  static List<String> keysFor(String gameId) {
    final all = allKeysFor(gameId);
    return (isGuess(gameId) ? all : all.take(2)).toList(growable: false);
  }

  /// Todos los iconos (versiones) de un juego, p. ej. [xy-x, xy-y].
  static List<String> allKeysFor(String gameId) => _keys.putIfAbsent(gameId, () {
        final prefixes = _prefixes[gameId];
        if (prefixes == null || prefixes.isEmpty) return const <String>[];
        final found = <String>[];
        for (final p in prefixes) {
          if (p.startsWith('~')) {
            final needle = _norm(p.substring(1));
            for (final id in _localIds) {
              final name = _enNames[id] ?? '';
              if ((name.contains(needle) || _norm(id).contains(needle)) && !found.contains(id)) {
                found.add(id);
              }
            }
          } else {
            for (final id in _localIds) {
              if ((id == p || id.startsWith('$p-')) && !found.contains(id)) {
                found.add(id);
              }
            }
          }
          if (found.isNotEmpty) break;
        }
        if (found.isEmpty) {
          // Sin coincidencias en el índice local: claves de prueba.
          for (final p in prefixes) {
            if (p.startsWith('~')) continue;
            final k = p.startsWith('=') ? p.substring(1) : p;
            if (!found.contains(k)) found.add(k);
          }
          if (found.isNotEmpty) _guessed.add(gameId);
        }
        return List<String>.unmodifiable(found);
      });

  static File cacheFile(String key) {
    final dir = PokepcLocalRepository.root.parent.path;
    final sep = Platform.pathSeparator;
    return File('$dir${sep}sprite-cache${sep}gametiles$sep$key.webp');
  }

  static Future<File?> resolve(String key) {
    final existing = _pending[key];
    if (existing != null) return existing;
    final future = _load(key);
    _pending[key] = future;
    future.then((r) {
      if (r == null) _pending.remove(key);
    });
    return future;
  }

  static Future<File?> _load(String key) async {
    final file = cacheFile(key);
    try {
      if (await file.exists() && await file.length() > 0) return file;
    } catch (_) {}
    if (_missing.contains(key)) return null;
    if (AppSettings.current?.offlineMode == true) return null;
    await AnimatedSprites._acquire();
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('$baseUrl$key.webp'));
      final response = await request.close().timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        if (response.statusCode == 404) _missing.add(key);
        await response.drain<void>();
        return null;
      }
      final builder = await response
          .fold<BytesBuilder>(BytesBuilder(copy: false), (b, d) => b..add(d))
          .timeout(const Duration(seconds: 30));
      final bytes = builder.takeBytes();
      // WebP válido: «RIFF....WEBP».
      if (bytes.length < 16 ||
          String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
          String.fromCharCodes(bytes.sublist(8, 12)) != 'WEBP') {
        _missing.add(key);
        return null;
      }
      await file.parent.create(recursive: true);
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      return file;
    } catch (_) {
      return null;
    } finally {
      client.close(force: true);
      AnimatedSprites._release();
    }
  }
}

class _GameTileImage extends StatefulWidget {
  final List<String> keys;
  final bool guess; // las claves son pruebas: vale la primera que exista
  final double size;
  final Widget fallback;
  const _GameTileImage({
    super.key,
    required this.keys,
    required this.size,
    required this.fallback,
    this.guess = false,
  });

  @override
  State<_GameTileImage> createState() => _GameTileImageState();
}

class _GameTileImageState extends State<_GameTileImage> {
  List<File> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    List<File> files;
    if (widget.guess) {
      files = [];
      for (final k in widget.keys) {
        final f = await GameTiles.resolve(k);
        if (f != null) {
          files = [f];
          break;
        }
      }
    } else {
      final result = await Future.wait(widget.keys.map(GameTiles.resolve));
      files = [for (final f in result) if (f != null) f];
    }
    if (!mounted) return;
    if (files.isNotEmpty) setState(() => _files = files);
  }

  @override
  Widget build(BuildContext context) {
    if (_files.isEmpty) return widget.fallback; // descargando / sin icono
    final h = widget.size * .78;
    final radius = BorderRadius.circular(widget.size * .14);
    Widget tile(File f, double w) => ClipRRect(
          borderRadius: radius,
          child: Image.file(f,
              width: w,
              height: h,
              fit: BoxFit.cover,
              cacheWidth: (w * 3).ceil(),
              errorBuilder: (_, __, ___) => SizedBox(width: w, height: h)),
        );
    if (_files.length == 1) {
      return SizedBox(
          width: widget.size, height: h, child: Center(child: tile(_files[0], h)));
    }
    // Pareja de versiones (p. ej. X / Y): dos iconos solapados.
    final w = widget.size * .64;
    return SizedBox(
      width: widget.size,
      height: h,
      child: Stack(children: [
        Positioned(left: 0, child: tile(_files[0], w)),
        Positioned(right: 0, child: tile(_files[1], w)),
      ]),
    );
  }
}

/// Icono de una versión concreta de un juego (p. ej. `bw-b`), con su nombre al
/// pasar el ratón. Se descarga de PokéPC; mientras tanto, o si no existe, se
/// muestra una etiqueta con las siglas.
class VersionIcon extends StatefulWidget {
  final String id;
  final double size;
  const VersionIcon(this.id, {super.key, this.size = 44});

  @override
  State<VersionIcon> createState() => _VersionIconState();
}

class _VersionIconState extends State<VersionIcon> {
  File? _file;

  @override
  void initState() {
    super.initState();
    GameTiles.resolve(widget.id).then((f) {
      if (mounted && f != null) setState(() => _file = f);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final h = widget.size * .78;
    final radius = BorderRadius.circular(widget.size * .14);
    final f = _file;
    final child = f != null
        ? ClipRRect(
            borderRadius: radius,
            child: Image.file(f,
                width: widget.size,
                height: h,
                fit: BoxFit.cover,
                cacheWidth: (widget.size * 3).ceil(),
                errorBuilder: (_, __, ___) => _label(t, h, radius)),
          )
        : _label(t, h, radius);
    return Tooltip(message: GameTiles.nameOf(widget.id), child: child);
  }

  Widget _label(ThemeData t, double h, BorderRadius radius) => Container(
        width: widget.size,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
          border: Border.all(color: t.colorScheme.outlineVariant),
        ),
        child: Text(widget.id.toUpperCase(),
            textAlign: TextAlign.center,
            style: t.textTheme.labelSmall?.copyWith(fontSize: widget.size * .2)),
      );
}

/// «Juegos en los que está disponible»: un icono por cada VERSIÓN (Rojo y Azul
/// por separado). Usa la disponibilidad real de PokéPC si está instalada; si no,
/// parte de las Pokédex de cada juego y las separa en sus versiones.
class AvailableGames extends StatelessWidget {
  final Species species;
  final String? variety;
  final bool isDefault;
  final double iconSize;
  final bool center;
  const AvailableGames({
    super.key,
    required this.species,
    this.variety,
    this.isDefault = false,
    this.iconSize = 44,
    this.center = false,
  });

  DexEntry? _entry() {
    for (final e in species.entries) {
      if (variety != null && e.id == variety) return e;
    }
    if (variety == null || isDefault) {
      for (final e in species.entries) {
        if (e.kind == 'base' || e.id == species.name) return e;
      }
    }
    return null;
  }

  List<String> _versionIds() {
    final real = PokepcLocalRepository.availabilityByEntryId;
    final e = _entry();
    final fromPokepc = e == null ? null : real[e.id];
    if (fromPokepc != null && fromPokepc.isNotEmpty) {
      return GameTiles.sortIds(fromPokepc);
    }
    // Sin datos de PokéPC: juegos cuya Pokédex incluye el Pokémon, por versión.
    final out = <String>[];
    for (final g in gamesWithSpecies(species, variety: variety, isDefault: isDefault)) {
      final keys = GameTiles.allKeysFor(g.iconId ?? g.id);
      for (final k in keys) {
        if (!out.contains(k)) out.add(k);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final ids = _versionIds();
    if (ids.isEmpty) {
      // Último recurso: iconos de siglas por juego.
      final games =
          gamesWithSpecies(species, variety: variety, isDefault: isDefault);
      if (games.isEmpty) {
        return Text('Sin datos de disponibilidad por juego.',
            style: t.textTheme.bodySmall);
      }
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: center ? WrapAlignment.center : WrapAlignment.start,
        children: [for (final g in games) GameIcon(g, size: iconSize)],
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: center ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [for (final id in ids) VersionIcon(id, size: iconSize)],
    );
  }
}
