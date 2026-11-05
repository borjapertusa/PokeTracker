import 'dart:convert';
import 'dart:io';

/// Descarga los datos y los iconos de todos los objetos para uso offline.
/// Ejecutar desde la raíz del proyecto: dart run tool/download_items.dart
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  Future<Map<String, dynamic>> getJson(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode}: $url');
    }
    return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  Future<String?> saveSprite(Map<String, dynamic> item) async {
    final sprite = (item['sprites'] as Map?)?['default']?.toString();
    if (sprite == null || sprite.isEmpty) return null;
    final slug = (item['name'] ?? 'item').toString().replaceAll(RegExp(r'[^a-z0-9-]'), '-');
    final file = File('assets/items/$slug.png');
    try {
      final request = await client.getUrl(Uri.parse(sprite));
      final response = await request.close();
      if (response.statusCode != 200) return null;
      await file.parent.create(recursive: true);
      await response.pipe(file.openWrite());
      return 'assets/items/$slug.png';
    } catch (_) {
      return null;
    }
  }

  try {
    stdout.writeln('Obteniendo índice de objetos…');
    final index = await getJson('https://pokeapi.co/api/v2/item?limit=2000');
    final results = (index['results'] as List).cast<Map<String, dynamic>>();
    final items = <Map<String, dynamic>>[];
    var next = 0;
    var done = 0;
    var failed = 0;
    var icons = 0;

    Future<void> worker() async {
      while (true) {
        final i = next++;
        if (i >= results.length) return;
        try {
          final item = await getJson(results[i]['url'] as String);
          final localSprite = await saveSprite(item);
          if (localSprite != null) {
            item['localSprite'] = localSprite;
            icons++;
          }
          items.add(item);
        } catch (e) {
          failed++;
          stderr.writeln('No se pudo descargar ${results[i]['name']}: $e');
        }
        done++;
        if (done % 20 == 0 || done == results.length) {
          stdout.writeln('Descargados $done/${results.length} objetos · $icons iconos…');
        }
      }
    }

    await Future.wait(List.generate(8, (_) => worker()));
    items.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    final output = {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'source': 'PokéAPI v2',
      'items': items,
    };
    final file = File('assets/data/items.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(output));
    stdout.writeln('Guardados ${items.length} objetos y $icons iconos locales en assets/data/items.json. Fallidos: $failed.');
  } finally {
    client.close(force: true);
  }
}
