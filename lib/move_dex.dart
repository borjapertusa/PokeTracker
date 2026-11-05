import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

/// Consulta los métodos de aprendizaje por grupo de juegos en PokéAPI.
/// Los resultados se mantienen en memoria durante la sesión.
class PokemonMovesSection extends StatefulWidget {
  final String pokemon;
  final bool spanish;
  const PokemonMovesSection({super.key, required this.pokemon, required this.spanish});

  @override
  State<PokemonMovesSection> createState() => _PokemonMovesSectionState();
}

class _PokemonMovesSectionState extends State<PokemonMovesSection> {
  static final Map<String, Future<List<_MoveRecord>>> _cache = {};
  late Future<List<_MoveRecord>> _future;
  String? _versionGroup;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant PokemonMovesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pokemon != widget.pokemon || oldWidget.spanish != widget.spanish) {
      _future = _load();
      _versionGroup = null;
    }
  }

  Future<List<_MoveRecord>> _load() => _cache.putIfAbsent(
      '${widget.pokemon}:${widget.spanish}', () => _fetchMoves(widget.pokemon, widget.spanish));

  @override
  Widget build(BuildContext context) => FutureBuilder<List<_MoveRecord>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('No se han podido cargar los movimientos. Comprueba la conexión a Internet e inténtalo de nuevo.'),
            Align(alignment: Alignment.centerRight, child: TextButton.icon(
              onPressed: () => setState(() { _cache.remove(widget.pokemon); _future = _load(); }),
              icon: const Icon(Icons.refresh), label: const Text('Reintentar'))),
          ])));
      }
      final records = snapshot.data ?? const <_MoveRecord>[];
      final groups = records.expand((r) => r.byGroup.keys).toSet().toList()
        ..sort((a,b) => (_groupOrder[a] ?? 999).compareTo(_groupOrder[b] ?? 999));
      if (groups.isEmpty) return _empty(context);
      final selected = groups.contains(_versionGroup) ? _versionGroup! : groups.first;
      final selectedMoves = <String, List<_MoveForGame>>{
        'level-up': [], 'machine': [], 'tutor': [], 'egg': [],
      };
      for (final r in records) {
        final data = r.byGroup[selected];
        if (data != null && selectedMoves.containsKey(data.method)) {
          selectedMoves[data.method]!.add(_MoveForGame(r.name, data.level, data.machine));
        }
      }
      for (final rows in selectedMoves.values) {
        rows.sort((a,b) => a.level != b.level ? a.level.compareTo(b.level) : a.name.compareTo(b.name));
      }
      return Padding(padding: const EdgeInsets.only(top: 20), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: selected,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Grupo de juegos', border: OutlineInputBorder(), isDense: true),
            items: [for (final g in groups) DropdownMenuItem(value: g, child: Text(_groupNames[g] ?? _pretty(g)))],
            onChanged: (v) => setState(() => _versionGroup = v),
          ),
          const SizedBox(height: 8),
          _moveTable(context, 'Por nivel', selectedMoves['level-up']!, 'Nivel'),
          _moveTable(context, 'MT / MO / DT', selectedMoves['machine']!, 'MT / MO / DT'),
          _moveTable(context, 'Por tutor', selectedMoves['tutor']!, 'Método'),
          _moveTable(context, 'Movimientos huevo', selectedMoves['egg']!, 'Método'),
          const SizedBox(height: 6),
          Text('Datos de PokéAPI. La disponibilidad y los métodos pueden variar entre grupos de versiones.',
            style: Theme.of(context).textTheme.bodySmall),
        ],
      ));
    },
  );

  Widget _empty(BuildContext context) => Padding(padding: const EdgeInsets.only(top:20), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Movimientos', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8), const Text('No hay datos de aprendizaje disponibles para este Pokémon.'),
    ]));

  Widget _moveTable(BuildContext context, String title, List<_MoveForGame> rows, String secondColumn) {
    return Card(margin: const EdgeInsets.symmetric(vertical: 5), child: ExpansionTile(
      initiallyExpanded: title == 'Por nivel',
      title: Text('$title (${rows.length})'),
      children: rows.isEmpty
        ? [const Padding(padding: EdgeInsets.all(12), child: Align(alignment: Alignment.centerLeft, child: Text('No aprende movimientos por este método en este grupo.')))]
        : [
          Padding(padding: const EdgeInsets.fromLTRB(16,0,16,12), child: Table(
            columnWidths: const {0: FlexColumnWidth(3), 1: FlexColumnWidth(1.4)},
            children: [
              TableRow(decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest), children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('Movimiento', style: Theme.of(context).textTheme.labelMedium)),
                Padding(padding: const EdgeInsets.all(8), child: Text(secondColumn, style: Theme.of(context).textTheme.labelMedium)),
              ]),
              for (final row in rows) TableRow(children: [
                Padding(padding: const EdgeInsets.all(8), child: Text(row.name)),
                Padding(padding: const EdgeInsets.all(8), child: Text(switch (title) { 'Por nivel' => row.level == 0 ? '—' : 'Nv. ${row.level}', 'MT / MO / DT' => row.machine ?? 'MT/MO/DT', 'Por tutor' => 'Tutor', _ => 'Huevo' })),
              ]),
            ],
          )),
        ],
    ));
  }
}

