import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'details.dart';
import 'models.dart';
import 'settings.dart';
import 'widgets.dart';

/// Una fila de [PokemonTable]: número, nombre, sprite y columnas extra.
class PokemonRow {
  final int? no;
  final String name;
  final String? sprite;
  final List<String> cells;
  const PokemonRow({this.no, required this.name, this.sprite, this.cells = const []});
}

/// Tabla de Pokémon con cabecera, filas alternas, buscador (si hay muchas filas)
/// y «Mostrar todos» para no construir cientos de filas de golpe.
class PokemonTable extends StatefulWidget {
  final List<PokemonRow> rows;
  final List<String> extraHeaders;
  final List<double> extraFlex;
  final AppSettings? settings;
  final int initialRows;
  const PokemonTable({
    super.key,
    required this.rows,
    this.extraHeaders = const [],
    this.extraFlex = const [],
    this.settings,
    this.initialRows = 40,
  });

  @override
  State<PokemonTable> createState() => _PokemonTableState();
}

class _PokemonTableState extends State<PokemonTable> {
  bool _all = false;
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final q = _q.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.rows
        : widget.rows
            .where((r) =>
                r.name.toLowerCase().contains(q) ||
                '${r.no ?? ''}' == q ||
                r.cells.any((c) => c.toLowerCase().contains(q)))
            .toList();
    final shown = (_all || q.isNotEmpty)
        ? filtered
        : filtered.take(widget.initialRows).toList();
    final showSprites = widget.settings != null;
    final headerStyle = t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);

    TableRow header() => TableRow(
          decoration: BoxDecoration(color: t.colorScheme.surfaceContainerHighest),
          children: [
            _cell(Text('Nº', style: headerStyle)),
            _cell(Text('Pokémon', style: headerStyle)),
            for (final h in widget.extraHeaders) _cell(Text(h, style: headerStyle)),
          ],
        );

    TableRow row(int i, PokemonRow r) => TableRow(
          decoration: BoxDecoration(
            color: i.isOdd ? t.colorScheme.surfaceContainerLow : null,
          ),
          children: [
            _cell(Row(mainAxisSize: MainAxisSize.min, children: [
              if (showSprites)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: t.colorScheme.surfaceContainerHighest,
                    child: ClipOval(
                      child: Sprite(r.sprite,
                          size: 34,
                          pixel: widget.settings!.pixelSprites,
                          threeD: widget.settings!.threeDSprites),
                    ),
                  ),
                ),
              Text(r.no == null ? '—' : '#${r.no.toString().padLeft(4, '0')}',
                  style: t.textTheme.bodySmall),
            ])),
            _cell(Text(r.name,
                style: t.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
            for (var c = 0; c < widget.extraHeaders.length; c++)
              _cell(Text(c < r.cells.length ? r.cells[c] : '—',
                  style: t.textTheme.bodySmall)),
          ],
        );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.rows.length > 25)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Filtrar la tabla',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _q = v),
              ),
            ),
          Table(
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              0: FixedColumnWidth(showSprites ? 124 : 72),
              1: const FlexColumnWidth(2.2),
              for (var c = 0; c < widget.extraHeaders.length; c++)
                2 + c: FlexColumnWidth(
                    c < widget.extraFlex.length ? widget.extraFlex[c] : 1.4),
            },
            children: [
              header(),
              for (var i = 0; i < shown.length; i++) row(i, shown[i]),
            ],
          ),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(14),
              child: Text('No hay Pokémon que coincidan.'),
            ),
          if (!_all && q.isEmpty && filtered.length > shown.length)
            TextButton.icon(
              onPressed: () => setState(() => _all = true),
              icon: const Icon(Icons.expand_more),
              label: Text('Mostrar todos (${filtered.length})'),
            ),
        ],
      ),
    );
  }

  Widget _cell(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: child,
      );
}

/// Localiza un Pokémon de PokéAPI (p. ej. `raichu-alola`) en el catálogo:
/// devuelve la especie y el nombre de su forma (vacío si es la forma base).
({GameSpecies? gs, String form}) _resolvePokemon(String apiName) {
  final home = kHomeGame;
  if (home == null) return (gs: null, form: '');
  _byName ??= {for (final gs in home.species) gs.species.name: gs};
  final parts = apiName.split('-');
  for (var n = parts.length; n >= 1; n--) {
    final gs = _byName![parts.take(n).join('-')];
    if (gs != null) {
      return (gs: gs, form: n == parts.length ? '' : localizedFormName(apiName));
    }
  }
  return (gs: null, form: '');
}

Map<String, GameSpecies>? _byName;
final Map<String, Future<List<PokemonRow>>> _learnersCache = {};

/// Pokémon que aprenden un movimiento (PokéAPI: `learned_by_pokemon`), ya en
/// forma de filas de tabla. Se guarda en memoria durante la sesión.
Future<List<PokemonRow>> loadMoveLearners(String slug, bool spanish) =>
    _learnersCache.putIfAbsent(slug, () async {
      final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      try {
        final r = await c.getUrl(Uri.parse('https://pokeapi.co/api/v2/move/$slug'));
        final s = await r.close();
        if (s.statusCode != 200) throw HttpException('HTTP ${s.statusCode}');
        final data = jsonDecode(await s.transform(utf8.decoder).join()) as Map<String, dynamic>;
        return learnersToRows((data['learned_by_pokemon'] as List? ?? const []), spanish);
      } finally {
        c.close(force: true);
      }
    });

/// Convierte la lista `learned_by_pokemon` de PokéAPI en filas de tabla.
List<PokemonRow> learnersToRows(List learned, bool spanish) {
  final rows = <PokemonRow>[];
  for (final p in learned) {
    final apiName = (p as Map)['name'].toString();
    final res = _resolvePokemon(apiName);
    final gs = res.gs;
    final base = gs?.species.displayName(spanish) ??
        apiName.split('-').map((x) => x.isEmpty ? x : '${x[0].toUpperCase()}${x.substring(1)}').join(' ');
    rows.add(PokemonRow(
      no: gs?.species.dex,
      name: res.form.isEmpty ? base : '$base (${res.form})',
      sprite: gs?.entries.first.sprite,
      cells: [res.form.isEmpty ? 'Base' : res.form],
    ));
  }
  rows.sort((a, b) {
    final c = (a.no ?? 1 << 20).compareTo(b.no ?? 1 << 20);
    return c != 0 ? c : a.name.compareTo(b.name);
  });
  return rows;
}
