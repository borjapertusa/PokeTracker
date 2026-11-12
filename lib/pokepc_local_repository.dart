import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'pokepc_dataset.dart';

/// Acceso de solo lectura a la copia portable del dataset PokéPC.
/// No realiza peticiones de red: todas las consultas se resuelven desde disco.
class PokepcLocalRepository {
  PokepcLocalRepository._();

  static Directory get root => PokepcDatasetUpdater.portableDataDirectory;

  // La carpeta del ejecutable no cambia: se calcula una sola vez (esto se
  // llama por cada sprite que se pinta).
  static final String _rootPath = root.path;

  /// Juegos (ids de versión, p. ej. `bw-b`) donde está disponible cada entrada,
  /// según los registros de PokéPC (obtainableIn + transferOnlyIn + eventOnlyIn).
  static final Map<String, Set<String>> availabilityByEntryId = {};

  static File file(String relativePath) => File(
        '$_rootPath${Platform.pathSeparator}${relativePath.replaceAll('/', Platform.pathSeparator)}',
      );

  static Future<bool> get isInstalled async {
    final metadata = await readMetadata();
    return metadata?['snapshotSchema'] == 3 &&
        await file('indices/pokemon.json').exists();
  }

  static Future<Map<String, dynamic>?> readMetadata() async {
    try {
      final f = file('metadata/local-install.json');
      if (!await f.exists()) return null;
      return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static Future<dynamic> readJson(String relativePath) async {
    final f = file(relativePath);
    if (!await f.exists()) {
      throw FileSystemException('No existe el archivo local', f.path);
    }
    return jsonDecode(await f.readAsString());
  }

  static Future<List<String>> readIndex(String kind) async {
    final value = await readJson('indices/$kind.json');
    if (value is! List || value.any((e) => e is! String)) {
      throw FormatException('El índice $kind no tiene un formato válido.');
    }
    return value.cast<String>();
  }

  static Future<Map<String, dynamic>> readPokemon(String id) async =>
      (await readJson('pokemon/$id.json')) as Map<String, dynamic>;

  /// Lee un catálogo (moves, abilities, items, …) unido a sus traducciones.
  /// Los campos de texto ES-ES prevalecen sobre los de inglés.
  static Future<List<Map<String, dynamic>>> loadTranslatedCollection(
    String kind,
  ) async {
    final raw = await readJson('$kind.json');
    if (raw is! List) {
      throw FormatException('El catálogo $kind no es una lista.');
    }
    final spanish = await readTextFile(kind);
    final english = await readTextFile(
      kind,
      locale: PokepcDatasetUpdater.englishLocale,
    );
    return raw.whereType<Map>().map((value) {
      final record = Map<String, dynamic>.from(value);
      final id = record['id']?.toString() ?? '';
      final es = spanish[id];
      final en = english[id];
      final translated = <String, dynamic>{};
      if (en is Map) translated.addAll(Map<String, dynamic>.from(en));
      if (es is Map) translated.addAll(Map<String, dynamic>.from(es));
      return <String, dynamic>{...record, ...translated};
    }).toList();
  }

  static Future<List<Map<String, dynamic>>> loadEntityRecords(String kind) async {
    final ids = await readIndex(kind);
    final records = <Map<String, dynamic>>[];
    for (final id in ids) {
      try {
        records.add((await readJson('$kind/$id.json')) as Map<String, dynamic>);
      } catch (_) {}
    }
    return records;
  }

  static Future<Map<String, dynamic>> readTextFile(
    String kind, {
    String locale = PokepcDatasetUpdater.spanishLocale,
  }) async {
    Map<String, dynamic> result;
    try {
      result = (await readJson('i18n/$locale/$kind.json')) as Map<String, dynamic>;
    } on FileSystemException {
      result = <String, dynamic>{};
    }
    // Las traducciones propias complementan a PokéPC sin modificar su copia.
    if (locale == PokepcDatasetUpdater.spanishLocale) {
      try {
        final overrides = (await readJson('overrides/i18n/$locale/$kind.json'))
            as Map<String, dynamic>;
        for (final entry in overrides.entries) {
          final current = result[entry.key];
          if (current is Map && entry.value is Map) {
            result[entry.key] = <String, dynamic>{
              ...Map<String, dynamic>.from(current),
              ...Map<String, dynamic>.from(entry.value as Map),
            };
          } else {
            result[entry.key] = entry.value;
          }
        }
      } on FileSystemException {
        // El overlay es opcional; se usa el texto publicado por PokéPC.
      }
    }
    return result;
  }

  /// Descripción de especie en español si existe una traducción propia;
  /// después intenta el texto de PokéPC y, por último, el original inglés.
  static Future<String?> readPokemonProse(String id) async {
    for (final path in [
      'overrides/i18n/es-es/pokemon-prose/$id.md',
      'i18n/es-es/pokemon-prose/$id.md',
      'i18n/eng/pokemon-prose/$id.md',
    ]) {
      try {
        final f = file(path);
        if (await f.exists()) return await f.readAsString();
      } catch (_) {}
    }
    return null;
  }

  /// Devuelve un campo traducido. Primero consulta ES-ES, después inglés y,
  /// como último recurso, el identificador legible.
  static String localizedValue(
    Map<String, dynamic> spanish,
    Map<String, dynamic> english,
    String id,
    String field,
  ) {
    final es = spanish[id];
    if (es is Map && es[field] is String && (es[field] as String).isNotEmpty) {
      return es[field] as String;
    }
    final en = english[id];
    if (en is Map && en[field] is String && (en[field] as String).isNotEmpty) {
      return en[field] as String;
    }
    return id.replaceAll('-', ' ');
  }

  /// Carga todas las especies y formas en el modelo que ya consume el tracker.
  /// Cada forma se mantiene asociada a su especie base mediante baseSpecies.
  /// [namesByDex] aporta el slug de PokéAPI por número nacional (el catálogo
  /// incluido): `name` debe seguir siendo ese slug porque la sección de
  /// movimientos consulta `pokeapi.co/api/v2/pokemon/<name>`.
  static Future<List<Species>> loadTrackerSpecies({
    Map<int, String> namesByDex = const {},
  }) async {
    final ids = await readIndex('pokemon');
    final spanish = await readTextFile('pokemon');
    final english = await readTextFile('pokemon', locale: PokepcDatasetUpdater.englishLocale);
    final records = <String, Map<String, dynamic>>{};

    // Los ficheros individuales son la fuente canónica de las formas y sus flags.
    for (final id in ids) {
      try {
        records[id] = await readPokemon(id);
      } catch (_) {
        // Un registro ausente no invalida el resto del catálogo; el validador
        // del instalador debe haber impedido publicar una descarga incompleta.
      }
    }

    final baseIdByDex = <int, String>{
      for (final record in records.values)
        if (record['isForm'] != true && record['dexNum'] is num)
          (record['dexNum'] as num).toInt(): record['id'].toString(),
    };
    final byBase = <String, List<Map<String, dynamic>>>{};
    for (final record in records.values) {
      final id = record['id']?.toString();
      if (id == null || id.isEmpty) continue;
      final explicitBase = record['baseSpecies'];
      final dex = (record['dexNum'] as num?)?.toInt();
      final inferredBase = record['isForm'] == true && dex != null
          ? baseIdByDex[dex]
          : null;
      final baseId = explicitBase is String && explicitBase.isNotEmpty
          ? _rootBase(explicitBase, records)
          : inferredBase ?? id;
      byBase.putIfAbsent(baseId, () => <Map<String, dynamic>>[]).add(record);
    }

    final output = <Species>[];
    for (final id in ids) {
      final base = records[id];
      if (base == null || base['isForm'] == true || base['baseSpecies'] is String) continue;
      final group = byBase[id] ?? [base];
      final declaredOrder = (base['forms'] as List? ?? const []).whereType<String>().toList();
      group.sort((a, b) {
        final aid = a['id'].toString();
        final bid = b['id'].toString();
        if (aid == id) {
          return -1;
        }
        if (bid == id) {
          return 1;
        }
        final ai = declaredOrder.indexOf(aid);
        final bi = declaredOrder.indexOf(bid);
        if (ai >= 0 && bi >= 0) return ai.compareTo(bi);
        if (ai >= 0) return -1;
        if (bi >= 0) return 1;
        return aid.compareTo(bid);
      });

      final entries = <Map<String, dynamic>>[];
      for (final record in group) {
        final formId = record['id'].toString();
        final esText = spanish[formId];
        final enText = english[formId];
        final esMap = esText is Map ? esText : const <String, dynamic>{};
        final enMap = enText is Map ? enText : const <String, dynamic>{};
        final formName = (esMap['formName'] as String?) ??
            (enMap['formName'] as String?) ??
            (formId == id ? 'Base' : _humanizeForm(formId, id));
        final refs = record['refs'];
        final slug = refs is Map ? refs['pkApiFormSlug']?.toString() : null;
        // El CDN de PokéPC nombra los iconos por `nid` (0003, 0003-f,
        // 0003-mega…), no por el identificador de PokéAPI.
        final nid = record['nid']?.toString();
        final validNid =
            nid != null && RegExp(r'^[0-9]{4}(-[a-z0-9-]+)?$').hasMatch(nid);
        final isFemale = record['isFemaleForm'] == true;
        final isCosmetic = record['isCosmeticForm'] == true;
        final kind = record['isMega'] == true
            ? 'mega'
            : record['isGmax'] == true
                ? 'gmax'
                : record['isRegional'] == true
                    ? 'regional'
                    : isCosmetic && isFemale
                        ? 'base'
                        : isCosmetic
                            ? 'cosmetic'
                            : record['isForm'] == true
                                ? 'other'
                                : 'base';
        final shinyAvailable = record['shinyReleased'] == true;
        final entryId = _legacyEntryId(formId, record, slug);
        final avail = <String>{};
        for (final k in const ['obtainableIn', 'transferOnlyIn', 'eventOnlyIn']) {
          final v = record[k];
          if (v is List) avail.addAll(v.whereType<String>());
        }
        if (avail.isNotEmpty) availabilityByEntryId[entryId] = avail;
        entries.add({
          'id': entryId,
          '_pc': formId,
          'label': formName,
          'kind': kind,
          'gender': isFemale && isCosmetic ? 'female' : 'none',
          'sprite': validNid ? 'pokepc:$nid' : null,
          'shiny': validNid && shinyAvailable ? 'pokepc-shiny:$nid' : null,
          'battleOnly': record['isBattleOnlyForm'] == true,
        });
      }

      // En una diferencia de género cosmética, la hembra es un registro `-f`
      // y su contraparte macho es el registro sin ese sufijo: se marca ♂ para
      // que la interfaz muestre la pareja igual que con el catálogo antiguo.
      for (final entry in entries) {
        if (entry['gender'] != 'female') continue;
        final pcId = entry['_pc'] as String;
        if (!pcId.endsWith('-f')) continue;
        final maleId = pcId.substring(0, pcId.length - 2);
        for (final other in entries) {
          if (other['_pc'] == maleId) other['gender'] = 'male';
        }
      }
      for (final entry in entries) {
        entry.remove('_pc');
      }

      final dex = (base['dexNum'] as num?)?.toInt();
      final gen = (base['gen'] as num?)?.toInt();
      if (dex == null || gen == null || entries.isEmpty) continue;
      final baseRefs = base['refs'];
      final baseSlug =
          baseRefs is Map ? baseRefs['pkApiFormSlug']?.toString() : null;
      // `name` sigue siendo el slug de PokéAPI: lo consumen la sección de
      // movimientos y la vista en inglés. `nameEs` es el nombre visible.
      final name = namesByDex[dex] ??
          (baseSlug != null && baseSlug.isNotEmpty ? baseSlug : id);
      final nameEs = _speciesDisplayName(spanish[id], english[id], name);
      output.add(Species.fromJson({
        'dex': dex,
        'gen': gen,
        'name': name,
        'nameEs': nameEs,
        'entries': entries,
      }));
    }
    output.sort((a, b) => a.dex.compareTo(b.dex));
    return output;
  }

  /// Excepciones puntuales donde el slug de PokéAPI no coincide con el ID
  /// histórico del tracker (validado contra el catálogo antiguo completo).
  static const Map<String, String> _legacyIdOverrides = {
    'gimmighoul': 'gimmighoul',
    'koraidon': 'koraidon',
    'miraidon': 'miraidon',
    'arceus-legendary': 'arceus-legendary',
    'floette-eternal': 'floette-eternal',
    'meowstic-mega': 'meowstic-male-mega',
    'tatsugiri-mega': 'tatsugiri-curly-mega',
    'greninja-ash': 'greninja-battle-bond',
    'frillish': 'frillish-male',
    'jellicent': 'jellicent-male',
    'pyroar': 'pyroar-male',
    'frillish-f': 'frillish-female',
    'jellicent-f': 'jellicent-female',
    'pyroar-f': 'pyroar-female',
  };

  /// Conserva los identificadores de entrada del catálogo antiguo para que
  /// games.json y el progreso guardado sigan emparejando tras la migración.
  /// La regla general es el slug de forma de PokéAPI; las hembras cosméticas
  /// usan el ID de PokéPC (venusaur-f, pikachu-f…), que ya era el ID antiguo.
  static String _legacyEntryId(
    String pcId,
    Map<String, dynamic> record,
    String? slug,
  ) {
    final override = _legacyIdOverrides[pcId];
    if (override != null) return override;
    if (record['isFemaleForm'] == true && record['isCosmeticForm'] == true) {
      return pcId;
    }
    return slug != null && slug.isNotEmpty ? slug : pcId;
  }

  /// Nombre visible de la especie: traducción propia/PokéPC en español,
  /// después inglés y como último recurso el slug legible. Elimina el
  /// calificador de forma entre paréntesis («Minior (Núcleo Rojo)»).
  static String _speciesDisplayName(dynamic es, dynamic en, String fallback) {
    String? pick(dynamic text) {
      if (text is! Map) return null;
      final species = text['speciesName'];
      if (species is String && species.trim().isNotEmpty) return species.trim();
      final name = text['name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
      return null;
    }

    final raw = pick(es) ?? pick(en);
    if (raw == null) {
      return fallback
          .split('-')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }
    final index = raw.lastIndexOf(' (');
    return index > 0 && raw.endsWith(')') ? raw.substring(0, index) : raw;
  }

  /// Algunas formas anidadas apuntan a otra forma (floette-eternal-mega →
  /// floette-eternal → floette). Se sigue la cadena hasta la especie raíz
  /// para que ninguna entrada quede fuera de su grupo.
  static String _rootBase(
      String id, Map<String, Map<String, dynamic>> records) {
    var current = id;
    final seen = <String>{};
    while (seen.add(current)) {
      final base = records[current]?['baseSpecies'];
      if (base is String && base.isNotEmpty && records.containsKey(base)) {
        current = base;
      } else {
        break;
      }
    }
    return current;
  }

  static String _humanizeForm(String id, String baseId) {
    final suffix = id.startsWith('$baseId-') ? id.substring(baseId.length + 1) : id;
    return suffix
        .split('-')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  static Future<PokepcLocalSummary> inspect() async {
    final metadata = await readMetadata();
    if (metadata == null) return const PokepcLocalSummary.notInstalled();
    var pokemon = 0;
    var homeIcons = 0;
    try {
      pokemon = (await readIndex('pokemon')).length;
    } catch (_) {}
    final iconsDir = Directory('${root.path}${Platform.pathSeparator}sprites${Platform.pathSeparator}home3d');
    if (await iconsDir.exists()) {
      await for (final entity in iconsDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.toLowerCase().endsWith('.webp')) {
          homeIcons++;
        }
      }
    }
    return PokepcLocalSummary(
      installed: true,
      version: metadata['version']?.toString(),
      pokemon: pokemon,
      games: (metadata['gameCount'] as num?)?.toInt() ?? 0,
      pokedexes: (metadata['pokedexCount'] as num?)?.toInt() ?? 0,
      homeIcons: homeIcons,
      downloadedAtUtc: metadata['downloadedAtUtc']?.toString(),
      directory: root.path,
    );
  }
}

class PokepcLocalSummary {
  final bool installed;
  final String? version;
  final int pokemon;
  final int games;
  final int pokedexes;
  final int homeIcons;
  final String? downloadedAtUtc;
  final String? directory;

  const PokepcLocalSummary({
    required this.installed,
    required this.version,
    required this.pokemon,
    required this.games,
    required this.pokedexes,
    required this.homeIcons,
    required this.downloadedAtUtc,
    required this.directory,
  });

  const PokepcLocalSummary.notInstalled()
      : installed = false,
        version = null,
        pokemon = 0,
        games = 0,
        pokedexes = 0,
        homeIcons = 0,
        downloadedAtUtc = null,
        directory = null;
}
