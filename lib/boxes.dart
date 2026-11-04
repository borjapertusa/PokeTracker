import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'profiles.dart';

const boxRows = 5, boxCols = 6, boxSize = boxRows * boxCols;

/// id de entrada -> (especie, entrada)
typedef EntryIndex = Map<String, (Species, DexEntry)>;

class DexBox {
  String name;
  final List<String?> slots; // 'idEntrada' o 'idEntrada|s' (variocolor); null = vacío

  DexBox(this.name, [List<String?>? slots])
      : slots = slots ?? List<String?>.filled(boxSize, null);

  int get filled => slots.where((s) => s != null).length;
}

/// Cajas de cada juego del perfil activo, guardadas en el equipo.
/// Al cambiar de perfil recarga sus cajas y avisa a la interfaz.
class BoxStore extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ProfileStore _profiles;
  final Map<String, List<DexBox>> _byGame = {};
  String _pid;

  BoxStore._(this._prefs, this._profiles) : _pid = _profiles.activeId {
    _read();
    _profiles.addListener(_onProfiles);
  }

  static Future<BoxStore> load(ProfileStore profiles) async =>
      BoxStore._(await SharedPreferences.getInstance(), profiles);

  void _read() {
    _byGame.clear();
    // El primer perfil recoge las cajas guardadas antes de existir los perfiles.
    final raw = _prefs.getString(boxesKey(_pid)) ??
        (_pid == defaultProfileId ? _prefs.getString('boxes_v1') : null);
    if (raw == null) return;
    try {
      (jsonDecode(raw) as Map<String, dynamic>).forEach((game, list) {
        _byGame[game] = [
          for (final b in list as List)
            DexBox(
              (b as Map<String, dynamic>)['n'] as String,
              _fit((b['s'] as List).map((x) => x as String?).toList()),
            ),
        ];
      });
    } catch (_) {
      _byGame.clear(); // Datos dañados: se empieza con cajas vacías.
    }
  }

  void _onProfiles() {
    if (_profiles.activeId != _pid) {
      _pid = _profiles.activeId;
      _read();
      notifyListeners();
    }
  }

  static List<String?> _fit(List<String?> l) =>
      List<String?>.generate(boxSize, (i) => i < l.length ? l[i] : null);

  List<DexBox> boxesOf(String game) =>
      _byGame.putIfAbsent(game, () => [DexBox('Caja 1')]);

  void _save() {
    _prefs.setString(
      boxesKey(_pid),
      jsonEncode({
        for (final e in _byGame.entries)
          e.key: [
            for (final b in e.value) {'n': b.name, 's': b.slots},
          ],
      }),
    );
    notifyListeners();
  }

  void rename(String game, int i, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    boxesOf(game)[i].name = n;
    _save();
  }

  void setSlot(String game, int box, int slot, String? value) {
    boxesOf(game)[box].slots[slot] = value;
    _save();
  }

  void swap(String game, int ba, int sa, int bb, int sb) {
    final b = boxesOf(game);
    final t = b[ba].slots[sa];
    b[ba].slots[sa] = b[bb].slots[sb];
    b[bb].slots[sb] = t;
    _save();
  }

  /// Mueve un Pokémon al primer hueco libre de otra caja. false si está llena.
  bool moveToBox(String game, int from, int slot, int to) {
    if (from == to) return true;
    final b = boxesOf(game);
    final free = b[to].slots.indexOf(null);
    if (free < 0) return false;
    b[to].slots[free] = b[from].slots[slot];
    b[from].slots[slot] = null;
    _save();
    return true;
  }

  void addBox(String game) {
    final b = boxesOf(game);
    b.add(DexBox('Caja ${b.length + 1}'));
    _save();
  }

  void removeBox(String game, int i) {
    final b = boxesOf(game);
    if (b.length <= 1) {
      b[0].slots.fillRange(0, boxSize, null);
    } else {
      b.removeAt(i);
    }
    _save();
  }

  void clearBox(String game, int i) {
    boxesOf(game)[i].slots.fillRange(0, boxSize, null);
    _save();
  }

  void moveBox(String game, int i, int delta) {
    final b = boxesOf(game);
    final j = i + delta;
    if (j < 0 || j >= b.length) return;
    final t = b[i];
    b[i] = b[j];
    b[j] = t;
    _save();
  }

  /// Borra las cajas de un juego propio en todos los perfiles.
  void removeGame(String game) {
    if (_byGame.remove(game) != null) _save();
    for (final p in _profiles.profiles) {
      if (p.id == _pid) continue;
      final key = boxesKey(p.id);
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final m = jsonDecode(raw) as Map<String, dynamic>;
        if (m.remove(game) != null) _prefs.setString(key, jsonEncode(m));
      } catch (_) {
        // Datos dañados: se dejan como están.
      }
    }
  }

  /// Sustituye todas las cajas del juego por las entradas dadas, 30 por caja.
  void fill(String game, List<String> ids) {
    final boxes = <DexBox>[];
    for (var i = 0; i < ids.length; i += boxSize) {
      final end = i + boxSize > ids.length ? ids.length : i + boxSize;
      final chunk = ids.sublist(i, end);
      boxes.add(DexBox('Caja ${boxes.length + 1}', _fit(chunk)));
    }
    if (boxes.isEmpty) boxes.add(DexBox('Caja 1'));
    _byGame[game] = boxes;
    _save();
  }
}
