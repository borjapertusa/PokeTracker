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

  /// Clave de progreso. HOME conserva las claves antiguas (sin prefijo).
  String key(DexEntry e) => id == 'home' ? e.id : '$id:${e.id}';

  List<DexEntry> get allEntries => species.expand((s) => s.entries).toList();
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
