import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'progress.dart';

/// Cómo se ordena la lista de la barra lateral.
enum GameSort { generation, generationDesc, name, nameDesc, progress, progressAsc, manual }

const gameSortLabels = {
  GameSort.generation: 'Generación (más antigua → más nueva)',
  GameSort.generationDesc: 'Generación (más nueva → más antigua)',
  GameSort.name: 'Nombre (A–Z)',
  GameSort.nameDesc: 'Nombre (Z–A)',
  GameSort.progress: 'Progreso (mayor a menor)',
  GameSort.progressAsc: 'Progreso (menor a mayor)',
  GameSort.manual: 'Manual',
};

/// De dónde salen las especies de una Pokédex propia.
enum DexSource { national, generation, copy }

/// Una Pokédex que se quiere crear (la rellena el diálogo "Nuevo tracker").
class DexSpec {
  String name;
  DexSource source;
  int gen; // para DexSource.generation
  String? copyOf; // id de un juego, para DexSource.copy
  DexSpec({
    this.name = '',
    this.source = DexSource.national,
    this.gen = 1,
    this.copyOf,
  });
}

/// Petición completa del diálogo "Nuevo tracker".
class TrackerRequest {
  final String name;
  final bool shiny, genders, forms;
  final List<DexSpec> dexes;
  const TrackerRequest({
    required this.name,
    required this.shiny,
    required this.genders,
    required this.forms,
    required this.dexes,
  });
}

/// Definición guardada de una Pokédex creada por el usuario.
class CustomDex {
  final String id;
  String name;
  final DexSource source;
  final int gen;
  final String? copyOf;
  final bool shiny, genders, forms;

  CustomDex({
    required this.id,
    required this.name,
    required this.source,
    required this.gen,
    required this.copyOf,
    required this.shiny,
    required this.genders,
    required this.forms,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'source': source.name,
        'gen': gen,
        'copyOf': copyOf,
        'shiny': shiny,
        'genders': genders,
        'forms': forms,
      };

  factory CustomDex.fromJson(Map<String, dynamic> j) => CustomDex(
        id: j['id'] as String,
        name: j['name'] as String,
        source: DexSource.values.firstWhere((s) => s.name == j['source'],
            orElse: () => DexSource.national),
        gen: (j['gen'] as num?)?.toInt() ?? 1,
        copyOf: j['copyOf'] as String?,
        shiny: j['shiny'] != false,
        genders: j['genders'] != false,
        forms: j['forms'] != false,
      );
}

/// Lista de Pokédex de la barra lateral: las de la app (assets), las que crea el
/// usuario, los renombres, las ocultas y el orden. Se guarda en el equipo.
///
/// [games] es siempre la misma instancia de lista (visibles, en el orden por
/// defecto: HOME, oficiales y por último las propias), así que el resto de la app
/// puede seguir recibiéndola como `List<Game>`. El orden que elige el usuario
/// solo afecta a [sorted].
class GameStore extends ChangeNotifier {
  static const _key = 'games_v1';

  final SharedPreferences _prefs;
  final List<Species> _species;
  final List<Game> _base; // juegos de assets (HOME primero), todos
  final Map<String, String> _baseNames = {};
  final List<CustomDex> _custom = [];
  final Map<String, Game> _customGames = {};
  final Map<String, String> _names = {}; // renombres de juegos oficiales
  final Set<String> _hidden = {};
  final List<String> _order = [];

  /// Se llama al eliminar una Pokédex propia para borrar sus datos.
  final void Function(String gameId)? onPurge;

  final List<Game> games = [];
  GameSort sort = GameSort.generation;

  GameStore._(this._prefs, this._species, this._base, this.onPurge) {
    for (final g in _base) {
      _baseNames[g.id] = g.name;
    }
  }

