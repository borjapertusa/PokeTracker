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


/// Proyección visual del tracker. Los datos completos permanecen intactos en
/// pokedex.json para poder reutilizar todas las formas en la futura Pokédex.
Species _trackerSpecies(Map<String, dynamic> source) {
  final dex = source['dex'] as int;
  final name = source['name'] as String;
  final entries = (source['entries'] as List)
      .cast<Map<String, dynamic>>()
      .where((e) {
        final id = e['id'] as String;
        if (id.contains('totem')) return false;
        if (dex == 3 && id == 'venusaur-mega-f') return false;
        if (dex == 25 && (id.contains('rock-star') || id.contains('belle') ||
            id.contains('pop-star') || id.contains('phd') || id.contains('libre') ||
            id.contains('cosplay') || id == 'pikachu-starter' ||
            id == 'pikachu-starter-f')) return false;
        if (dex == 133 && id.startsWith('eevee-starter')) return false;
        if (dex == 351 && id != 'castform') return false;
        if (dex == 421 && id == 'cherrim-sunshine') return false;
        if ([483, 484, 487].contains(dex) && id.endsWith('-origin')) return false;
        if (dex == 493 && id != 'arceus-normal') return false;
        if (dex == 555 && (id == 'darmanitan-zen' || id == 'darmanitan-galar-zen')) return false;
        if (dex == 646 && (id == 'kyurem-black' || id == 'kyurem-white')) return false;
        if (dex == 678 && (id == 'meowstic-female' || id == 'meowstic-female-mega')) return false;
        if (dex == 716 && id == 'xerneas-neutral') return false;
        if (dex == 718 && ['zygarde-10-power-construct','zygarde-50-power-construct','zygarde-complete'].contains(id)) return false;
        if (dex == 773 && id != 'silvally-normal') return false;
        // Se excluyen las siete formas Meteoro, incluida la forma por defecto;
        // se conservan las siete formas Núcleo.
        if (dex == 774 && id.contains('meteor')) return false;
        if (dex == 778 && id != 'mimikyu-disguised') return false;
        if (dex == 800 && id != 'necrozma') return false;
        if (dex == 801 && id == 'magearna-original-mega') return false;
        if (dex == 845 && id != 'cramorant') return false;
        if (dex == 876 && id == 'indeedee-female') return false;
        if (dex == 877 && id == 'morpeko-hangry') return false;
        if ([888,889].contains(dex) && id.endsWith('-crowned')) return false;
        if (dex == 890 && id == 'eternatus-eternamax') return false;
        if (dex == 916 && id == 'oinkologne-female') return false;
        if (dex == 978 && id == 'tatsugiri-droopy-mega' || dex == 978 && id == 'tatsugiri-stretchy-mega') return false;
        if ([1007,1008].contains(dex) && id != name) return false;
        if ([1017,1024].contains(dex) && id != name) return false;
        return true;
      })
      .map((e) {
        final m = Map<String, dynamic>.from(e);
        final id = m['id'] as String;
        const translations = {
          'unown-question': 'Interrogación',
          'unown-exclamation': 'Exclamación',
          'keldeo-resolute': 'Brío',
          'meloetta-pirouette': 'Danza',
          'flabebe-red': 'Roja', 'flabebe-yellow': 'Amarilla',
          'flabebe-orange': 'Naranja', 'flabebe-blue': 'Azul', 'flabebe-white': 'Blanca',
          'floette-red': 'Roja', 'floette-yellow': 'Amarilla',
          'floette-orange': 'Naranja', 'floette-blue': 'Azul', 'floette-white': 'Blanca',
          'florges-red': 'Roja', 'florges-yellow': 'Amarilla',
          'florges-orange': 'Naranja', 'florges-blue': 'Azul', 'florges-white': 'Blanca',
          'furfrou-natural': 'Natural', 'furfrou-heart': 'Corazón',
          'furfrou-star': 'Estrella', 'furfrou-diamond': 'Diamante',
          'furfrou-debutante': 'Dama', 'furfrou-matron': 'Señorita',
          'furfrou-dandy': 'Caballero', 'furfrou-la-reine': 'Reina',
          'furfrou-kabuki': 'Kabuki', 'furfrou-pharaoh': 'Faraón',
        };
        if (translations.containsKey(id)) m['label'] = translations[id]!.trim();
        if (dex == 678 && id == 'meowstic-male-mega') m['label'] = 'Mega';
        if (dex == 978 && id == 'tatsugiri-curly-mega') m['label'] = 'Mega';
        // El shiny de los Pikachu con gorra no fue liberado oficialmente.
        if (dex == 25 && id.contains('cap')) m['shiny'] = null;
        return m;
      }).toList();
  return Species.fromJson({...source, 'entries': entries});
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final raw = await rootBundle.loadString('assets/data/pokedex.json');
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final allSpecies = (data['species'] as List)
      .map((e) => Species.fromJson(e as Map<String, dynamic>))
      .toList();
  final species = (data['species'] as List)
      .map((e) => _trackerSpecies(e as Map<String, dynamic>))
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
    byDex: {for (final s in allSpecies) s.dex: s},
    allSpecies: allSpecies,
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
        if (es.isNotEmpty) list.add(GameSpecies(base, sm['n'] as int, es, label: sm['label'] as String?));
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
  final List<Species> allSpecies;
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
    required this.allSpecies,
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
              allSpecies: allSpecies,
              boxes: boxes,
              entryIndex: entryIndex,
              profiles: profiles),
        ),
      );
}
