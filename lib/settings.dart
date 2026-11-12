import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ViewMode { grid, list }

/// Estilo de sprites: 2D clásico, render 3D de HOME o 3D animado.
enum SpriteMode { twoD, threeD, animated }

/// Opciones visuales de la app, guardadas en el equipo.
class AppSettings extends ChangeNotifier {
  static AppSettings? current;
  static const _key = 'settings_v1';

  static const accents = <String, Color>{
    'Rojo': Colors.red,
    'Naranja': Colors.orange,
    'Verde': Colors.green,
    'Turquesa': Colors.teal,
    'Azul': Colors.blue,
    'Morado': Colors.deepPurple,
    'Rosa': Colors.pink,
    'Gris': Colors.blueGrey,
  };

  final SharedPreferences _prefs;
  AppSettings._(this._prefs);

  ThemeMode themeMode = ThemeMode.system;
  String accent = 'Rojo';
  double textScale = 1.0; // 0.8 – 1.5
  double spriteSize = 80; // 48 – 128
  double leftSidebarWidth = 270; // 200 – 420
  double rightSidebarWidth = 420; // 300 – 700
  Map<String, String> detailOverrides = {};
  ViewMode viewMode = ViewMode.grid;
  bool spanish = true;
  bool pixelSprites = true;
  /// Estilo de los sprites: 2D, 3D (render HOME) o 3D animados.
  SpriteMode spriteMode = SpriteMode.twoD;

  /// Los sprites 3D (estáticos o animados) usan el render de HOME.
  bool get threeDSprites => spriteMode != SpriteMode.twoD;
  bool get animatedSprites => spriteMode == SpriteMode.animated;
  bool offlineMode = false;
  String lastGame = 'home';

  Color get seed => accents[accent] ?? Colors.red;

  static double _d(dynamic v, double def, double lo, double hi) =>
      ((v is num) ? v.toDouble() : def).clamp(lo, hi).toDouble();

  static Future<AppSettings> load() async {
    final s = AppSettings._(await SharedPreferences.getInstance());
    final raw = s._prefs.getString(_key);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        s.themeMode = ThemeMode.values.firstWhere(
            (m) => m.name == j['themeMode'],
            orElse: () => ThemeMode.system);
        s.accent = accents.containsKey(j['accent']) ? j['accent'] : 'Rojo';
        s.textScale = _d(j['textScale'], 1.0, 0.8, 1.5);
        s.spriteSize = _d(j['spriteSize'], 80, 48, 128);
        s.leftSidebarWidth = _d(j['leftSidebarWidth'], 270, 200, 420);
        s.rightSidebarWidth = _d(j['rightSidebarWidth'], 420, 300, 700);
        final rawOverrides = j['detailOverrides'];
        if (rawOverrides is Map) {
          s.detailOverrides = rawOverrides.map((k, v) => MapEntry(k.toString(), v.toString()));
        }
        s.viewMode = ViewMode.values.firstWhere((m) => m.name == j['viewMode'],
            orElse: () => ViewMode.grid);
        s.spanish = j['spanish'] != false;
        s.pixelSprites = j['pixelSprites'] != false;
        final mode = j['spriteMode'];
        s.spriteMode = SpriteMode.values.firstWhere((m) => m.name == mode,
            orElse: () => j['threeDSprites'] == true
                ? SpriteMode.threeD
                : SpriteMode.twoD);
        s.offlineMode = j['offlineMode'] == true;
        s.lastGame = (j['lastGame'] as String?) ?? 'home';
      } catch (_) {
        // Si el archivo está dañado se usan los valores por defecto.
      }
    }
    current = s;
    return s;
  }

  /// Aplica un cambio, lo guarda y avisa a la interfaz.
  void update(void Function() change) {
    change();
    _prefs.setString(
        _key,
        jsonEncode({
          'themeMode': themeMode.name,
          'accent': accent,
          'textScale': textScale,
          'spriteSize': spriteSize,
          'leftSidebarWidth': leftSidebarWidth,
          'rightSidebarWidth': rightSidebarWidth,
          'detailOverrides': detailOverrides,
          'viewMode': viewMode.name,
          'spanish': spanish,
          'pixelSprites': pixelSprites,
          'spriteMode': spriteMode.name,
          'threeDSprites': threeDSprites,
          'offlineMode': offlineMode,
          'lastGame': lastGame,
        }));
    notifyListeners();
  }

  void reset() => update(() {
        themeMode = ThemeMode.system;
        accent = 'Rojo';
        textScale = 1.0;
        spriteSize = 80;
        leftSidebarWidth = 270;
        rightSidebarWidth = 420;
        viewMode = ViewMode.grid;
        spanish = true;
        pixelSprites = true;
        spriteMode = SpriteMode.twoD;
        offlineMode = false;
      });
}
