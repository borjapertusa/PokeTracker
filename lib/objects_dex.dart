import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'settings.dart';
import 'text_editor.dart';
import 'package:flutter/services.dart';

import 'details.dart';
import 'models.dart';

/// Agrupaciones que aparecen en el selector de la Objetodex.
/// PokéAPI identifica muchos objetos por generación; los textos y precios
/// específicos de versión se usan como evidencia adicional cuando existen.
class _ItemGameGroup {
  final String id;
  final String label;
  final int generation;
  final List<String> versionGroups;
  const _ItemGameGroup(this.id, this.label, this.generation, this.versionGroups);
}

const _itemGroups = <_ItemGameGroup>[
  _ItemGameGroup('gen1', 'Rojo / Azul / Amarillo', 1, ['red-blue', 'yellow']),
  _ItemGameGroup('gen2', 'Oro / Plata / Cristal', 2, ['gold-silver', 'crystal']),
  _ItemGameGroup('gen3', 'Rubí / Zafiro / Esmeralda', 3, ['ruby-sapphire', 'emerald']),
  _ItemGameGroup('frlg', 'Rojo Fuego / Verde Hoja', 3, ['firered-leafgreen']),
  _ItemGameGroup('gen4dppt', 'Diamante / Perla / Platino', 4, ['diamond-pearl', 'platinum']),
  _ItemGameGroup('hgss', 'Oro HeartGold / Plata SoulSilver', 4, ['heartgold-soulsilver']),
  _ItemGameGroup('gen5', 'Blanco / Negro / Blanco 2 / Negro 2', 5, ['black-white', 'black-2-white-2']),
  _ItemGameGroup('gen6xy', 'X / Y', 6, ['x-y']),
  _ItemGameGroup('oras', 'Rubí Omega / Zafiro Alfa', 6, ['omega-ruby-alpha-sapphire']),
  _ItemGameGroup('gen7sm', 'Sol / Luna / Ultrasol / Ultraluna', 7, ['sun-moon', 'ultra-sun-ultra-moon']),
  _ItemGameGroup('letsgo', "Let's Go, Pikachu / Let's Go, Eevee", 7, ['lets-go-pikachu-lets-go-eevee']),
  _ItemGameGroup('gen8', 'Espada / Escudo (incluidos los DLC)', 8, ['sword-shield', 'the-isle-of-armor', 'the-crown-tundra']),
  _ItemGameGroup('pla', 'Leyendas Pokémon: Arceus', 8, ['legends-arceus']),
  _ItemGameGroup('bdsp', 'Diamante Brillante / Perla Reluciente', 8, ['brilliant-diamond-shining-pearl']),
  _ItemGameGroup('gen9', 'Escarlata / Púrpura (incluidos los DLC)', 9, ['scarlet-violet', 'the-teal-mask', 'the-indigo-disk']),
  _ItemGameGroup('za', 'Leyendas Pokémon: Z-A (incluido el DLC)', 9, ['legends-za', 'mega-dimension']),
];

const _versionGroupsByGeneration = <int, Set<String>>{
  1: {'red-blue', 'yellow'},
  2: {'gold-silver', 'crystal'},
  3: {'ruby-sapphire', 'emerald', 'firered-leafgreen'},
  4: {'diamond-pearl', 'platinum', 'heartgold-soulsilver'},
  5: {'black-white', 'black-2-white-2'},
  6: {'x-y', 'omega-ruby-alpha-sapphire'},
  7: {'sun-moon', 'ultra-sun-ultra-moon', 'lets-go-pikachu-lets-go-eevee'},
  8: {'sword-shield', 'the-isle-of-armor', 'the-crown-tundra', 'legends-arceus', 'brilliant-diamond-shining-pearl'},
  9: {'scarlet-violet', 'the-teal-mask', 'the-indigo-disk', 'legends-za', 'mega-dimension'},
};

class _ItemRecord {
  final Map<String, dynamic> data;
  final String name;
  final String category;
  final String? sprite;
  final Set<String> generations;
  final Set<String> versionGroups;
  _ItemRecord(this.data, this.name, this.category, this.sprite,
      this.generations, this.versionGroups);

