import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Claves donde se guardan los datos de cada perfil.
String progressKey(String profileId) => 'progress_v1:$profileId';
String boxesKey(String profileId) => 'boxes_v1:$profileId';

/// El primer perfil hereda los datos guardados antes de que existieran los perfiles.
const defaultProfileId = 'p1';

/// Nombre de entrenador e ID de un perfil en un juego concreto.
class GameProfile {
  String name;
  String tid;
  GameProfile({this.name = '', this.tid = ''});
  bool get isEmpty => name.isEmpty && tid.isEmpty;
}

class Profile {
  final String id;
  String name;
  String? avatar; // 'idEntrada' o 'idEntrada|s' (variocolor): Pokémon favorito
  final Map<String, GameProfile> games; // idJuego -> datos
  Profile(this.id, this.name, {this.avatar, Map<String, GameProfile>? games})
      : games = games ?? {};
}

/// Perfiles de la app y perfil activo. Progreso y cajas se guardan por perfil.
class ProfileStore extends ChangeNotifier {
  static const _key = 'profiles_v1';
  final SharedPreferences _prefs;
  final List<Profile> profiles = [];
  String activeId = '';

  ProfileStore._(this._prefs);

  Profile get active =>
      profiles.firstWhere((p) => p.id == activeId, orElse: () => profiles.first);

  static Future<ProfileStore> load() async {
    final s = ProfileStore._(await SharedPreferences.getInstance());
    final raw = s._prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        for (final p in j['profiles'] as List) {
          final m = p as Map<String, dynamic>;
          final games = <String, GameProfile>{};
          (m['games'] as Map<String, dynamic>? ?? {}).forEach((g, v) {
            final gm = v as Map<String, dynamic>;
            games[g] = GameProfile(
                name: gm['n'] as String? ?? '', tid: gm['i'] as String? ?? '');
          });
          s.profiles.add(Profile(m['id'] as String, m['name'] as String,
              avatar: m['avatar'] as String?, games: games));
        }
        s.activeId = j['active'] as String? ?? '';
      } catch (_) {
        s.profiles.clear();
      }
    }
    if (s.profiles.isEmpty) s.profiles.add(Profile(defaultProfileId, 'Perfil 1'));
    if (!s.profiles.any((p) => p.id == s.activeId)) {
      s.activeId = s.profiles.first.id;
    }
    return s;
  }

  void _save() {
    _prefs.setString(
      _key,
      jsonEncode({
        'active': activeId,
        'profiles': [
          for (final p in profiles)
            {
              'id': p.id,
              'name': p.name,
              'avatar': p.avatar,
              'games': {
                for (final e in p.games.entries)
                  e.key: {'n': e.value.name, 'i': e.value.tid},
              },
            },
        ],
      }),
    );
    notifyListeners();
  }

  Profile create(String name) {
    final p = Profile('p${DateTime.now().millisecondsSinceEpoch}', name.trim());
    profiles.add(p);
    _save();
    return p;
  }

  void select(String id) {
    if (!profiles.any((p) => p.id == id) || id == activeId) return;
    activeId = id;
    _save();
  }

  void rename(Profile p, String name) {
    final n = name.trim();
    if (n.isEmpty) return;
    p.name = n;
    _save();
  }

  void setAvatar(Profile p, String? value) {
    p.avatar = value;
    _save();
  }

  void setGame(Profile p, String gameId,
      {required String name, required String tid}) {
    final gp = p.games.putIfAbsent(gameId, () => GameProfile());
    gp.name = name.trim();
    gp.tid = tid.trim();
    if (gp.isEmpty) p.games.remove(gameId);
    _save();
  }

  /// Quita el nombre e ID de entrenador de un juego (al eliminar un juego propio).
  void removeGameData(String gameId) {
    var changed = false;
    for (final p in profiles) {
      if (p.games.remove(gameId) != null) changed = true;
    }
    if (changed) _save();
  }

  /// Elimina un perfil y sus datos. false si es el único que queda.
  bool delete(String id) {
    if (profiles.length <= 1) return false;
    if (id == activeId) {
      activeId = profiles.firstWhere((p) => p.id != id).id;
    }
    profiles.removeWhere((p) => p.id == id);
    _prefs.remove(progressKey(id));
    _prefs.remove(boxesKey(id));
    if (id == defaultProfileId) {
      _prefs.remove('progress_v1');
      _prefs.remove('boxes_v1');
    }
    _save();
    return true;
  }
}
