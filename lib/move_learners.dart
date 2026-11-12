import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/material.dart';

import 'details.dart';
import 'models.dart';
import 'pokemon_table.dart';
import 'pokepc_local_repository.dart';
import 'settings.dart';

dynamic _decodeJson(String raw) => jsonDecode(raw);

/// Datos de aprendizaje de Pokémon Showdown (learnsets + pokédex). Se descargan
/// la primera vez y se guardan en `data/sprite-cache/showdown-data`; para
/// refrescarlos, borra esa carpeta.
class LearnsetStore {
  LearnsetStore._();

  static const _base = 'https://play.pokemonshowdown.com/data/';
  static Future<LearnsetStore>? _loading;

  late Map<String, dynamic> _learnsets;
  late Map<String, dynamic> _dex;

  static Future<LearnsetStore> load() => _loading ??= _doLoad().catchError((e) {
        _loading = null; // permite reintentar
        throw e;
      });

  static File _file(String name) {
    final dir = PokepcLocalRepository.root.parent.path;
    final sep = Platform.pathSeparator;
    return File('$dir${sep}sprite-cache${sep}showdown-data$sep$name');
  }

  static Future<String> _text(String name) async {
    final f = _file(name);
    try {
      if (await f.exists() && await f.length() > 1000) return await f.readAsString();
    } catch (_) {}
    if (AppSettings.current?.offlineMode == true) {
      throw const HttpException('Modo sin conexión: faltan datos de aprendizaje.');
    }
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(Uri.parse('$_base$name'));
      final res = await req.close().timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}: $name');
      final body = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 90));
      try {
        await f.parent.create(recursive: true);
        await f.writeAsString(body, flush: true);
      } catch (_) {}
      return body;
    } finally {
      client.close(force: true);
    }
  }

  static Future<LearnsetStore> _doLoad() async {
    final results = await Future.wait([_text('learnsets.json'), _text('pokedex.json')]);
    final decoded = await Future.wait([
      compute(_decodeJson, results[0]),
      compute(_decodeJson, results[1]),
    ]);
    final s = LearnsetStore._();
    s._learnsets = (decoded[0] as Map).cast<String, dynamic>();
    s._dex = (decoded[1] as Map).cast<String, dynamic>();
    return s;
  }

  // ---------- consultas ----------

  static String moveId(String slug) => slug.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  Map? _entry(String id) => _dex[id] as Map?;

  List<String> _eggGroups(String id) =>
      ((_entry(id)?['eggGroups'] as List?) ?? const []).map((e) => e.toString()).toList();

  bool _canBeFather(String id) {
    final d = _entry(id);
    if (d == null) return false;
    final groups = _eggGroups(id);
    if (groups.isEmpty || groups.contains('Undiscovered')) return false;
    if (d['gender'] == 'F' || d['gender'] == 'N') return false;
    final ratio = d['genderRatio'] as Map?;
    if (ratio != null && (ratio['M'] as num? ?? 0) == 0) return false;
    return true;
  }

  /// Filas de tabla por generación (1-9) de los Pokémon que aprenden [slug].
  Map<int, List<PokemonRow>> rowsFor(String slug, bool spanish) {
    final mid = moveId(slug);
    final home = kHomeGame;
    final byDex = <int, GameSpecies>{
      if (home != null) for (final gs in home.species) gs.species.dex: gs,
    };
    // Aprendizaje por Pokémon y generación.
    final learners = <String, Map<int, List<String>>>{};
    _learnsets.forEach((pid, v) {
      final src = ((v as Map)['learnset'] as Map?)?[mid] as List?;
      if (src == null) return;
      final perGen = <int, List<String>>{};
      for (final s in src) {
        final code = s.toString();
        final g = int.tryParse(code[0]);
        if (g != null) perGen.putIfAbsent(g, () => []).add(code.substring(1));
      }
      if (perGen.isNotEmpty) learners[pid] = perGen;
    });

    String nameOf(String pid) {
      final d = _entry(pid);
      final dex = (d?['num'] as num?)?.toInt();
      final gs = dex == null ? null : byDex[dex];
      final base = gs?.species.displayName(spanish) ?? (d?['name']?.toString() ?? pid);
      final forme = d?['forme']?.toString() ?? '';
      if (forme.isEmpty) return base;
      final api = '${gs?.species.name ?? pid}-${forme.toLowerCase().replaceAll(' ', '-')}';
      return '$base (${localizedFormName(api)})';
    }

    // Posibles padres de un movimiento huevo: aprenden el movimiento por nivel en
    // esa generación, pueden ser machos y comparten grupo huevo con la cría.
    final fathersCache = <int, List<String>>{};
    List<String> fathersGen(int gen) => fathersCache.putIfAbsent(gen, () {
          final out = <String>[];
          learners.forEach((pid, perGen) {
            final s = perGen[gen];
            if (s == null || !s.any((x) => x.startsWith('L'))) return;
            if (!_canBeFather(pid)) return;
            out.add(pid);
          });
          return out;
        });

    String fathersText(String baby, int gen) {
      final groups = _eggGroups(baby).toSet();
      if (groups.isEmpty) return '';
      final babyDex = (_entry(baby)?['num'] as num?)?.toInt();
      final names = <String>[];
      for (final f in fathersGen(gen)) {
        if (f == baby) continue;
        final fd = _entry(f);
        if (fd == null) continue;
        if ((fd['num'] as num?)?.toInt() == babyDex) continue;
        if (!_eggGroups(f).any(groups.contains)) continue;
        // Las formas cosméticas de la misma especie no se repiten.
        final n = nameOf(f);
        if (!names.contains(n)) names.add(n);
      }
      if (names.isEmpty) return '';
      names.sort();
      final shown = names.take(8).join(', ');
      return names.length > 8 ? '$shown… (+${names.length - 8})' : shown;
    }

    String methodText(int gen, String pid, List<String> codes) {
      final parts = <String>[];
      final levels = <int>[
        for (final c in codes)
          if (c.startsWith('L')) int.tryParse(c.substring(1)) ?? 0,
      ]..sort();
      if (levels.isNotEmpty) {
        final uniq = levels.toSet().toList();
        parts.add(uniq.length == 1 && uniq.first <= 1
            ? 'Nivel 1 / al evolucionar'
            : 'Nivel ${uniq.map((l) => l <= 1 ? 'inicial' : '$l').join(', ')}');
      }
      if (codes.any((c) => c.startsWith('M'))) parts.add('MT/MO');
      if (codes.any((c) => c.startsWith('T'))) parts.add('Tutor');
      if (codes.any((c) => c.startsWith('E'))) {
        final f = fathersText(pid, gen);
        parts.add(f.isEmpty ? 'Huevo' : 'Huevo (padre: $f)');
      }
      if (codes.any((c) => c.startsWith('S'))) parts.add('Evento');
      if (codes.any((c) => c.startsWith('D'))) parts.add('Dream World');
      if (codes.any((c) => c.startsWith('V'))) parts.add('Consola Virtual');
      if (parts.isEmpty) parts.add('Otro');
      return parts.join(' · ');
    }

    final out = <int, List<PokemonRow>>{};
    learners.forEach((pid, perGen) {
      final d = _entry(pid);
      final dex = (d?['num'] as num?)?.toInt();
      if (dex == null || dex <= 0) return; // Pokémon de pruebas o inexistentes
      final gs = byDex[dex];
      perGen.forEach((gen, codes) {
        out.putIfAbsent(gen, () => []).add(PokemonRow(
              no: dex,
              name: nameOf(pid),
              sprite: gs?.entries.first.sprite,
              cells: [methodText(gen, pid, codes)],
            ));
      });
    });
    for (final rows in out.values) {
      rows.sort((a, b) {
        final c = (a.no ?? 1 << 20).compareTo(b.no ?? 1 << 20);
        return c != 0 ? c : a.name.compareTo(b.name);
      });
    }
    return out;
  }
}