  factory _ItemRecord.fromJson(Map<String, dynamic> j) {
    String localized(List raw, String lang, String fallback) {
      for (final e in raw) {
        if (e is Map && e['language'] is Map && e['language']['name'] == lang) {
          return (e['name'] ?? e['text'] ?? fallback).toString();
        }
      }
      return fallback;
    }

    final id = (j['name'] ?? '').toString();
    final fallback = _pretty(id);
    final name = localized((j['names'] as List? ?? []), 'es', fallback);
    final categoryRaw = (j['category'] as Map?)?['name']?.toString() ?? 'other';
    final category = _categoryName(categoryRaw);
    final generations = <String>{
      for (final g in (j['game_indices'] as List? ?? []))
        if (g is Map && g['generation'] is Map)
          (g['generation']['name'] ?? '').toString(),
    };
    final groups = <String>{
      for (final f in (j['flavor_text_entries'] as List? ?? []))
        if (f is Map && f['version_group'] is Map)
          (f['version_group']['name'] ?? '').toString(),
      for (final p in (j['prices'] as List? ?? []))
        if (p is Map && p['version_group'] is Map)
          (p['version_group']['name'] ?? '').toString(),
    };
    return _ItemRecord(
      j,
      name,
      category,
      (j['localSprite'] ?? (j['sprites'] as Map?)?['default'])?.toString(),
      generations,
      groups,
    );
  }

  bool availableIn(_ItemGameGroup group) {
    if (versionGroups.any(group.versionGroups.contains)) return true;
    // Si el version group de Z-A aún no está publicado en la API, mostramos
    // el inventario de Gen IX como provisional en vez de dejar la sección vacía.
    if (group.id == 'za') return generations.contains('generation-ix');
    final sameGenerationGroups = _versionGroupsByGeneration[group.generation] ?? const <String>{};
    // Si la fuente sí aporta datos de versión para ese objeto, pero no para
    // este grupo, no lo mostramos como confirmado en otra edición hermana.
    if (versionGroups.any(sameGenerationGroups.contains)) return false;
    final generation = 'generation-${_romanGeneration(group.generation)}';
    return generations.contains(generation);
  }
}

String _romanGeneration(int n) => const {
  1: 'i', 2: 'ii', 3: 'iii', 4: 'iv', 5: 'v',
  6: 'vi', 7: 'vii', 8: 'viii', 9: 'ix', 10: 'x',
}[n] ?? '$n';

String _pretty(String value) => value.split('-').map((p) => p.isEmpty
    ? p
    : '${p[0].toUpperCase()}${p.substring(1)}').join(' ');

String _categoryName(String id) => const {
  'stat-boosts': 'Mejora de características',
  'medicine': 'Medicina',
  'other': 'Otros',
  'in-a-pinch': 'Uso en apuros',
  'picky-healing': 'Curación selectiva',
  'type-protection': 'Protección de tipo',
  'baking-only': 'Cocina',
  'collectibles': 'Coleccionables',
  'evolution': 'Evolución',
  'spelunking': 'Exploración',
  'held-items': 'Objetos equipables',
  'choice': 'Objetos de elección',
  'effort-training': 'Entrenamiento',
  'bad-held-items': 'Objetos equipables perjudiciales',
  'training': 'Entrenamiento',
  'plates': 'Tablas',
  'species-specific': 'Específicos de especie',
  'type-enhancement': 'Potenciadores de tipo',
  'event-items': 'Objetos de evento',
  'gameplay': 'Objetos de juego',
  'plot-advancement': 'Objetos clave',
  'unused': 'Sin uso',
  'loot': 'Botín',
  'all-mail': 'Cartas',
  'all-machines': 'Máquinas',
  'flutes': 'Flautas',
  'apricorn-box': 'Cajas de Bonguris',
  'apricorn-balls': 'Poké Balls de Bonguris',
  'data-cards': 'Tarjetas de datos',
  'jewels': 'Joyas',
  'miracle-shooter': 'Lanzamilagros',
  'mega-stones': 'Megapiedras',
  'memories': 'Discos de memoria',
  'z-crystals': 'Cristales Z',
  'dynamax-crystals': 'Cristales Dinamax',
  'curry-ingredients': 'Ingredientes de curry',
  'tera-shard': 'Teralitos',
}[id] ?? _pretty(id);

class ObjectsDexScreen extends StatefulWidget {
  final bool spanish;
  final DexDetails? details;
  final List<Species> species;
  final AppSettings settings;
  const ObjectsDexScreen({super.key, required this.spanish, required this.details, required this.species, required this.settings});

  @override
  State<ObjectsDexScreen> createState() => _ObjectsDexScreenState();
}

