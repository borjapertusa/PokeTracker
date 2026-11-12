import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Descarga una instantánea completa de PokéPC Dataset v8 y los iconos HOME
/// 3D servidos por PokéPC. Los datos se guardan junto al ejecutable.
///
/// El dataset v8 publica los JSON en la raíz de la API (sin prefijo /data/).
/// Los textos están separados por idioma en `/i18n/<locale>/`.
class PokepcDatasetUpdater {
  PokepcDatasetUpdater._();

  static const String baseUrl = 'https://pokepc.github.io/dataset/v8/';
  static const List<String> _baseUrlCandidates = [
    'https://pokepc.github.io/dataset/v8/',
    'https://pokepc.github.io/dataset/latest/',
    'https://pokepc.github.io/dataset/',
  ];
  static const String spanishLocale = 'es-es';
  static const String englishLocale = 'eng';
  static const String _iconBaseUrl =
      'https://static.pokepc.net/images/pokemon/home3d-icon-xl';
  static const int _snapshotSchema = 3;
  static const List<String> _overrideAssets = [
    'games.json',
    'pokedexes.json',
    'regions.json',
    'types.json',
  ];

  static const List<String> _collectionFiles = [
    'abilities.json',
    'battle-states.json',
    'items.json',
    'moves.json',
    'pokeballs.json',
    'languages.json',
    'marks.json',
    'ribbons.json',
    'types.json',
    'natures.json',
    'characters.json',
    'colors.json',
    'generations.json',
    'originmarks.json',
    'personalities.json',
    'regions.json',
    'locations.json',
    'metadata/pokemon-mugshots.json',
    'codes/pokemon.json',
    'codes/ribbons.json',
    'codes/marks.json',
    'codes/moves.json',
  ];

  static const List<String> _indices = [
    'indices/pokemon.json',
    'indices/games.json',
    'indices/pokedexes.json',
  ];

  static const List<String> _textKinds = [
    'abilities',
    'battle-states',
    'characters',
    'colors',
    'games',
    'items',
    'locations',
    'marks',
    'moves',
    'natures',
    'originmarks',
    'personalities',
    'pokeballs',
    'pokedexes',
    'pokemon',
    'regions',
    'ribbons',
    'types',
  ];

  static Directory get portableDataDirectory {
    final executableDirectory = File(Platform.resolvedExecutable).parent;
    return Directory(
      '${executableDirectory.path}${Platform.pathSeparator}data${Platform.pathSeparator}pokepc',
    );
  }

  static Future<PokepcUpdateResult> update({
    void Function(String message, int completed, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 25)
      ..idleTimeout = const Duration(seconds: 25)
      ..userAgent = 'PokeTracker/1.0 (PokePC offline dataset updater)';

    final target = portableDataDirectory;
    final parent = target.parent;
    await parent.create(recursive: true);
    final stamp = DateTime.now().toUtc().microsecondsSinceEpoch;
    final staging = Directory(
      '${parent.path}${Platform.pathSeparator}.pokepc-staging-$stamp',
    );
    final backup = Directory(
      '${parent.path}${Platform.pathSeparator}.pokepc-backup-$stamp',
    );
    await staging.create(recursive: true);

    var completed = 0;
    var total = 1 + _collectionFiles.length + _indices.length;
    var downloaded = 0;
    var missingOptional = 0;
    var downloadedIcons = 0;
    var missingIcons = 0;
    var apiBaseUrl = baseUrl;
    final failures = <String>[];

    void report(String label) {
      completed++;
      onProgress?.call(label, completed, total);
    }

    String localPath(String relativePath) =>
        '${staging.path}${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}';

    Future<List<int>?> getBytes(
      Uri uri, {
      bool optional = false,
      bool ignoreErrors = false,
    }) async {
      // GitHub Pages/CDN puede responder temporalmente 503 cuando recibe
      // muchas peticiones simultáneas. Reintentamos antes de marcar el archivo
      // como fallido para no cancelar una instantánea completa por un pico.
      const maxAttempts = 4;
      Object? lastError;

      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final request = await client.getUrl(uri);
          request.headers.set(HttpHeaders.acceptHeader, '*/*');
          final response = await request.close();

          if (response.statusCode == HttpStatus.notFound && optional) {
            await response.drain<void>();
            missingOptional++;
            return null;
          }

          if (response.statusCode != HttpStatus.ok) {
            final statusCode = response.statusCode;
            await response.drain<void>();
            final retryableStatus = statusCode == 408 ||
                statusCode == 429 ||
                statusCode == 500 ||
                statusCode == 502 ||
                statusCode == 503 ||
                statusCode == 504;
            final error = HttpException('HTTP $statusCode', uri: uri);
            if (!retryableStatus || attempt == maxAttempts) throw error;
            lastError = error;
          } else {
            final bytes = await response.fold<List<int>>(
              <int>[],
              (a, b) => a..addAll(b),
            );
            if (bytes.isEmpty) {
              throw const FormatException('Respuesta vacía');
            }
            return bytes;
          }
        } catch (error) {
          lastError = error;
          final isPermanentHttpError = error is HttpException &&
              !RegExp(r'HTTP (408|429|500|502|503|504)')
                  .hasMatch(error.message);
          if (isPermanentHttpError || attempt == maxAttempts) break;
        }

        if (attempt < maxAttempts) {
          await Future<void>.delayed(Duration(seconds: 1 << (attempt - 1)));
        }
      }

      if (!ignoreErrors) failures.add('${uri.path}: $lastError');
      return null;
    }

