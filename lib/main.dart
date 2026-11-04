import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boxes.dart';
import 'details.dart';
import 'game_store.dart';
import 'models.dart';
import 'profiles.dart';
import 'progress.dart';
import 'launcher.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/data/pokedex.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final species = (data['species'] as List)
      .map((e) => Species.fromJson(e as Map<String, dynamic>))
      .toList();
  final baseGames = await _loadGames(species);
  final profiles = await ProfileStore.load();
  final progress = await Progress.load(profiles);
  final settings = await AppSettings.load();
  final boxes = await BoxStore.load(profiles);
  // Lista de Pokédex de la barra lateral (las de la app + las que crea el usuario).
  final store = await GameStore.load(
    species,
    baseGames,
    onPurge: (id) {
      progress.removeGame(id);
      boxes.removeGame(id);
      profiles.removeGameData(id);
    },
  );
  runApp(PokedexApp(
    games: store.games,
    store: store,
    progress: progress,
    settings: settings,
    details: await _loadDetails(),
    byDex: {for (final s in species) s.dex: s},
    boxes: boxes,
    profiles: profiles,
    entryIndex: {
      for (final s in species)
        for (final e in s.entries) e.id: (s, e),
    },
  ));
}

/// Fichas (estadísticas, evolución, ubicaciones) si existe details.json.
Future<DexDetails?> _loadDetails() async {
  try {
    final raw = await rootBundle.loadString('assets/data/details.json');
    return DexDetails.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Pokémon HOME (todo) + los juegos de assets/data/games.json, si existe.
Future<List<Game>> _loadGames(List<Species> species) async {
  final games = <Game>[
    Game(
      id: 'home',
      name: 'Pokémon HOME',
      gen: 0,
      shiny: true,
      genders: true,
      species: [for (final s in species) GameSpecies(s, s.dex, s.entries)],
    ),
  ];
  try {
    final byDex = {for (final s in species) s.dex: s};
    final byId = {
      for (final s in species)
        for (final e in s.entries) e.id: e,
    };
    final raw = await rootBundle.loadString('assets/data/games.json');
    final gj = jsonDecode(raw) as Map<String, dynamic>;
    for (final g in gj['games'] as List) {
      final m = g as Map<String, dynamic>;
      final list = <GameSpecies>[];
      for (final sp in m['species'] as List) {
        final sm = sp as Map<String, dynamic>;
        final base = byDex[sm['d'] as int];
        if (base == null) continue;
        final es = <DexEntry>[
          for (final id in sm['e'] as List)
            if (byId[id] != null) byId[id]!,
        ];
        if (es.isNotEmpty) list.add(GameSpecies(base, sm['n'] as int, es));
      }
      games.add(Game(
        id: m['id'] as String,
        name: m['name'] as String,
        gen: m['gen'] as int,
        shiny: m['shiny'] as bool,
        genders: m['genders'] as bool,
        species: list,
      ));
    }
  } catch (_) {
    // Sin games.json (aún no generado) solo se muestra Pokémon HOME.
  }
  return games;
}

class PokedexApp extends StatelessWidget {
  final List<Game> games;
  final GameStore store;
  final Progress progress;
  final AppSettings settings;
  final DexDetails? details;
  final Map<int, Species> byDex;
  final BoxStore boxes;
  final EntryIndex entryIndex;
  final ProfileStore profiles;
  const PokedexApp({
    super.key,
    required this.games,
    required this.store,
    required this.progress,
    required this.settings,
    required this.details,
    required this.byDex,
    required this.boxes,
    required this.entryIndex,
    required this.profiles,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Pokédex Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: ThemeData(
              colorSchemeSeed: settings.seed,
              brightness: Brightness.light,
              useMaterial3: true),
          darkTheme: ThemeData(
              colorSchemeSeed: settings.seed,
              brightness: Brightness.dark,
              useMaterial3: true),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(settings.textScale)),
            child: child!,
          ),
          home: LauncherScreen(
              games: games,
              store: store,
              progress: progress,
              settings: settings,
              details: details,
              byDex: byDex,
              boxes: boxes,
              entryIndex: entryIndex,
              profiles: profiles),
        ),
      );
}
