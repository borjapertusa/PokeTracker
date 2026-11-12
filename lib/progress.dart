import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'profiles.dart';

/// Progreso del tracker del perfil activo. Guarda por entrada un valor de 2 bits:
/// 1 = normal, 2 = variocolor. Las claves son `idEntrada` (HOME) o `idJuego:idEntrada`.
/// Al cambiar de perfil recarga sus datos y avisa a la interfaz.
class Progress extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ProfileStore _profiles;
  final Map<String, int> _bits = {};
  String _pid;
  // Sube con cada cambio de progreso; invalida el caché del desafío diario.
  int _rev = 0;
  final Map<String, (int, List<Map<String, dynamic>>)> _challengeCache = {};

  Progress._(this._prefs, this._profiles) : _pid = _profiles.activeId {
    _read();
    _profiles.addListener(_onProfiles);
  }

  static Future<Progress> load(ProfileStore profiles) async =>
      Progress._(await SharedPreferences.getInstance(), profiles);

  void _read() {
    _bits.clear();
    _rev++;
    // El primer perfil recoge el progreso guardado antes de existir los perfiles.
    final raw = _prefs.getString(progressKey(_pid)) ??
        (_pid == defaultProfileId ? _prefs.getString('progress_v1') : null);
    if (raw != null) {
      try {
        (jsonDecode(raw) as Map<String, dynamic>)
            .forEach((k, v) => _bits[k] = v as int);
      } catch (_) {
        // Datos dañados: se empieza en blanco.
      }
    }
  }

  void _onProfiles() {
    if (_profiles.activeId != _pid) {
      _pid = _profiles.activeId;
      _read();
      notifyListeners();
    }
  }

  void _save() {
    _rev++;
    _prefs.setString(progressKey(_pid), jsonEncode(_bits));
  }

  bool has(String key, {bool shiny = false}) =>
      ((_bits[key] ?? 0) & (shiny ? 2 : 1)) != 0;

  String _challengeKey(Game game) => 'daily_challenge_v1_${_pid}_${game.id}';

  bool _targetCaught(Game game, GameSpecies gs, bool shiny) => gs.entries.any((entry) =>
      (!shiny || game.shinyFor(entry)) &&
      ((_bits[game.key(entry)] ?? 0) & (shiny ? 2 : 1)) != 0);

  List<Map<String, dynamic>> _eligibleChallenge(Game game,
      {Set<String> except = const {}}) => [
        for (final gs in game.uniqueSpecies)
          if (!_targetCaught(game, gs, false) && !except.contains('${gs.species.dex}:n'))
            {'dex': gs.species.dex, 'shiny': false},
        if (game.shiny)
          for (final gs in game.uniqueSpecies)
            if (gs.entries.any(game.shinyFor) &&
                !_targetCaught(game, gs, true) && !except.contains('${gs.species.dex}:s'))
              {'dex': gs.species.dex, 'shiny': true},
      ];

  String _targetKey(Map<String,dynamic> t) => '${t['dex']}:${t['shiny'] == true ? 's' : 'n'}';

  List<Map<String,dynamic>> _readChallenge(Game game) {
    final raw = _prefs.getString(_challengeKey(game));
    if (raw == null) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((v) => v is num
          ? {'dex': v.toInt(), 'shiny': false}
          : Map<String,dynamic>.from(v as Map)).toList();
    } catch (_) { return []; }
  }

  void _saveChallenge(Game game, List<Map<String,dynamic>> targets) {
    _challengeCache.remove(_challengeKey(game));
    _prefs.setString(_challengeKey(game), jsonEncode(targets));
  }

  /// Cuatro objetivos persistentes; cada especie puede aparecer como normal y variocolor.
  /// El resultado se guarda en memoria hasta que cambie el progreso, y solo se
  /// escribe en disco si los objetivos cambian (esto se llama al pintar).
  List<Map<String,dynamic>> dailyChallenge(Game game) {
    final cacheKey = _challengeKey(game);
    final cached = _challengeCache[cacheKey];
    if (cached != null && cached.$1 == _rev) return cached.$2;
    final stored = _readChallenge(game);
    final valid = <int, GameSpecies>{
      for (final gs in game.species) gs.species.dex: gs,
    };
    final current = stored.where((t) {
      final gs = valid[t['dex']];
      if (gs == null) return false;
      final shiny = t['shiny'] == true;
      return (!shiny || game.shiny) && !_targetCaught(game, gs, shiny);
    }).toList();
    final unique = <Map<String,dynamic>>[];
    final keys = <String>{};
    for (final t in current) { if (keys.add(_targetKey(t))) unique.add(t); }
    final eligible = _eligibleChallenge(game, except: keys);
    final random = Random();
    while (unique.length < 4 && eligible.isNotEmpty) {
      final index = random.nextInt(eligible.length);
      final target = eligible.removeAt(index);
      unique.add(target);
    }
    final changed = jsonEncode(stored) != jsonEncode(unique);
    if (changed) _saveChallenge(game, unique);
    final result = List<Map<String,dynamic>>.unmodifiable(unique);
    _challengeCache[cacheKey] = (_rev, result);
    return result;
  }

  void rerollDailyChallenge(Game game) {
    final eligible = _eligibleChallenge(game)..shuffle(Random());
    _saveChallenge(game, eligible.take(4).toList());
    notifyListeners();
  }

  /// Al completar un objetivo normal o variocolor, se sustituye solo ese objetivo.
  void toggleEntry(Game game, Species species, DexEntry entry, {bool shiny = false}) {
    toggle(game.key(entry), shiny: shiny);
    GameSpecies? gs;
    for (final candidate in game.species) {
      if (candidate.species.dex == species.dex) { gs = candidate; break; }
    }
    if (gs == null || !_targetCaught(game, gs, shiny)) return;
    final current = _readChallenge(game);
    final key = '${species.dex}:${shiny ? 's' : 'n'}';
    if (!current.any((t) => _targetKey(t) == key)) return;
    current.removeWhere((t) => _targetKey(t) == key);
    final eligible = _eligibleChallenge(game, except: current.map(_targetKey).toSet());
    if (eligible.isNotEmpty) current.add(eligible[Random().nextInt(eligible.length)]);
    _saveChallenge(game, current);
    notifyListeners();
  }

  void toggle(String key, {bool shiny = false}) {
    final v = (_bits[key] ?? 0) ^ (shiny ? 2 : 1);
    if (v == 0) {
      _bits.remove(key);
    } else {
      _bits[key] = v;
    }
    _save();
    notifyListeners();
  }

  /// Cuenta registros. Los variocolor solo cuentan en entradas donde se pueden
  /// conseguir; un marcado antiguo en una entrada sin variocolor se ignora.
  int count(Game g, Iterable<DexEntry> es, {bool shiny = false}) => es
      .where((e) => (!shiny || g.shinyFor(e)) && has(g.key(e), shiny: shiny))
      .length;

  /// Progreso total (0–1) de [es]: normales + variocolor disponibles.
  double ratio(Game g, Iterable<DexEntry> es) {
    final list = es is List<DexEntry> ? es : es.toList();
    final total = list.length + g.shinyTotal(list);
    if (total == 0) return 0;
    return (count(g, list) + count(g, list, shiny: true)) / total;
  }

  /// Marca o desmarca (value) la casilla normal o variocolor de varias entradas.
  void setAll(Game g, Iterable<DexEntry> es,
      {required bool shiny, required bool value}) {
    final bit = shiny ? 2 : 1;
    for (final e in es) {
      if (shiny && !g.shinyFor(e)) continue; // sin variocolor: no se marca
      final k = g.key(e);
      final cur = _bits[k] ?? 0;
      final next = value ? (cur | bit) : (cur & ~bit);
      if (next == 0) {
        _bits.remove(k);
      } else {
        _bits[k] = next;
      }
    }
    _save();
    notifyListeners();
  }

  /// Marca o desmarca de una vez el registro normal y, si el juego lo admite,
  /// también el variocolor. Cada elemento contiene el juego y su entrada.
  void setAllCombined(Iterable<(Game, DexEntry)> items,
      {required bool value}) {
    for (final (game, entry) in items) {
      final key = game.key(entry);
      final bits = game.shinyFor(entry) ? 3 : 1;
      final current = _bits[key] ?? 0;
      final next = value ? (current | bits) : (current & ~bits);
      if (next == 0) {
        _bits.remove(key);
      } else {
        _bits[key] = next;
      }
    }
    _save();
    notifyListeners();
  }

  /// Borra el progreso de un juego propio en todos los perfiles.
  void removeGame(String gameId) {
    // Elimina también los desafíos diarios guardados para este tracker en
    // todos los perfiles; no deben reaparecer si se crea otro con el mismo ID.
    for (final profile in _profiles.profiles) {
      _prefs.remove('daily_challenge_v1_${profile.id}_$gameId');
    }
    final prefix = '$gameId:';
    if (_bits.keys.any((k) => k.startsWith(prefix))) {
      _bits.removeWhere((k, _) => k.startsWith(prefix));
      _save();
      notifyListeners();
    }
    for (final p in _profiles.profiles) {
      if (p.id == _pid) continue;
      final key = progressKey(p.id);
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        final before = m.length;
        m.removeWhere((k, _) => k.startsWith(prefix));
        if (m.length != before) _prefs.setString(key, jsonEncode(m));
      } catch (_) {
        // Datos dañados: se dejan como están.
      }
    }
  }

  String export() => jsonEncode({'version': 1, 'progress': _bits});

  /// Combina (unión) el progreso importado con el del perfil activo.
  bool import(String text) {
    try {
      final map = (jsonDecode(text) as Map<String, dynamic>)['progress']
          as Map<String, dynamic>;
      map.forEach((k, v) => _bits[k] = (_bits[k] ?? 0) | (v as int));
      _save();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