    Future<bool> fetch(String relativePath, {bool required = false}) async {
      final uri = Uri.parse('$apiBaseUrl$relativePath');
      final bytes = await getBytes(uri, optional: !required);
      if (bytes == null) return false;
      try {
        if (relativePath.endsWith('.json')) jsonDecode(utf8.decode(bytes));
        final file = File(localPath(relativePath));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
        downloaded++;
        return true;
      } catch (error) {
        failures.add('$relativePath: JSON/archivo inválido: $error');
        return false;
      }
    }

    try {
      await _prepareOverrides(target, staging);

      // PokéPC publica una ruta por versión estable y otra para latest.
      // Probamos las tres rutas documentadas para evitar fallos si el alias
      // de una versión todavía no se ha desplegado en GitHub Pages.
      Map<String, dynamic>? spec;
      final specErrors = <String>[];
      for (final candidate in _baseUrlCandidates) {
        final uri = Uri.parse('${candidate}openapi.json');
        try {
          final request = await client.getUrl(uri);
          request.headers.set(HttpHeaders.acceptHeader, 'application/json');
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            await response.drain<void>();
            specErrors.add('$uri respondió HTTP ${response.statusCode}');
            continue;
          }
          final bytes = await response.fold<List<int>>(
            <int>[],
            (a, b) => a..addAll(b),
          );
          final decoded = jsonDecode(utf8.decode(bytes));
          if (decoded is! Map<String, dynamic> ||
              decoded['openapi'] == null || decoded['info'] is! Map) {
            specErrors.add('$uri no contiene una especificación OpenAPI válida');
            continue;
          }
          apiBaseUrl = candidate;
          spec = decoded;
          final specFile = File(localPath('openapi.json'));
          await specFile.parent.create(recursive: true);
          await specFile.writeAsBytes(bytes, flush: true);
          downloaded++;
          break;
        } catch (error) {
          specErrors.add('$uri: $error');
        }
      }
      report('Comprobando versión publicada de PokéPC');
      if (spec == null) {
        throw Exception(
          'No se pudo descargar openapi.json desde ninguna ruta de PokéPC. '
          '${specErrors.join(' | ')}',
        );
      }
      final version = (spec['info'] as Map?)?['version']?.toString() ?? 'desconocida';

      final previous = await readInstalledMetadata();
      if (previous?['version'] == version &&
          previous?['snapshotSchema'] == _snapshotSchema &&
          await target.exists()) {
        await staging.delete(recursive: true);
        return PokepcUpdateResult(
          version: version,
          files: 0,
          missingOptional: 0,
          icons: 0,
          missingIcons: 0,
          pokemon: (previous?['pokemonCount'] as num?)?.toInt() ?? 0,
          games: (previous?['gameCount'] as num?)?.toInt() ?? 0,
          pokedexes: (previous?['pokedexCount'] as num?)?.toInt() ?? 0,
          directory: target.path,
          alreadyLatest: true,
        );
      }

      for (final path in _collectionFiles) {
        await fetch(path);
        report('Descargando $path');
      }

      final indices = <String, List<String>>{};
      for (final path in _indices) {
        final ok = await fetch(path, required: true);
        report('Descargando $path');
        if (!ok) {
          throw Exception('No se pudo descargar el índice obligatorio $path.');
        }
        final decoded = jsonDecode(await File(localPath(path)).readAsString());
        if (decoded is! List || decoded.any((e) => e is! String)) {
          throw FormatException('Índice inválido: $path');
        }
        indices[path] = decoded.cast<String>();
      }