class _ObjectsDexScreenState extends State<ObjectsDexScreen> {
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  final _search = TextEditingController();
  _ItemGameGroup _selected = _itemGroups.first;
  Future<List<_ItemRecord>>? _visibleFuture;
  Future<List<_ItemRecord>>? _allItemsFuture;
  int _loaded = 0;
  int _total = 0;
  bool _usingLocalData = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _visibleFuture = _itemsFor(_selected);
  }

  @override
  void dispose() {
    _search.dispose();
    _client.close(force: true);
    super.dispose();
  }

  Future<Map<String, dynamic>> _getJson(String url) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close();
    if (response.statusCode != 200) {
      throw HttpException('HTTP ${response.statusCode} al consultar $url');
    }
    return jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
  }

  Future<List<_ItemRecord>> _itemsFor(_ItemGameGroup group) async {
    final all = await (_allItemsFuture ??= _loadAllItems());
    return all.where((item) => item.availableIn(group) &&
        (item.data['category'] as Map?)?['name'] != 'all-machines').toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<_ItemRecord>> _loadAllItems() async {
    try {
      // Si se ha generado assets/data/items.json, la Objetodex funciona offline.
      try {
        final local = jsonDecode(await rootBundle.loadString('assets/data/items.json')) as Map<String, dynamic>;
        final rows = (local['items'] as List? ?? const []).cast<Map<String, dynamic>>();
        if (rows.isNotEmpty) {
          final cached = rows.map(_ItemRecord.fromJson).toList();
          _total = cached.length;
          _loaded = cached.length;
          _usingLocalData = true;
          if (mounted) setState(() {});
          return cached;
        }
      } catch (_) {
        // El archivo local es opcional hasta ejecutar tool/download_items.dart.
      }
      _usingLocalData = false;
      final index = await _getJson('https://pokeapi.co/api/v2/item?limit=2000');
      final results = (index['results'] as List).cast<Map<String, dynamic>>();
      _total = results.length;
      _loaded = 0;
      if (mounted) setState(() {});
      final output = <_ItemRecord>[];
      var next = 0;
      // Concurrencia limitada para no saturar PokéAPI.
      Future<void> worker() async {
        while (true) {
          final i = next++;
          if (i >= results.length) return;
          try {
            final data = await _getJson(results[i]['url'] as String);
            output.add(_ItemRecord.fromJson(data));
          } catch (_) {
            // Un registro puntual que falle no impide cargar el resto.
          }
          _loaded++;
          if (mounted && (_loaded % 12 == 0 || _loaded == _total)) setState(() {});
        }
      }
      await Future.wait(List.generate(10, (_) => worker()));
      if (output.isEmpty) throw Exception('No se recibió ningún objeto.');
      return output;
    } catch (e) {
      rethrow;
    }
  }

  void _changeGroup(_ItemGameGroup? group) {
    if (group == null) return;
    setState(() {
      _selected = group;
      _visibleFuture = _itemsFor(group);
    });
  }

  String _description(_ItemRecord item) {
    final entries = (item.data['flavor_text_entries'] as List? ?? []).cast<Map>();
    final wanted = entries.where((e) =>
      (e['language'] as Map?)?['name'] == (widget.spanish ? 'es' : 'en') &&
      _selected.versionGroups.contains((e['version_group'] as Map?)?['name'])).toList();
    final candidates = wanted.isNotEmpty ? wanted : entries.where((e) =>
      (e['language'] as Map?)?['name'] == (widget.spanish ? 'es' : 'en')).toList();
    if (candidates.isEmpty) return '';
    final raw = candidates.last['text']?.toString() ?? '';
    return raw.replaceAll(RegExp(r'[\n\r\f]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _effect(_ItemRecord item) {
    final entries = (item.data['effect_entries'] as List? ?? []).cast<Map>();
    for (final lang in widget.spanish ? ['es'] : ['en']) {
      for (final e in entries) {
        if ((e['language'] as Map?)?['name'] == lang) {
          return (e['effect'] ?? e['short_effect'] ?? '').toString().replaceAll('\n', ' ').trim();
        }
      }
    }
    return widget.spanish
        ? 'La fuente no ofrece este efecto general en español.'
        : 'No hay un efecto general traducido disponible en la fuente.';
  }

  List<String> _evolutionUses(_ItemRecord item) {
    final details = widget.details;
    if (details == null) return [];
    final aliases = <String>{
      item.name.toLowerCase(),
      (item.data['name'] ?? '').toString().replaceAll('-', ' ').toLowerCase(),
    };
    const extra = <String, String>{
      'king\'s-rock': 'kings rock', 'kings-rock': 'kings rock', 'metal-coat': 'metal coat',
      'dragon-scale': 'dragon scale', 'up-grade': 'up grade',
      'dubious-disc': 'dubious disc', 'deep-sea-tooth': 'deep sea tooth',
      'deep-sea-scale': 'deep sea scale', 'prism-scale': 'prism scale',
      'reaper-cloth': 'reaper cloth', 'razor-claw': 'razor claw',
      'razor-fang': 'razor fang', 'whipped-dream': 'whipped dream',
      'galarica-cuff': 'galarica cuff', 'galarica-wreath': 'galarica wreath',
    };
    final rawId = (item.data['name'] ?? '').toString();
    if (extra[rawId] != null) aliases.add(extra[rawId]!);
    String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9áéíóúüñ]'), '');
    final wanted = aliases.map(norm).where((s) => s.isNotEmpty).toSet();
    final found = <String>{};
    final byDex = {for (final s in widget.species) s.dex: s};
    final seenChains = <int>{};
    for (final species in widget.species) {
      final chainId = details.species(species.dex)?.chain;
      if (chainId == null || !seenChains.add(chainId)) continue;
      final chain = details.chain(chainId);
      if (chain == null) continue;
      for (final edge in evoEdges(chain)) {
        final requirement = norm(edge.$2);
        if (wanted.any((a) => requirement.contains(a))) {
          final from = byDex[edge.$1];
          final to = byDex[edge.$3];
          if (from != null && to != null) {
            found.add('${from.displayName(widget.spanish)} → ${to.displayName(widget.spanish)}');
          }
        }
      }
    }
    return found.toList()..sort();
  }

  void _showDetail(_ItemRecord item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ItemDetailSheet(
        item: item,
        group: _selected,
        description: _description(item),
        effect: _effect(item),
        evolutions: _evolutionUses(item),
        settings: widget.settings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Objetos')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: DropdownButtonFormField<_ItemGameGroup>(
            value: _selected,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Ediciones',
              prefixIcon: Icon(Icons.videogame_asset_outlined),
              border: OutlineInputBorder(),
            ),
            items: [for (final group in _itemGroups)
              DropdownMenuItem(value: group, child: Text(group.label, overflow: TextOverflow.ellipsis))],
            onChanged: _changeGroup,
          ),
        ),
        if (_selected.id == 'za')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 8),
            child: Text(
              'Para Leyendas Z-A, la disponibilidad puede depender de que PokéAPI haya publicado ya los datos específicos del juego y su DLC.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              labelText: 'Buscar objeto',
              border: const OutlineInputBorder(),
              suffixIcon: _query.isEmpty ? null : IconButton(
                tooltip: 'Borrar búsqueda', icon: const Icon(Icons.clear),
                onPressed: () { _search.clear(); setState(() => _query = ''); },
              ),
            ),
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<_ItemRecord>>(
            future: _visibleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                final progress = _total == 0 ? null : _loaded / _total;
                return Center(child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Padding(padding: const EdgeInsets.all(24), child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_total == 0 ? 'Consultando el catálogo de objetos…' : 'Descargando datos de objetos: $_loaded / $_total'),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 8),
                      const Text('La primera carga consulta los detalles de los objetos. Después, el catálogo queda en memoria mientras la app siga abierta.', textAlign: TextAlign.center),
                    ],
                  )),
                ));
              }
              if (snapshot.hasError) {
                return Center(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.cloud_off, size: 42),
                    const SizedBox(height: 12),
                    const Text('No se pudo cargar la Objetodex. Comprueba la conexión a Internet.'),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => setState(() { _allItemsFuture = null; _visibleFuture = _itemsFor(_selected); }),
                      icon: const Icon(Icons.refresh), label: const Text('Reintentar'),
                    ),
                  ]),
                ));
              }
              final all = snapshot.data ?? const <_ItemRecord>[];
              final filtered = all.where((item) => item.name.toLowerCase().contains(_query) ||
                (item.data['name'] ?? '').toString().contains(_query)).toList();
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    Text('${filtered.length} objetos', style: theme.textTheme.labelLarge),
                    const SizedBox(width: 8),
                    Chip(avatar: Icon(_usingLocalData ? Icons.offline_pin : Icons.cloud_done, size: 16), label: Text(_usingLocalData ? 'Local' : 'Online'), visualDensity: VisualDensity.compact),
                    const Spacer(),
                    const Tooltip(
                      message: 'PokéAPI indica la presencia de objetos por generación. Algunas diferencias entre ediciones de una misma generación pueden no estar desglosadas.',
                      child: Icon(Icons.info_outline, size: 18),
                    ),
                  ]),
                ),
                Expanded(child: filtered.isEmpty
                  ? const Center(child: Text('No hay objetos que coincidan con la búsqueda.'))
                  : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) {
                      final item = filtered[i];
                      final description = _description(item);
                      return ListTile(
                        leading: _ItemSprite(url: item.sprite, size: 44),
                        title: Text(item.name),
                        subtitle: Text(description.isEmpty ? item.category : '${item.category} · $description', maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showDetail(item),
                      );
                    },
                  )),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _ItemSprite extends StatelessWidget {
  final String? url;
  final double size;
  const _ItemSprite({required this.url, this.size = 48});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: url == null || url!.isEmpty
      ? const Icon(Icons.inventory_2_outlined)
      : url!.startsWith('assets/') || AppSettings.current?.offlineMode == true
          ? (url!.startsWith('assets/')
              ? Image.asset(url!, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined))
              : const Icon(Icons.inventory_2_outlined))
          : Image.network(url!, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.inventory_2_outlined)),
  );
}