  static Future<GameStore> load(
    List<Species> species,
    List<Game> base, {
    void Function(String gameId)? onPurge,
  }) async {
    final s = GameStore._(
        await SharedPreferences.getInstance(), species, base, onPurge);
    final raw = s._prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.sort = GameSort.values.firstWhere((m) => m.name == j['sort'],
            orElse: () => GameSort.generation);
        (j['names'] as Map<String, dynamic>? ?? {}).forEach((id, n) {
          if (s._baseNames.containsKey(id) && n is String && n.isNotEmpty) {
            s._names[id] = n;
          }
        });
        for (final id in (j['hidden'] as List? ?? const [])) {
          if (id is String && id != 'home') s._hidden.add(id);
        }
        for (final id in (j['order'] as List? ?? const [])) {
          if (id is String) s._order.add(id);
        }
        for (final c in (j['custom'] as List? ?? const [])) {
          final def = CustomDex.fromJson(c as Map<String, dynamic>);
          s._custom.add(def);
          s._customGames[def.id] = s._build(def);
        }
      } catch (_) {
        // Datos dañados: se empieza con la lista por defecto.
        s._custom.clear();
        s._customGames.clear();
        s._names.clear();
        s._hidden.clear();
        s._order.clear();
        s.sort = GameSort.generation;
      }
    }
    for (final g in s._base) {
      final n = s._names[g.id];
      if (n != null) g.name = n;
    }
    s._rebuild();
    return s;
  }

  // ---------------------------------------------------------------- consulta

  /// Juegos oficiales (sin HOME) cuya lista se puede copiar al crear una Pokédex.
  List<Game> get copyable => [for (final g in _base) if (g.id != 'home') g];

  int get maxGen => _species.fold(1, (m, s) => s.gen > m ? s.gen : m);

  /// Juegos oficiales que el usuario ha quitado de la lista.
  List<Game> get hiddenGames =>
      [for (final g in _base) if (_hidden.contains(g.id)) g];

  bool isRenamed(Game g) => !g.custom && _names.containsKey(g.id);

  String? originalName(Game g) => _baseNames[g.id];

  /// Juegos en el orden elegido por el usuario.
  List<Game> sorted(Progress p) {
    switch (sort) {
      case GameSort.generation:
      case GameSort.generationDesc:
        final originalPosition = {
          for (var i = 0; i < games.length; i++) games[i].id: i
        };
        return List.of(games)
          ..sort((a, b) {
            final generationOrder = sort == GameSort.generation
                ? a.gen.compareTo(b.gen)
                : b.gen.compareTo(a.gen);
            return generationOrder != 0
                ? generationOrder
                : originalPosition[a.id]!.compareTo(originalPosition[b.id]!);
          });
      case GameSort.name:
        final byName = {for (var i = 0; i < games.length; i++) games[i].id: i};
        return List.of(games)
          ..sort((a, b) {
            final c = a.name.toLowerCase().compareTo(b.name.toLowerCase());
            return c != 0 ? c : byName[a.id]!.compareTo(byName[b.id]!);
          });
      case GameSort.nameDesc:
        final byName = {for (var i = 0; i < games.length; i++) games[i].id: i};
        return List.of(games)
          ..sort((a, b) {
            final c = b.name.toLowerCase().compareTo(a.name.toLowerCase());
            return c != 0 ? c : byName[a.id]!.compareTo(byName[b.id]!);
          });
      case GameSort.progress:
      case GameSort.progressAsc:
        final pos = {for (var i = 0; i < games.length; i++) games[i].id: i};
        final ratio = {for (final g in games) g.id: _ratio(g, p)};
        return List.of(games)
          ..sort((a, b) {
            final c = sort == GameSort.progress
                ? ratio[b.id]!.compareTo(ratio[a.id]!)
                : ratio[a.id]!.compareTo(ratio[b.id]!);
            return c != 0 ? c : pos[a.id]!.compareTo(pos[b.id]!);
          });
      case GameSort.manual:
        return _manual();
    }
  }

  static double _ratio(Game g, Progress p) {
    final all = g.allEntries;
    final t = all.length;
    if (t == 0) return 0;
    final n = p.count(g, all);
    final sh = g.shiny ? p.count(g, all, shiny: true) : 0;
    return (n + sh) / ((g.shiny ? 2 : 1) * t);
  }

  List<Game> _manual() {
    final byId = {for (final g in games) g.id: g};
    final out = <Game>[];
    for (final id in _order) {
      final g = byId.remove(id);
      if (g != null) out.add(g);
    }
    // Los que no estén en el orden guardado (juegos nuevos) van al final.
    out.addAll(byId.values);
    return out;
  }

  // ------------------------------------------------------------------ cambios

  void setSort(GameSort s) {
    if (s == GameSort.manual && _order.isEmpty) {
      _order.addAll(games.map((g) => g.id));
    }
    sort = s;
    _save();
  }

  /// Sube (delta -1) o baja (delta 1) un juego en el orden manual.
  void move(Game g, int delta) {
    final ids = [for (final x in _manual()) x.id];
    final i = ids.indexOf(g.id);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= ids.length) return;
    ids.removeAt(i);
    ids.insert(j, g.id);
    _order
      ..clear()
      ..addAll(ids);
    _save();
  }

  void rename(Game g, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    g.name = n;
    if (g.custom) {
      for (final c in _custom) {
        if (c.id == g.id) c.name = n;
      }
    } else if (n == _baseNames[g.id]) {
      _names.remove(g.id);
    } else {
      _names[g.id] = n;
    }
    _save();
  }

  /// Crea un tracker nuevo con una o varias Pokédex. Devuelve los juegos creados.
  List<Game> add(TrackerRequest r) {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final multi = r.dexes.length > 1;
    final created = <Game>[];
    for (var i = 0; i < r.dexes.length; i++) {
      final d = r.dexes[i];
      final label = d.name.trim().isEmpty ? 'Pokédex ${i + 1}' : d.name.trim();
      final def = CustomDex(
        id: 'custom_${stamp}_$i',
        name: multi ? '${r.name.trim()} · $label' : r.name.trim(),
        source: d.source,
        gen: d.gen,
        copyOf: d.copyOf,
        shiny: r.shiny,
        genders: r.genders,
        forms: r.forms,
      );
      final g = _build(def);
      _custom.add(def);
      _customGames[def.id] = g;
      created.add(g);
    }
    _rebuild();
    _save();
    return created;
  }

  /// Quita una Pokédex de la lista. Las propias se borran con su progreso, sus
  /// cajas y los datos de entrenador; las de la app se ocultan (se pueden restaurar).
  void remove(Game g) {
    if (g.id == 'home') return;
    if (g.custom) {
      _custom.removeWhere((c) => c.id == g.id);
      _customGames.remove(g.id);
      _order.remove(g.id);
      onPurge?.call(g.id);
    } else {
      _hidden.add(g.id);
    }
    _rebuild();
    _save();
  }

  void restore(Game g) {
    _hidden.remove(g.id);
    _rebuild();
    _save();
  }

  void restoreAll() {
    _hidden.clear();
    _rebuild();
    _save();
  }

  // ------------------------------------------------------------------ interno

  void _rebuild() {
    games
      ..clear()
      ..addAll([
        for (final g in _base)
          if (!_hidden.contains(g.id)) g,
        for (final c in _custom) _customGames[c.id]!,
      ]);
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'sort': sort.name,
        'custom': [for (final c in _custom) c.toJson()],
        'names': _names,
        'hidden': _hidden.toList(),
        'order': _order,
      }),
    );
    notifyListeners();
  }

  /// Construye la Pokédex a partir de su definición.
  Game _build(CustomDex c) {
    bool genderOk(DexEntry e) => c.genders || e.gender != 'female';

    GameSpecies? make(Species s, int no, List<DexEntry> from) {
      var es = [
        for (final e in from)
          if (genderOk(e) && (c.forms || e.kind == 'base')) e,
      ];
      // Sin formas alternativas, las especies sin forma "base" (p. ej. Unown)
      // conservan su primera entrada para no desaparecer.
      if (es.isEmpty && from.isNotEmpty) {
        es = [from.firstWhere(genderOk, orElse: () => from.first)];
      }
      return es.isEmpty ? null : GameSpecies(s, no, es);
    }

    Game? src;
    if (c.source == DexSource.copy) {
      for (final g in _base) {
        if (g.id == c.copyOf) src = g;
      }
    }

    final list = <GameSpecies>[];
    if (src != null) {
      for (final gs in src.species) {
        final x = make(gs.species, gs.no, gs.entries);
        if (x != null) list.add(x);
      }
    } else {
      for (final s in _species) {
        if (c.source == DexSource.generation && s.gen != c.gen) continue;
        final x = make(s, s.dex, s.entries);
        if (x != null) list.add(x);
      }
    }

    return Game(
      id: c.id,
      name: c.name,
      gen: 0,
      shiny: c.shiny,
      genders: c.genders,
      species: list,
      custom: true,
    );
  }
}
