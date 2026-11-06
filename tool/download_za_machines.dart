import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Descarga el catálogo ES-ES de las 160 MT de Leyendas Pokémon: Z-A
/// (107 del juego base + 53 de Megadimensión) desde Pokémon Project.
/// Ejecutar: dart run tool/download_za_machines.dart
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 30);
  try {
    final request = await client.getUrl(Uri.parse('https://pkproject.net/leyendas-pokemon-z-a/lista-de-mt'));
    request.headers.set(HttpHeaders.userAgentHeader, 'PokeTracker MT downloader');
    final response = await request.close();
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode} al consultar la lista de MT');
    final html = await response.transform(utf8.decoder).join();
    final rows = <Map<String, dynamic>>[];
    String clean(String value) => value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ').replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'").replaceAll('&quot;', '"')
        .replaceAll(RegExp(r'\s+'), ' ').trim();
    final tr = RegExp(r'<tr\b[^>]*>(.*?)</tr>', caseSensitive: false, dotAll: true);
    final td = RegExp(r'<t[dh]\b[^>]*>(.*?)</t[dh]>', caseSensitive: false, dotAll: true);
    for (final row in tr.allMatches(html)) {
      final cells = td.allMatches(row.group(1)!).map((m) => clean(m.group(1)!)).toList();
      if (cells.length < 6) continue;
      final numberMatch = RegExp(r'(?:MT|TM)\s*0*(\d{1,3})', caseSensitive: false).firstMatch(cells.join(' '));
      if (numberMatch == null) continue;
      final number = int.parse(numberMatch.group(1)!);
      if (number < 1 || number > 160 || rows.any((r) => r['number'] == number)) continue;
      final name = cells.firstWhere((c) => c.isNotEmpty && !RegExp(r'^(MT|TM)\d+$', caseSensitive: false).hasMatch(c), orElse: () => '');
      // En la tabla de Pokémon Project, el nombre aparece en la segunda celda.
      final move = cells.length > 1 ? cells[1] : name;
      if (move.isEmpty) continue;
      final type = cells.length > 2 ? cells[2] : '—';
      final category = cells.length > 3 ? cells[3] : '—';
      int? numeric(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
      rows.add({'number': number, 'move': move, 'nameEs': move, 'typeEs': type,
        'categoryEs': category, 'power': numeric(cells.length > 4 ? cells[4] : ''),
        'accuracy': null, 'pp': null,
        'effectEs': 'MT de Leyendas Pokémon: Z-A. Consulta el efecto detallado en la ficha del movimiento o dentro del juego.'});
    }
    rows.sort((a, b) => (a['number'] as int).compareTo(b['number'] as int));
    if (rows.length != 160) {
      throw StateError('Se esperaban 160 MT y la página proporcionó ${rows.length}. No se ha sobrescrito el archivo.');
    }
    final file = File('assets/data/za_machines.json');
    await file.parent.create(recursive: true);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert({
      'source': 'Pokémon Project · Lista de MT de Leyendas Pokémon: Z-A',
      'count': rows.length, 'baseGame': 107, 'dlcMegaDimension': 53, 'machines': rows,
    }));
    stdout.writeln('Descargadas ${rows.length} MT de Z-A (107 base + 53 Megadimensión) en ${file.path}.');
  } finally { client.close(force: true); }
}
