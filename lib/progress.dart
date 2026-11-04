import 'dart:convert';

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

  Progress._(this._prefs, this._profiles) : _pid = _profiles.activeId {
    _read();
    _profiles.addListener(_onProfiles);
  }

  static Future<Progress> load(ProfileStore profiles) async =>
      Progress._(await SharedPreferences.getInstance(), profiles);

  void _read() {
    _bits.clear();
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

  void _save() => _prefs.setString(progressKey(_pid), jsonEncode(_bits));

  bool has(String key, {bool shiny = false}) =>
      ((_bits[key] ?? 0) & (shiny ? 2 : 1)) != 0;

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

  int count(Game g, Iterable<DexEntry> es, {bool shiny = false}) =>
      es.where((e) => has(g.key(e), shiny: shiny)).length;

  /// Marca o desmarca (value) la casilla normal o variocolor de varias entradas.
  void setAll(Game g, Iterable<DexEntry> es,
      {required bool shiny, required bool value}) {
    final bit = shiny ? 2 : 1;
    for (final e in es) {
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

  /// Borra el progreso de un juego propio en todos los perfiles.
  void removeGame(String gameId) {
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
