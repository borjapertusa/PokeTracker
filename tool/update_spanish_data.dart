import 'dart:convert';
import 'dart:io';

/// Completa los nombres ES-ES oficiales de Pokémon y habilidades en los datos
/// locales. Ejecutar desde la raíz: dart run tool/update_spanish_data.dart
/// Las claves internas (slugs) no se modifican para no romper referencias.
Future<void> main() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  Future<String> getText(String url) async {
    final req = await client.getUrl(Uri.parse(url));
    req.headers.set(HttpHeaders.userAgentHeader, 'PokeTracker localization updater');
    final res = await req.close();
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}: $url');
    return res.transform(utf8.decoder).join();
  }
  Future<Map<String, dynamic>> getJson(String url) async =>
      jsonDecode(await getText(url)) as Map<String, dynamic>;

  try {
    List<List<String>> csv(String source) {
      final rows = <List<String>>[];
      var row = <String>[];
      var cell = StringBuffer();
      var quoted = false;
      for (var i = 0; i < source.length; i++) {
        final c = source[i];
        if (quoted) {
          if (c == '"' && i + 1 < source.length && source[i + 1] == '"') {
            cell.write('"'); i++;
          } else if (c == '"') {
            quoted = false;
          } else {
            cell.write(c);
          }
        } else if (c == '"') {
          quoted = true;
        } else if (c == ',') {
          row.add(cell.toString()); cell = StringBuffer();
        } else if (c == '\n') {
          row.add(cell.toString()); cell = StringBuffer();
          if (row.any((v) => v.isNotEmpty)) rows.add(row);
          row = <String>[];
        } else if (c != '\r') {
          cell.write(c);
        }
      }
      row.add(cell.toString());
      if (row.any((v) => v.isNotEmpty)) rows.add(row);
      return rows;
    }

    const raw = 'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/';
    stdout.writeln('Descargando nombres oficiales en español…');
    final speciesRows = csv(await getText('${raw}pokemon_species_names.csv'));
    final speciesNames = <int, String>{};
    for (final r in speciesRows.skip(1)) {
      if (r.length >= 3 && r[1] == '7') {
        final id = int.tryParse(r[0]);
        if (id != null && r[2].trim().isNotEmpty) speciesNames[id] = r[2].trim();
      }
    }

    final dexFile = File('assets/data/pokedex.json');
    final dex = jsonDecode(await dexFile.readAsString()) as Map<String, dynamic>;
    final species = (dex['species'] as List).cast<Map<String, dynamic>>();
    var named = 0;
    for (final s in species) {
      final translated = speciesNames[s['dex'] as int];
      if (translated != null) { s['nameEs'] = translated; named++; }
    }
    await dexFile.writeAsString(const JsonEncoder.withIndent('  ').convert(dex));

    stdout.writeln('Descargando nombres oficiales de movimientos…');
    final moveRows = csv(await getText('${raw}move_names.csv'));
    final moveIdRows = csv(await getText('${raw}moves.csv'));
    final moveIdToSlug = <String, String>{};
    for (final r in moveIdRows.skip(1)) {
      if (r.length >= 2) moveIdToSlug[r[0]] = r[1];
    }
    final moveNames = <String, String>{};
    for (final r in moveRows.skip(1)) {
      if (r.length >= 3 && r[1] == '7' && r[2].trim().isNotEmpty) {
        final slug = moveIdToSlug[r[0]];
        if (slug != null) moveNames[slug] = r[2].trim();
      }
    }
    final moveNamesFile = File('assets/data/move_names_es.json');
    await moveNamesFile.writeAsString(const JsonEncoder.withIndent('  ').convert(moveNames));

    stdout.writeln('Descargando nombres de habilidades…');
    // El JSON de detalles usa slugs como claves; se cruza con el endpoint de
    // habilidad, que contiene el nombre español y el texto descriptivo local.
    final detailsFile = File('assets/data/details.json');
    final details = jsonDecode(await detailsFile.readAsString()) as Map<String, dynamic>;
    final abilities = (details['abilities'] as Map).cast<String, dynamic>();
    final effectsEs = <String, dynamic>{};
    var abilityCount = 0;
    var effectCount = 0;
    for (final slug in abilities.keys.toList()) {
      try {
        final a = await getJson('https://pokeapi.co/api/v2/ability/${Uri.encodeComponent(slug)}/');
        final names = (a['names'] as List? ?? const []).cast<Map>();
        final esName = names.where((n) => (n['language'] as Map?)?['name'] == 'es');
        if (esName.isNotEmpty) { abilities[slug] = esName.first['name']; abilityCount++; }
        final flavors = (a['flavor_text_entries'] as List? ?? const []).cast<Map>();
        final esText = flavors.where((e) => (e['language'] as Map?)?['name'] == 'es').toList();
        if (esText.isNotEmpty) {
          effectsEs[slug] = esText.last['flavor_text'].toString()
              .replaceAll(RegExp(r'[\n\r\f]+'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ').trim();
          effectCount++;
        }
      } catch (e) {
        stderr.writeln('Habilidad $slug: $e');
      }
    }
    details['abilityEffectsEs'] = effectsEs;
    await detailsFile.writeAsString(const JsonEncoder.withIndent('  ').convert(details));
    stdout.writeln('Pokémon: $named/${species.length} nombres ES; movimientos: ${moveNames.length}. Habilidades: $abilityCount nombres y $effectCount descripciones breves oficiales en español.');
    stdout.writeln('Los textos largos de efecto que PokéAPI no ofrece en español no se traducen automáticamente; se evita mostrar inglés como si fuese ES-ES.');
  } finally {
    client.close(force: true);
  }
}