      final pokemonIds = indices['indices/pokemon.json']!;
      final gameIds = indices['indices/games.json']!;
      final pokedexIds = indices['indices/pokedexes.json']!;
      final entityTasks = <String>[
        ...pokemonIds.map((id) => 'pokemon/$id.json'),
        ...gameIds.map((id) => 'games/$id.json'),
        ...pokedexIds.map((id) => 'pokedexes/$id.json'),
      ];
      total += entityTasks.length;
      await _runPool(entityTasks, 4, (path) async {
        await fetch(path, required: true);
        report('Descargando $path');
      });

      // v8 mantiene los textos separados. ES-ES es la primera opción y ENG
      // sirve como fallback explícito cuando PokéPC no ha publicado un campo.
      final translationTasks = <String>[
        for (final language in [spanishLocale, englishLocale])
          for (final kind in _textKinds) 'i18n/$language/$kind.json',
      ];
      total += translationTasks.length;
      await _runPool(translationTasks, 4, (path) async {
        await fetch(path); // 404: PokéPC no ofrece ese tipo en ese idioma.
        report('Descargando traducciones ${path.split('/').last}');
      });

      // Las descripciones narrativas de PokéPC existen en inglés y alemán,
      // no en es-es. Descargamos ENG como respaldo; el overlay ES-ES propio
      // se añadirá por separado sin atribuir esas traducciones a PokéPC.
      final proseSpeciesIds = <String>{};
      for (final id in pokemonIds) {
        final recordFile = File(localPath('pokemon/$id.json'));
        if (!await recordFile.exists()) continue;
        try {
          final record = jsonDecode(await recordFile.readAsString()) as Map<String, dynamic>;
          if (record['isForm'] == true) continue;
          final baseSpecies = record['baseSpecies'];
          proseSpeciesIds.add(
            baseSpecies is String && baseSpecies.isNotEmpty ? baseSpecies : id,
          );
        } catch (_) {
          proseSpeciesIds.add(id);
        }
      }
      final proseTasks = proseSpeciesIds
          .map((id) => 'i18n/$englishLocale/pokemon-prose/$id.md')
          .toList();
      total += proseTasks.length;
      await _runPool(proseTasks, 4, (path) async {
        await fetch(path); // 404 significa que no hay descripción para esa especie.
        report('Descargando descripción ${path.split('/').last}');
      });

      // Datos específicos de Pokémon Champions: roster y vistas fusionadas.
      final rosterOk = await fetch('mods/champions/roster.json');
      report('Comprobando datos de Pokémon Champions');
      if (rosterOk) {
        final roster = jsonDecode(await File(localPath('mods/champions/roster.json')).readAsString())
            as Map<String, dynamic>;
        final championsPokemon = (roster['pokemon'] as List? ?? const [])
            .whereType<String>()
            .map((id) => 'games/champions/pokemon/$id.json')
            .toList();
        final championsFiles = <String>[
          'games/champions/moves.json',
          'games/champions/abilities.json',
          'games/champions/items.json',
          'games/champions/battle-states.json',
          for (final locale in [spanishLocale, englishLocale])
            for (final kind in _textKinds)
              'games/champions/i18n/$locale/$kind.json',
          ...championsPokemon,
        ];
        total += championsFiles.length;
        await _runPool(championsFiles, 4, (path) async {
          await fetch(path);
          report('Descargando datos de Champions: ${path.split('/').last}');
        });
      }

      // Iconos HOME 3D: no forman parte de los JSON del dataset; PokéPC los
      // sirve en su CDN con el nombre `nid` de cada registro (p. ej. 0003,
      // 0003-f, 0003-mega). Ese identificador —no el de PokéAPI— es la clave
      // real de las imágenes, incluidas formas y diferencias de género.
      final iconNids = <String, bool>{};
      for (final id in pokemonIds) {
        final recordFile = File(localPath('pokemon/$id.json'));
        if (!await recordFile.exists()) continue;
        try {
          final record = jsonDecode(await recordFile.readAsString()) as Map<String, dynamic>;
          final nid = record['nid']?.toString();
          if (nid == null || !RegExp(r'^[0-9]{4}(-[a-z0-9-]+)?$').hasMatch(nid)) {
            continue;
          }
          iconNids[nid] = iconNids[nid] == true || record['shinyReleased'] == true;
        } catch (_) {}
      }
      final iconTasks = <(String, String)>[];
      for (final entry in iconNids.entries) {
        final nid = entry.key;
        iconTasks.add(('regular/$nid.webp', 'regular/$nid.webp'));
        if (entry.value) iconTasks.add(('shiny/$nid.webp', 'shiny/$nid.webp'));
      }
      total += iconTasks.length;
      await _runPool(iconTasks, 3, (task) async {
        final relative = 'sprites/home3d/${task.$2}';
        final uri = Uri.parse('$_iconBaseUrl/${task.$1}');
        final bytes = await getBytes(uri, optional: true, ignoreErrors: true);
        final validWebp = bytes != null && bytes.length >= 12 &&
            ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
            ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
        if (validWebp) {
          final file = File(localPath(relative));
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
          downloadedIcons++;
        } else {
          missingIcons++;
        }
        report('Descargando iconos HOME 3D ${task.$1}');
      });

