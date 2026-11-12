import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokedex_tracker/models.dart';
import 'package:pokedex_tracker/pokepc_local_repository.dart';

/// Verificación de la migración a PokéPC: prepara una instalación portable
/// temporal junto al ejecutable de prueba a partir de la caché local del
/// dataset (.tmp/) y la elimina al terminar. Se omite si no hay caché o si
/// ya existe una instalación portable (para no alterarla).
void main() {
  final cache = Directory('${Directory.current.path}/.tmp');
  final root = PokepcLocalRepository.root;
  final canRun = !root.existsSync() &&
      File('${cache.path}/pokemon_index.json').existsSync() &&
      Directory('${cache.path}/records').existsSync();
  final skip = canRun ? null : 'Requiere la caché .tmp/ del dataset PokéPC';

  late List<Species> species;
  late Map<int, Species> byDex;
  late Map<String, DexEntry> byId;

  setUpAll(() async {
    if (!canRun) return;
    await Directory('${root.path}/indices').create(recursive: true);
    await Directory('${root.path}/pokemon').create(recursive: true);
    await Directory('${root.path}/i18n/es-es').create(recursive: true);
    await Directory('${root.path}/i18n/eng').create(recursive: true);
    await Directory('${root.path}/metadata').create(recursive: true);
    await File('${cache.path}/pokemon_index.json')
        .copy('${root.path}/indices/pokemon.json');
    await for (final f in Directory('${cache.path}/records').list()) {
      if (f is File && f.path.endsWith('.json')) {
        await f.copy('${root.path}/pokemon/${f.uri.pathSegments.last}');
      }
    }
    await File('${cache.path}/pokemon_es.json')
        .copy('${root.path}/i18n/es-es/pokemon.json');
    await File('${cache.path}/pokemon_en.json')
        .copy('${root.path}/i18n/eng/pokemon.json');
    await File('${root.path}/metadata/local-install.json').writeAsString(
        jsonEncode({'snapshotSchema': 3, 'version': 'v8-test'}));

    final legacy = jsonDecode(
            await File('assets/data/pokedex.json').readAsString())
        as Map<String, dynamic>;
    final namesByDex = <int, String>{
      for (final s in legacy['species'] as List)
        (s as Map<String, dynamic>)['dex'] as int: s['name'] as String,
    };
    species = await PokepcLocalRepository.loadTrackerSpecies(
        namesByDex: namesByDex);
    byDex = {for (final s in species) s.dex: s};
    byId = {
      for (final s in species)
        for (final e in s.entries) e.id: e,
    };
  });

  tearDownAll(() async {
    if (canRun && root.existsSync()) await root.delete(recursive: true);
  });

  DexEntry entry(String id) {
    final e = byId[id];
    expect(e, isNotNull, reason: 'Falta la entrada $id');
    return e!;
  }

  test('instalación portable reconocida con el esquema 3', () async {
    expect(await PokepcLocalRepository.isInstalled, isTrue);
  }, skip: skip);

  test('catálogo completo: 1025 especies ordenadas por número nacional', () {
    expect(species.length, 1025);
    expect(species.map((s) => s.dex).toList(),
        List<int>.generate(1025, (i) => i + 1));
  }, skip: skip);

  test('identificadores de entrada únicos (progreso y games.json)', () {
    final all = [for (final s in species) for (final e in s.entries) e.id];
    expect(all.toSet().length, all.length);
    expect(all.length, 1595, reason: 'Ninguna forma debe perderse (floette-eternal-mega incluida)');
  }, skip: skip);

  test('todos los sprites usan tokens nid válidos', () {
    final normal = RegExp(r'^pokepc:[0-9]{4}(-[a-z0-9-]+)?$');
    final shiny = RegExp(r'^pokepc-shiny:[0-9]{4}(-[a-z0-9-]+)?$');
    for (final s in species) {
      for (final e in s.entries) {
        expect(e.sprite, isNotNull, reason: '${s.dex} ${e.id} sin sprite');
        expect(normal.hasMatch(e.sprite!), isTrue,
            reason: 'Token inválido: ${e.sprite}');
        if (e.shiny != null) {
          expect(shiny.hasMatch(e.shiny!), isTrue,
              reason: 'Token variocolor inválido: ${e.shiny}');
        }
      }
    }
  }, skip: skip);

  test('formas y hembras: Venusaur, Pikachu, Meowstic, Frillish', () {
    expect(entry('venusaur').gender, 'male');
    expect(entry('venusaur-f').gender, 'female');
    expect(entry('venusaur-f').sprite, 'pokepc:0003-f');
    expect(entry('venusaur-mega').sprite, 'pokepc:0003-mega');
    expect(entry('venusaur-mega').shiny, 'pokepc-shiny:0003-mega');
    expect(entry('venusaur-gmax').kind, 'gmax');
    expect(entry('pikachu-f').gender, 'female');
    expect(entry('pikachu-gmax').sprite, 'pokepc:0025-gmax');
    expect(entry('pikachu-gmax').shiny, isNotNull);
    expect(entry('meowstic-male'), isNotNull);
    expect(entry('meowstic-female'), isNotNull);
    expect(entry('meowstic-male-mega'), isNotNull);
    expect(entry('frillish-male').gender, 'male');
    expect(entry('frillish-female').gender, 'female');
  }, skip: skip);

  test('Arceus conserva todos sus tipos y la Tabla Legendaria', () {
    final arceus = byDex[493]!;
    expect(arceus.entries.length, 19);
    expect(entry('arceus-normal').sprite, 'pokepc:0493');
    expect(entry('arceus-fairy').sprite, 'pokepc:0493-fairy');
    expect(entry('arceus-legendary').sprite, 'pokepc:0493-legendary');
  }, skip: skip);

  test('Vivillon: 20 patrones, variocolor solo donde está publicado', () {
    final vivillon = byDex[666]!;
    expect(vivillon.entries.length, 20);
    expect(entry('vivillon-icy-snow').sprite, 'pokepc:0666');
    expect(entry('vivillon-poke-ball').sprite, 'pokepc:0666-pokeball');
    expect(entry('vivillon-poke-ball').shiny, isNull);
    expect(entry('vivillon-fancy').shiny, isNotNull);
    expect(entry('floette-eternal').shiny, isNull);
    expect(entry('floette-mega').sprite, 'pokepc:0670-eternal-mega');
  }, skip: skip);

  test('Minior y bases con slug de forma conservan el slug de PokéAPI', () {
    expect(byDex[774]!.name, 'minior');
    expect(byDex[774]!.nameEs, 'Minior');
    expect(entry('minior-red-meteor').sprite, 'pokepc:0774');
    expect(entry('minior-red').sprite, 'pokepc:0774-red');
    expect(entry('minior-blue'), isNotNull);
    expect(byDex[681]!.name, 'aegislash');
    expect(entry('aegislash-shield'), isNotNull);
    expect(byDex[250]!.name, 'ho-oh');
    expect(byDex[250]!.nameEs, 'Ho-Oh');
    expect(byDex[984]!.name, 'great-tusk');
    expect(byDex[984]!.nameEs, 'Colmilargo');
    expect(byDex[986]!.name, 'brute-bonnet');
    expect(byDex[986]!.nameEs, 'Furioseta');
  }, skip: skip);

  test('Greninja Ash, Mothim y Scatterbug conservan sus entradas', () {
    expect(entry('greninja-battle-bond').sprite, 'pokepc:0658-ash');
    expect(entry('greninja-battle-bond').shiny, isNull);
    expect(entry('greninja-mega'), isNotNull);
    expect(byDex[414]!.entries.single.id, 'mothim-plant');
    expect(byDex[664]!.entries.single.id, 'scatterbug-icy-snow');
    expect(byDex[665]!.entries.single.id, 'spewpa-icy-snow');
  }, skip: skip);

  test('nombres visibles sin calificadores de forma', () {
    for (final s in species) {
      expect(s.nameEs.contains(' ('), isFalse,
          reason: '${s.dex}: ${s.nameEs}');
      expect(s.displayName(true), s.nameEs);
    }
  }, skip: skip);

  test('games.json: ningún Pokémon pierde todas sus entradas', () async {
    final raw = jsonDecode(await File('assets/data/games.json').readAsString())
        as Map<String, dynamic>;
    var empty = <String>[];
    for (final g in raw['games'] as List) {
      final game = g as Map<String, dynamic>;
      for (final sp in game['species'] as List) {
        final s = sp as Map<String, dynamic>;
        final ids = (s['e'] as List).cast<String>();
        if (!ids.any(byId.containsKey)) {
          empty.add('${game['id']} #${s['d']}');
        }
      }
    }
    expect(empty, isEmpty);
    for (final id in [
      'scatterbug-icy-snow', 'spewpa-icy-snow', 'vivillon-icy-snow',
      'vivillon-poke-ball', 'mothim-plant', 'minior-red-meteor',
      'greninja-battle-bond', 'meowstic-female', 'meowstic-male-mega',
      'arceus-normal', 'rockruff', 'lycanroc-dusk',
    ]) {
      expect(byId.containsKey(id), isTrue, reason: 'games.json necesita $id');
    }
  }, skip: skip);
}