class _MoveRecord {
  final String name;
  final Map<String, _MoveGameData> byGroup;
  _MoveRecord(this.name, this.byGroup);
}
class _MoveGameData {
  final String method;
  final int level;
  final String? machine;
  _MoveGameData(this.method, this.level, this.machine);
}
class _MoveForGame {
  final String name;
  final int level;
  final String? machine;
  _MoveForGame(this.name, this.level, this.machine);
}

Future<List<_MoveRecord>> _fetchMoves(String pokemon, bool spanish) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  Future<Map<String, dynamic>> getJson(String url) async {
    final request = await client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != 200) throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
    return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }
  try {
    final raw = await getJson('https://pokeapi.co/api/v2/pokemon/${Uri.encodeComponent(pokemon.toLowerCase())}/');
    final moves = raw['moves'] as List? ?? const [];
    final out = <_MoveRecord>[];
    final machineCache = <String, Future<String?>>{};
    for (final item in moves) {
      final m = item as Map<String, dynamic>;
      final url = (m['move'] as Map<String, dynamic>)['url'] as String;
      final details = m['version_group_details'] as List? ?? const [];
      final byGroup = <String, _MoveGameData>{};
      for (final detail in details) {
        final d = detail as Map<String, dynamic>;
        final method = ((d['move_learn_method'] as Map<String, dynamic>)['name'] as String);
        final group = ((d['version_group'] as Map<String, dynamic>)['name'] as String);
        if (!{'level-up','machine','tutor','egg'}.contains(method)) continue;
        byGroup[group] = _MoveGameData(method, (d['level_learned_at'] as int?) ?? 0, null);
      }
      if (byGroup.isEmpty) continue;
      var moveName = _pretty((m['move'] as Map<String, dynamic>)['name'] as String);
      // Se consulta el nombre localizado solo para movimientos realmente aprendibles.
      try {
        final moveRaw = await getJson(url);
        final names = moveRaw['names'] as List? ?? const [];
        final localized = names.cast<Map<String,dynamic>>().where((n) =>
          ((n['language'] as Map<String,dynamic>)['name'] as String?) == (spanish ? 'es' : 'en')).toList();
        if (localized.isNotEmpty) moveName = localized.first['name'] as String;
        final machines = moveRaw['machines'] as List? ?? const [];
        for (final machine in machines) {
          final machineData = machine as Map<String,dynamic>;
          final group = ((machineData['version_group'] as Map<String,dynamic>)['name'] as String);
          if (byGroup[group]?.method != 'machine') continue;
          final machineUrl = (machineData['machine'] as Map<String,dynamic>)['url'] as String;
          final label = await machineCache.putIfAbsent(machineUrl, () async {
            try {
              final machineRaw = await getJson(machineUrl);
              final itemName = ((machineRaw['item'] as Map<String,dynamic>)['name'] as String);
              final match = RegExp(r'^(tm|hm|tr)(\d+)$').firstMatch(itemName);
              if (match == null) return _pretty(itemName);
              final prefix = switch (match.group(1)) { 'tm' => 'MT', 'hm' => 'MO', _ => 'DT' };
              return '$prefix${match.group(2)}';
            } catch (_) { return null; }
          });
          byGroup[group] = _MoveGameData('machine', 0, label);
        }
      } catch (_) {}
      out.add(_MoveRecord(moveName, byGroup));
    }
    return out;
  } finally {
    client.close(force: true);
  }
}

const Map<String,int> _groupOrder = {
  'red-blue':1,'yellow':2,'gold-silver':3,'crystal':4,'ruby-sapphire':5,'emerald':6,
  'firered-leafgreen':7,'diamond-pearl':8,'platinum':9,'heartgold-soulsilver':10,
  'black-white':11,'black-2-white-2':12,'x-y':13,'omega-ruby-alpha-sapphire':14,
  'sun-moon':15,'ultra-sun-ultra-moon':16,'lets-go-pikachu-lets-go-eevee':17,
  'sword-shield':18,'brilliant-diamond-shining-pearl':19,'legends-arceus':20,'scarlet-violet':21,
};
const Map<String,String> _groupNames = {
  'red-blue':'Rojo / Azul','yellow':'Amarillo','gold-silver':'Oro / Plata','crystal':'Cristal',
  'ruby-sapphire':'Rubí / Zafiro','emerald':'Esmeralda','firered-leafgreen':'Rojo Fuego / Verde Hoja',
  'diamond-pearl':'Diamante / Perla','platinum':'Platino','heartgold-soulsilver':'Oro HeartGold / Plata SoulSilver',
  'black-white':'Negro / Blanco','black-2-white-2':'Negro 2 / Blanco 2','x-y':'X / Y',
  'omega-ruby-alpha-sapphire':'Rubí Omega / Zafiro Alfa','sun-moon':'Sol / Luna',
  'ultra-sun-ultra-moon':'Ultrasol / Ultraluna','lets-go-pikachu-lets-go-eevee':'Let’s Go Pikachu / Eevee',
  'sword-shield':'Espada / Escudo','brilliant-diamond-shining-pearl':'Diamante Brillante / Perla Reluciente',
  'legends-arceus':'Leyendas Pokémon: Arceus','scarlet-violet':'Escarlata / Púrpura',
};
String _pretty(String value) => value.split('-').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