const _genNames = {
  1: 'I', 2: 'II', 3: 'III', 4: 'IV', 5: 'V', 6: 'VI', 7: 'VII', 8: 'VIII', 9: 'IX',
};

/// Pokémon que aprenden un movimiento, separados por generación y con el método
/// o nivel (y, si es movimiento huevo, los padres que pueden transmitirlo).
class MoveLearnersSection extends StatefulWidget {
  final String slug;
  final bool spanish;
  final AppSettings settings;
  const MoveLearnersSection({
    super.key,
    required this.slug,
    required this.spanish,
    required this.settings,
  });

  @override
  State<MoveLearnersSection> createState() => _MoveLearnersSectionState();
}

class _MoveLearnersSectionState extends State<MoveLearnersSection> {
  late Future<Map<int, List<PokemonRow>>> _future = _load();
  int? _gen;

  Future<Map<int, List<PokemonRow>>> _load() async {
    final store = await LearnsetStore.load();
    return store.rowsFor(widget.slug, widget.spanish);
  }

  @override
  void didUpdateWidget(covariant MoveLearnersSection old) {
    super.didUpdateWidget(old);
    if (old.slug != widget.slug || old.spanish != widget.spanish) {
      _future = _load();
      _gen = null;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<int, List<PokemonRow>>>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (s.hasError) {
            return Row(children: [
              const Expanded(
                  child: Text('No se han podido cargar los datos de aprendizaje. Comprueba la conexión.')),
              TextButton(
                onPressed: () => setState(() => _future = _load()),
                child: const Text('Reintentar'),
              ),
            ]);
          }
          final byGen = s.data ?? const <int, List<PokemonRow>>{};
          if (byGen.isEmpty) {
            return const Text('Ningún Pokémon aprende este movimiento según los datos disponibles.');
          }
          final gens = byGen.keys.toList()..sort();
          final gen = (_gen != null && byGen.containsKey(_gen)) ? _gen! : gens.last;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final g in gens)
                  ChoiceChip(
                    label: Text('Gen. ${_genNames[g] ?? g} (${byGen[g]!.length})'),
                    selected: g == gen,
                    onSelected: (_) => setState(() => _gen = g),
                  ),
              ]),
              const SizedBox(height: 10),
              PokemonTable(
                key: ValueKey('${widget.slug}-$gen'),
                settings: widget.settings,
                extraHeaders: const ['Cómo lo aprende'],
                extraFlex: const [3],
                rows: byGen[gen]!,
              ),
            ],
          );
        },
      );
}
