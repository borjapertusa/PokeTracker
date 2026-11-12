class DexEntry {
  final String id, label, kind, gender; // gender: male | female | none
  final String? sprite, shiny;
  final bool battleOnly;

  DexEntry.fromJson(Map<String, dynamic> j)
      : id = j['id'],
        label = _localizedEntryLabel((j['label'] ?? '').toString()),
        kind = j['kind'],
        gender = j['gender'],
        sprite = j['sprite'],
        shiny = j['shiny'],
        battleOnly = j['battleOnly'] ?? false;
}

class Species {
  final int dex, gen;
  final String name, nameEs;
  final List<DexEntry> entries;

  Species.fromJson(Map<String, dynamic> j)
      : dex = j['dex'],
        gen = j['gen'],
        name = j['name'],
        nameEs = j['nameEs'],
        entries = (j['entries'] as List)
            .map((e) => DexEntry.fromJson(e as Map<String, dynamic>))
            .toList();

  /// Misma especie con otra lista de entradas (p. ej. recortada para el tracker).
  Species.withEntries(Species o, this.entries)
      : dex = o.dex,
        gen = o.gen,
        name = o.name,
        nameEs = o.nameEs;

  /// Nombre en español o en inglés (a partir del identificador de PokéAPI).
  String displayName(bool spanish) => spanish
      ? nameEs
      : name
          .split('-')
          .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
          .join(' ');
}

/// Una especie dentro de la Pokédex de un juego: nº regional y formas que cuentan ahí.
class GameSpecies {
  final Species species;
  final int no;
  final List<DexEntry> entries;
  final String? label;
  final String? section;
  const GameSpecies(this.species, this.no, this.entries, {this.label, this.section});
  String displayName(bool spanish) => label ?? species.displayName(spanish);
}

/// Pokédex de un juego (o de Pokémon HOME, que lo incluye todo).
/// [custom] = Pokédex creada por el usuario desde la barra lateral.
class Game {
  final String id;
  String name; // editable: el usuario puede renombrar las Pokédex
  final int gen; // 0 = general (HOME)
  final bool shiny; // el juego tiene variocolor
  final bool genders; // el juego muestra diferencias de género
  final List<GameSpecies> species;
  final bool custom;
  final String? iconId;

  Game({
    required this.id,
    required this.name,
    required this.gen,
    required this.shiny,
    required this.genders,
    required this.species,
    this.custom = false,
    this.iconId,
  });

  /// Ids de entrada cuyo variocolor NO se puede conseguir en esta Pokédex
  /// (ver assets/data/shiny_availability.json). Se asigna al cargar los datos.
  Set<String> shinyLocked = const {};

  final Map<String, String> _keys = {};
  List<DexEntry>? _all;
  int _allLen = -1;

  /// Clave de progreso. HOME conserva las claves antiguas (sin prefijo).
  String key(DexEntry e) =>
      id == 'home' ? e.id : (_keys[e.id] ??= '$id:${e.id}');

  List<GameSpecies>? _unique;
  int _uniqueLen = -1;

  /// Especies sin repetir (la primera aparición de cada una), para cosas que
  /// no deben duplicarse aunque salgan en varias secciones: cajas, desafíos…
  List<GameSpecies> get uniqueSpecies {
    if (_unique == null || _uniqueLen != species.length) {
      final seen = <int>{};
      _unique = [
        for (final gs in species)
          if (seen.add(gs.species.dex)) gs,
      ];
      _uniqueLen = species.length;
    }
    return _unique!;
  }

  /// Todas las entradas (en caché; la lista de especies puede crecer al
  /// anexarse los DLC durante la carga, por eso se comprueba su longitud).
  List<DexEntry> get allEntries {
    if (_all == null || _allLen != species.length) {
      // Una especie puede aparecer en varias secciones (p. ej. las islas de
      // Alola): sus entradas cuentan una sola vez.
      final seen = <String>{};
      _all = [
        for (final s in species)
          for (final e in s.entries)
            if (seen.add(e.id)) e,
      ];
      _allLen = species.length;
    }
    return _all!;
  }

  /// El variocolor de esta entrada se puede registrar en esta Pokédex: el juego
  /// lo admite, existe su variocolor (si `e.shiny` es null, no se puede
  /// conseguir en ningún sitio) y no está bloqueado en este juego/generación.
  bool shinyFor(DexEntry e) =>
      shiny && e.shiny != null && (shinyLocked.isEmpty || !shinyLocked.contains(e.id));

  /// Cuántas de [es] tienen variocolor registrable (total para contadores y barras).
  int shinyTotal(Iterable<DexEntry> es) {
    if (!shiny) return 0;
    var n = 0;
    for (final e in es) {
      if (shinyFor(e)) n++;
    }
    return n;
  }
}


String _localizedEntryLabel(String value) {
  const labels = {
    'Base': 'Base', 'Mega': 'Mega', 'Mega X': 'Mega-X', 'Mega Y': 'Mega-Y',
    'Mega Z': 'Mega-Z', 'Gmax': 'Gigamax', 'Alola': 'Alola', 'Galar': 'Galar',
    'Hisui': 'Hisui', 'Paldea': 'Paldea', 'Totem': 'Dominante',
    'Female': 'Hembra', 'Male': 'Macho', 'Starter': 'Inicial',
    'Therian': 'Tótem', 'Incarnate': 'Avatar', 'Origin': 'Origen',
    'Attack': 'Forma Ataque', 'Defense': 'Forma Defensa', 'Speed': 'Forma Velocidad',
    'Sunny': 'Soleado', 'Rainy': 'Lluvioso', 'Snowy': 'Nevado',
  };
  return labels[value] ?? value;
}


/// Juegos oficiales (sin HOME ni los propios del usuario). Se rellena al cargar
/// los datos; sirve para mostrar en qué juegos está disponible un Pokémon.
List<Game> kOfficialGames = const [];

/// Pokémon HOME (lista con todo), usado por la ficha de la Pokédex general.
Game? kHomeGame;

/// Juegos oficiales en cuya Pokédex aparece [sp]. Si se indica [variety] (id de
/// forma), solo cuentan los juegos que incluyen esa forma; [isDefault] hace que
/// la forma base también valga cuando el id exacto no coincide.
List<Game> gamesWithSpecies(Species sp, {String? variety, bool isDefault = false}) {
  bool matches(DexEntry e) {
    if (variety == null) return true;
    if (e.id == variety) return true;
    return isDefault && (e.kind == 'base' || e.id == sp.name);
  }

  final out = <Game>[];
  for (final g in kOfficialGames) {
    var found = false;
    for (final gs in g.species) {
      if (gs.species.dex != sp.dex) continue;
      if (gs.entries.any(matches)) found = true;
      break;
    }
    if (found) out.add(g);
  }
  // Si la forma concreta no consta en ningún juego, se usa la especie completa.
  if (out.isEmpty && variety != null) return gamesWithSpecies(sp);
  return out;
}
