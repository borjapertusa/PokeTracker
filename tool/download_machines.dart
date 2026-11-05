import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Descarga el catálogo de máquinas desde el endpoint /machine de PokéAPI.
/// PokéAPI no ofrece una categoría de objeto llamada "machines"; las máquinas
/// se publican como recursos propios y cada una enlaza el objeto, movimiento
/// y grupo de versiones correspondiente.
/// Ejecutar desde la raíz del proyecto:
///   dart run tool/download_machines.dart
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);

  Future<Map<String, dynamic>> getJson(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'PokeTracker offline machine downloader');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('HTTP ${response.statusCode}: $url');
    }
    return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  String localizedName(Map<String, dynamic> data, String language, String fallback) {
    final names = (data['names'] as List? ?? const []).cast<Map>();
    for (final entry in names) {
      if ((entry['language'] as Map?)?['name'] == language) {
        return entry['name'].toString();
      }
    }
    return fallback;
  }

  String localizedEffect(Map<String, dynamic> data) {
    final entries = (data['effect_entries'] as List? ?? const []).cast<Map>();
    for (final entry in entries) {
      if ((entry['language'] as Map?)?['name'] == 'es') {
        return entry['short_effect'].toString();
      }
    }
    for (final entry in entries) {
      if ((entry['language'] as Map?)?['name'] == 'en') {
        return entry['short_effect'].toString();
      }
    }
    return 'Descripción no disponible en PokéAPI.';
  }

  try {
    stdout.writeln('Consultando el catálogo de máquinas de PokéAPI…');

    // /item-category/machines/ no existe en PokéAPI. El endpoint correcto es
    // /machine/, que devuelve recursos con item, move y version_group.
    final machineRefs = <Map<String, dynamic>>[];
    String? pageUrl = 'https://pokeapi.co/api/v2/machine/?limit=1000';
    while (pageUrl != null) {
      final page = await getJson(pageUrl);
      machineRefs.addAll((page['results'] as List? ?? const []).cast<Map<String, dynamic>>());
      pageUrl = page['next']?.toString();
    }

    final rows = <Map<String, dynamic>>[];
    var next = 0;
    var done = 0;
    var failedMachines = 0;

    Future<void> machineWorker() async {
      while (true) {
        final index = next++;
        if (index >= machineRefs.length) return;
        final ref = machineRefs[index];
        try {
          final machine = await getJson(ref['url'] as String);
          final item = machine['item'] as Map<String, dynamic>;
          final slug = item['name'].toString();
          final match = RegExp(r'^(tm|hm|tr)(\d+)$').firstMatch(slug);
          if (match != null) {
            final prefix = match.group(1)!;
            rows.add({
              'machineId': machine['id'],
              'item': slug,
              'itemUrl': item['url'],
              'move': (machine['move'] as Map<String, dynamic>)['name'],
              'moveUrl': (machine['move'] as Map<String, dynamic>)['url'],
              'number': int.parse(match.group(2)!),
              'kind': prefix == 'tm' ? 'MT' : prefix == 'hm' ? 'MO' : 'DT',
              'group': (machine['version_group'] as Map<String, dynamic>)['name'],
            });
          }
        } catch (error) {
          failedMachines++;
          stderr.writeln('No se pudo descargar ${ref['url']}: $error');
        }
        done++;
        if (done % 50 == 0 || done == machineRefs.length) {
          stdout.writeln('Máquinas consultadas: $done/${machineRefs.length}…');
        }
      }
    }

    await Future.wait(List.generate(8, (_) => machineWorker()));
    rows.sort((a, b) {
      final group = (a['group'] as String).compareTo(b['group'] as String);
      if (group != 0) return group;
      final kind = ['MT', 'MO', 'DT'].indexOf(a['kind'] as String)
          .compareTo(['MT', 'MO', 'DT'].indexOf(b['kind'] as String));
      if (kind != 0) return kind;
      final number = (a['number'] as int).compareTo(b['number'] as int);
      if (number != 0) return number;
      return (a['machineId'] as int).compareTo(b['machineId'] as int);
    });

    final uniqueMoves = <String, String>{};
    for (final row in rows) {
      uniqueMoves[row['move'] as String] = row['moveUrl'] as String;
    }
    stdout.writeln('Descargando datos de ${uniqueMoves.length} movimientos…');
    final moveInfo = <String, Map<String, dynamic>>{};
    final moveEntries = uniqueMoves.entries.toList();
    next = 0;
    done = 0;
    var failedMoves = 0;

    Future<void> moveWorker() async {
      while (true) {
        final index = next++;
        if (index >= moveEntries.length) return;
        final entry = moveEntries[index];
        try {
          final move = await getJson(entry.value);
          final type = move['type'] as Map<String, dynamic>;
          final damageClass = move['damage_class'] as Map<String, dynamic>;
          moveInfo[entry.key] = {
            'nameEs': localizedName(move, 'es', entry.key.replaceAll('-', ' ')),
            'nameEn': localizedName(move, 'en', entry.key.replaceAll('-', ' ')),
            'typeEs': localizedName(type, 'es', (type['name'] ?? '').toString()),
            'typeEn': localizedName(type, 'en', (type['name'] ?? '').toString()),
            'categoryEs': localizedName(damageClass, 'es', (damageClass['name'] ?? '').toString()),
            'categoryEn': localizedName(damageClass, 'en', (damageClass['name'] ?? '').toString()),
            'effect': localizedEffect(move),
            'power': move['power'],
            'accuracy': move['accuracy'],
            'pp': move['pp'],
          };
        } catch (error) {
          failedMoves++;
          stderr.writeln('No se pudo descargar el movimiento ${entry.key}: $error');
        }
        done++;
        if (done % 25 == 0 || done == moveEntries.length) {
          stdout.writeln('Movimientos descargados: $done/${moveEntries.length}…');
        }
      }
    }

    await Future.wait(List.generate(8, (_) => moveWorker()));
    final output = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'PokéAPI v2 /machine',
      'machineCount': rows.length,
      'moveCount': moveInfo.length,
      'machines': rows,
      'moves': moveInfo,
    };
    final file = File('assets/data/machines.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(output));
    stdout.writeln('');
    stdout.writeln('Terminado: ${rows.length} registros de máquinas y ${moveInfo.length} movimientos guardados en ${file.path}.');
    stdout.writeln('Fallos: $failedMachines máquinas y $failedMoves movimientos.');
    stdout.writeln('La aplicación podrá leer este catálogo localmente, sin conexión.');
  } finally {
    client.close(force: true);
  }
}