      if (failures.isNotEmpty) {
        throw Exception(
          'La descarga quedó incompleta (${failures.length} errores). Primer error: ${failures.first}',
        );
      }

      final metadata = <String, dynamic>{
        'source': 'PokéPC Dataset',
        'baseUrl': apiBaseUrl,
        'version': version,
        'snapshotSchema': _snapshotSchema,
        'locale': spanishLocale,
        'fallbackLocale': englishLocale,
        'downloadedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'downloadedFiles': downloaded,
        'missingOptionalFiles': missingOptional,
        'downloadedHomeIcons': downloadedIcons,
        'missingHomeIcons': missingIcons,
        'pokemonCount': pokemonIds.length,
        'gameCount': gameIds.length,
        'pokedexCount': pokedexIds.length,
      };
      final metadataFile = File(localPath('metadata/local-install.json'));
      await metadataFile.parent.create(recursive: true);
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata),
        flush: true,
      );

      // Publicación atómica: la instalación previa se conserva hasta que el
      // snapshot nuevo está descargado y validado por completo.
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staging.rename(target.path);
      } catch (_) {
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);

      return PokepcUpdateResult(
        version: version,
        files: downloaded,
        missingOptional: missingOptional,
        icons: downloadedIcons,
        missingIcons: missingIcons,
        pokemon: pokemonIds.length,
        games: gameIds.length,
        pokedexes: pokedexIds.length,
        directory: target.path,
      );
    } catch (_) {
      if (await staging.exists()) await staging.delete(recursive: true);
      rethrow;
    } finally {
      client.close(force: true);
    }
  }


  static Future<void> _prepareOverrides(Directory target, Directory staging) async {
    final oldOverrides = Directory(
      '${target.path}${Platform.pathSeparator}overrides',
    );
    if (await oldOverrides.exists()) {
      await for (final entity in oldOverrides.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final relative = entity.path.substring(oldOverrides.path.length + 1);
        final destination = File(
          '${staging.path}${Platform.pathSeparator}overrides${Platform.pathSeparator}$relative',
        );
        await destination.parent.create(recursive: true);
        await entity.copy(destination.path);
      }
    }

    // Copia los primeros complementos ES-ES empaquetados con la aplicación,
    // pero nunca pisa traducciones locales que el usuario haya editado.
    for (final name in _overrideAssets) {
      final destination = File(
        '${staging.path}${Platform.pathSeparator}overrides${Platform.pathSeparator}i18n${Platform.pathSeparator}es-es${Platform.pathSeparator}$name',
      );
      if (await destination.exists()) continue;
      try {
        final contents = await rootBundle.loadString(
          'assets/data/pokepc-overrides/i18n/es-es/$name',
        );
        await destination.parent.create(recursive: true);
        await destination.writeAsString(contents, flush: true);
      } catch (_) {
        // El complemento es opcional: el dataset sigue siendo válido sin él.
      }
    }
  }

  static Future<void> _runPool<T>(
    List<T> values,
    int concurrency,
    Future<void> Function(T value) action,
  ) async {
    var next = 0;
    Future<void> worker() async {
      while (true) {
        final index = next++;
        if (index >= values.length) return;
        await action(values[index]);
      }
    }
    await Future.wait(List.generate(concurrency, (_) => worker()));
  }

  static Future<Map<String, dynamic>?> readInstalledMetadata() async {
    try {
      final file = File(
        '${portableDataDirectory.path}${Platform.pathSeparator}metadata${Platform.pathSeparator}local-install.json',
      );
      if (!await file.exists()) return null;
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class PokepcUpdateResult {
  final String version;
  final int files;
  final int missingOptional;
  final int icons;
  final int missingIcons;
  final int pokemon;
  final int games;
  final int pokedexes;
  final String directory;
  final bool alreadyLatest;

  const PokepcUpdateResult({
    required this.version,
    required this.files,
    required this.missingOptional,
    required this.icons,
    required this.missingIcons,
    required this.pokemon,
    required this.games,
    required this.pokedexes,
    required this.directory,
    this.alreadyLatest = false,
  });
}
