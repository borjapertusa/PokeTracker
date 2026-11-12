import 'dart:convert';
import 'dart:io';

/// Rellena las descripciones en español (ES-ES) de habilidades y movimientos
/// con las listas de WikiDex:
///   https://www.wikidex.net/wiki/Lista_de_habilidades
///   https://www.wikidex.net/wiki/Lista_de_movimientos
/// Escribe assets/data/descriptions_es.json (conserva lo que ya hubiera).
/// Ejecutar desde la raíz del proyecto: dart run tool/update_wikidex_descriptions.dart
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);

  Future<String> pageHtml(String page) async {
    final uri = Uri.https('www.wikidex.net', '/api.php', {
      'action': 'parse',
      'page': page,
      'prop': 'text',
      'format': 'json',
      'formatversion': '2',
    });
    final req = await client.getUrl(uri);
    req.headers.set(HttpHeaders.userAgentHeader, 'PokeTracker descriptions updater');
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}: $uri');
    final body = await res.transform(utf8.decoder).join();
    return (jsonDecode(body)['parse']['text']) as String;
  }

  String norm(String s) {
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const to = 'aaaaaeeeeiiiiooooouuuunc';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = from.indexOf(c);
      b.write(i >= 0 ? to[i] : c);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String clean(String html) {
    var t = html
        .replaceAll(RegExp(r'<sup[^>]*>.*?</sup>', dotAll: true), '')
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', dotAll: true), '')
        .replaceAll(RegExp(r'<br\s*/?>'), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    t = t
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAllMapped(RegExp(r'&#(\d+);'),
            (m) => String.fromCharCode(int.parse(m.group(1)!)));
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  List<List<String>> rawRows(String html) {
    final rows = <List<String>>[];
    for (final tr in RegExp(r'<tr[^>]*>(.*?)</tr>', dotAll: true).allMatches(html)) {
      final cells = RegExp(r'<t[dh][^>]*>(.*?)</t[dh]>', dotAll: true)
          .allMatches(tr.group(1)!)
          .map((m) => m.group(1)!)
          .toList();
      if (cells.isNotEmpty) rows.add(cells);
    }
    return rows;
  }

  // Catálogos locales: slug -> nombre en español.
  final details = jsonDecode(File('assets/data/details.json').readAsStringSync()) as Map;
  final abilityEs = (details['abilities'] as Map).cast<String, dynamic>();
  final moveEs = (jsonDecode(File('assets/data/move_names_es.json').readAsStringSync()) as Map)
      .cast<String, dynamic>();
  final abilityByEn = {for (final s in abilityEs.keys) norm(s): s};
  final moveByEn = {for (final s in moveEs.keys) norm(s): s};
  final moveByEs = {for (final e in moveEs.entries) norm(e.value.toString()): e.key};
  final abilityByEs = {for (final e in abilityEs.entries) norm(e.value.toString()): e.key};

  final outFile = File('assets/data/descriptions_es.json');
  final data = outFile.existsSync()
      ? (jsonDecode(outFile.readAsStringSync()) as Map).cast<String, dynamic>()
      : <String, dynamic>{};
  final abilities = ((data['abilities'] as Map?) ?? {}).cast<String, dynamic>();
  final moves = ((data['moves'] as Map?) ?? {}).cast<String, dynamic>();

  // ---- Habilidades: # | Nombre (ES) | Nombre (HA) | Inglés | Gen | Descripción
  stdout.writeln('Descargando Lista de habilidades…');
  final abHtml = await pageHtml('Lista_de_habilidades');
  var abOk = 0;
  final abMiss = <String>[];
  for (final cells in rawRows(abHtml)) {
    if (cells.length < 5) continue;
    final texts = cells.map(clean).toList();
    if (!RegExp(r'^-?\d{1,3}$').hasMatch(texts[0])) continue;
    final desc = texts.last;
    if (desc.length < 8) continue;
    final en = texts.length > 3 ? texts[3] : '';
    final esName = texts[1];
    var slug = abilityByEn[norm(en)] ??
        abilityByEn[norm(en.replaceAll(RegExp(r'\s*\(.*\)'), ''))] ??
        abilityByEs[norm(esName)];
    if (slug == null) {
      abMiss.add('$en / $esName');
      continue;
    }
    // Las variantes (p. ej. Evocarrecuerdos x4): vale la primera.
    if (abilities.containsKey(slug) && abilities[slug] == desc) continue;
    abilities[slug] = desc;
    abOk++;
  }
  stdout.writeln('  habilidades actualizadas: $abOk · sin casar: ${abMiss.length}');
  if (abMiss.isNotEmpty) stdout.writeln('  ${abMiss.join(' | ')}');

  // ---- Movimientos: # | Nombre (ES + inglés) | Gen | Descripción | Tipo | ...
  stdout.writeln('Descargando Lista de movimientos…');
  final mvHtml = await pageHtml('Lista_de_movimientos');
  var mvOk = 0;
  final mvMiss = <String>[];
  for (final cells in rawRows(mvHtml)) {
    if (cells.length < 4) continue;
    final texts = cells.map(clean).toList();
    if (!RegExp(r'^\d{4}$').hasMatch(texts[0])) continue;
    // La descripción es la celda de texto más larga de la fila.
    var desc = '';
    for (final t in texts.skip(1)) {
      if (t.length > desc.length) desc = t;
    }
    if (desc.length < 12) continue; // movimientos Z sin texto propio, etc.
    // Inglés: texto en cursiva de la celda del nombre; si no, nombres en español.
    final italic = RegExp(r'<(i|em)[^>]*>(.*?)</\1>', dotAll: true)
        .firstMatch(cells[1]);
    String? slug;
    if (italic != null) slug = moveByEn[norm(clean(italic.group(2)!))];
    if (slug == null) {
      for (final part in texts[1].split('/')) {
        slug = moveByEs[norm(part.replaceAll(RegExp(r'\d+'), ''))];
        if (slug != null) break;
      }
    }
    if (slug == null) {
      mvMiss.add(texts[1]);
      continue;
    }
    moves[slug] = desc;
    mvOk++;
  }
  stdout.writeln('  movimientos actualizados: $mvOk · sin casar: ${mvMiss.length}');
  if (mvMiss.isNotEmpty) {
    stdout.writeln('  (primeros) ${mvMiss.take(25).join(' | ')}');
  }

  data['about'] =
      'Descripciones en español (ES-ES) de WikiDex. Se rellena y amplía con: dart run tool/update_wikidex_descriptions.dart';
  data['source'] = 'https://www.wikidex.net/wiki/Lista_de_habilidades · https://www.wikidex.net/wiki/Lista_de_movimientos';
  data['abilities'] = abilities;
  data['moves'] = moves;
  outFile.writeAsStringSync(jsonEncode(data));
  stdout.writeln('Guardado ${outFile.path}: ${abilities.length} habilidades, ${moves.length} movimientos.');
  client.close(force: true);
}
