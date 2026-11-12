import 'dart:convert';
import 'dart:io';

/// Descarga los iconos HOME 3D de PokéPC usando el `nid` de cada registro
/// (0003, 0003-f, 0003-mega…), que es como los nombra el CDN. Los identificadores
/// numéricos de PokéAPI devuelven 404 para formas, hembras y variocolor.
/// Ejecutar desde la raíz: dart run tool/download_pokepc_icons.dart
const _datasetBase = 'https://pokepc.github.io/dataset/v8/';
const _iconBase = 'https://static.pokepc.net/images/pokemon/home3d-icon-xl';

Future<void> main() async {
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 25)
    ..idleTimeout = const Duration(seconds: 25)
    ..userAgent = 'PokeTracker offline asset downloader';

  Future<dynamic> getJson(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    }
    final text = await response.transform(utf8.decoder).join();
    return jsonDecode(text);
  }

  // nid -> shiny disponible (varios registros pueden compartir nid).
  final nids = <String, bool>{};
  try {
    final ids = (await getJson('${_datasetBase}indices/pokemon.json') as List)
        .cast<String>();
    var read = 0;
    for (final id in ids) {
      try {
        final record =
            await getJson('${_datasetBase}pokemon/$id.json') as Map<String, dynamic>;
        final nid = record['nid']?.toString();
        if (nid != null && RegExp(r'^[0-9]{4}(-[a-z0-9-]+)?$').hasMatch(nid)) {
          nids[nid] = nids[nid] == true || record['shinyReleased'] == true;
        }
      } catch (_) {}
      read++;
      if (read % 100 == 0) {
        stdout.write('\rRegistros leídos: $read/${ids.length}');
      }
    }
    stdout.writeln('\nNids únicos: ${nids.length}');
  } catch (error) {
    stderr.writeln('No se pudo leer el índice de PokéPC: $error');
    client.close(force: true);
    exitCode = 1;
    return;
  }

  final tasks = <(String, String)>[];
  for (final entry in nids.entries) {
    tasks.add(('regular/${entry.key}.webp', 'regular/${entry.key}.webp'));
    if (entry.value) tasks.add(('shiny/${entry.key}.webp', 'shiny/${entry.key}.webp'));
  }

  final dir = Directory('assets/sprites3d');
  await dir.create(recursive: true);
  var ok = 0, missing = 0, done = 0;
  final queue = List<(String, String)>.from(tasks);

  Future<void> worker() async {
    while (queue.isNotEmpty) {
      final (remote, relative) = queue.removeAt(0);
      final file = File('${dir.path}/$relative');
      if (await file.exists() && await file.length() > 0) {
        ok++;
        done++;
        continue;
      }
      try {
        final request = await client.getUrl(Uri.parse('$_iconBase/$remote'));
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          await response.drain<void>();
          missing++;
        } else {
          final bytes =
              await response.fold<List<int>>(<int>[], (a, b) => a..addAll(b));
          final validWebp = bytes.length >= 12 &&
              ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
              ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
          if (validWebp) {
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes, flush: true);
            ok++;
          } else {
            missing++;
          }
        }
      } catch (_) {
        missing++;
      }
      done++;
      if (done % 25 == 0 || done == tasks.length) {
        stdout.write('\rIconos: $ok | no disponibles: $missing | $done/${tasks.length}');
      }
    }
  }

  try {
    await Future.wait([for (var i = 0; i < 4; i++) worker()]);
  } finally {
    client.close(force: true);
  }
  stdout.writeln('\nFinalizado. Iconos guardados en assets/sprites3d/{regular,shiny}/.');
  stdout.writeln('Descargados/existentes: $ok; no disponibles: $missing.');
}