class _ItemDetailSheet extends StatelessWidget {
  final _ItemRecord item;
  final _ItemGameGroup group;
  final String description;
  final String effect;
  final List<String> evolutions;
  final AppSettings settings;
  const _ItemDetailSheet({required this.item, required this.group,
    required this.description, required this.effect, required this.evolutions, required this.settings});

  @override
  Widget build(BuildContext context) {
    final d = item.data;
    final prices = (d['prices'] as List? ?? []).cast<Map>();
    final matchingPrices = prices.where((p) => group.versionGroups.contains(
      (p['version_group'] as Map?)?['name'])).toList();
    final held = (d['held_by_pokemon'] as List? ?? []).cast<Map>();
    final attributes = (d['attributes'] as List? ?? []).cast<Map>();
    final fling = d['fling_effect'] is Map ? (d['fling_effect']['name'] ?? '').toString() : '';
    final flingPower = d['fling_power'];
    final scroll = MediaQuery.of(context).size.height * .82;
    return SafeArea(child: SizedBox(
      height: scroll,
      child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _ItemSprite(url: item.sprite, size: 68),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              Text(item.category, style: Theme.of(context).textTheme.bodyMedium),
            ])),
          ]),
          const SizedBox(height: 18),
          _section(context, 'Ediciones', group.label),
          _editableSection(context, 'Para qué sirve', effect, 'item:${item.data['name']}:effect', settings),
          if (description.isNotEmpty) _editableSection(context, 'Descripción en el juego', description, 'item:${item.data['name']}:description', settings),
          if (evolutions.isNotEmpty) _section(context, 'Evoluciones que provoca', evolutions.join('\n'))
          else if (item.category.toLowerCase().contains('evol'))
            _section(context, 'Evolución', 'Es un objeto evolutivo. No se ha podido asociar automáticamente a una línea evolutiva concreta.'),
          if (matchingPrices.isNotEmpty) _section(context, 'Precio', matchingPrices.map((p) =>
            'Compra: ${p['purchase_price'] ?? '—'} · Venta: ${p['sell_price'] ?? '—'}').join('\n')),
          if (attributes.isNotEmpty) _section(context, 'Atributos', attributes.map((a) => _pretty((a['name'] ?? '').toString())).join(', ')),
          if (held.isNotEmpty) _section(context, 'Pokémon que pueden llevarlo', held.map((h) {
            final pokemon = _pretty(((h['pokemon'] as Map?)?['name'] ?? '').toString());
            final versions = ((h['version_details'] as List? ?? []).cast<Map>())
                .map((v) => _pretty(((v['version'] as Map?)?['name'] ?? '').toString())).toSet();
            final rarities = ((h['version_details'] as List? ?? []).cast<Map>())
                .map((v) => v['rarity']).where((v) => v != null).toSet();
            final rarity = rarities.isEmpty ? '' : ' · prob. ${rarities.join('/')}%';
            return '$pokemon${versions.isEmpty ? '' : ' (${versions.join(', ')})'}$rarity';
          }).join('\n')),
          if (d['baby_trigger_for'] != null) _section(context, 'Cría', 'Está relacionado con una evolución que permite obtener un Pokémon bebé.'),
          if (flingPower != null) _section(context, 'Movimiento Lanzamiento', 'Potencia: $flingPower${fling.isEmpty ? '' : ' · Efecto: ${_pretty(fling)}'}'),
          const SizedBox(height: 12),
          Text('Disponibilidad: el catálogo utiliza los índices de generación de PokéAPI. La fuente no distingue todos los objetos exclusivos de cada edición; los textos y precios específicos se muestran cuando están disponibles.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]),
      ),
    ));
  }

  Widget _editableSection(BuildContext context, String title, String body, String key, AppSettings settings) {
    final value = editableText(settings, key, body);
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
          IconButton(tooltip: 'Editar texto', icon: const Icon(Icons.edit, size: 18),
            onPressed: () => editTextValue(context, settings, key, value, title))]),
        Text(value),
      ]));
  }

  Widget _section(BuildContext context, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(body),
    ]),
  );
}
