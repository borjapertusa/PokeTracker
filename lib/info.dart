import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'details.dart';
import 'models.dart';
import 'settings.dart';
import 'widgets.dart';

const _typeEs = <String, String>{
  'normal': 'Normal', 'fire': 'Fuego', 'water': 'Agua', 'electric': 'Eléctrico',
  'grass': 'Planta', 'ice': 'Hielo', 'fighting': 'Lucha', 'poison': 'Veneno',
  'ground': 'Tierra', 'flying': 'Volador', 'psychic': 'Psíquico', 'bug': 'Bicho',
  'rock': 'Roca', 'ghost': 'Fantasma', 'dragon': 'Dragón', 'dark': 'Siniestro',
  'steel': 'Acero', 'fairy': 'Hada',
};

const _typeColor = <String, Color>{
  'normal': Color(0xFFA8A77A), 'fire': Color(0xFFEE8130), 'water': Color(0xFF6390F0),
  'electric': Color(0xFFD9B21F), 'grass': Color(0xFF7AC74C), 'ice': Color(0xFF6FC3C0),
  'fighting': Color(0xFFC22E28), 'poison': Color(0xFFA33EA1), 'ground': Color(0xFFC9A24A),
  'flying': Color(0xFFA98FF3), 'psychic': Color(0xFFF95587), 'bug': Color(0xFFA6B91A),
  'rock': Color(0xFFB6A136), 'ghost': Color(0xFF735797), 'dragon': Color(0xFF6F35FC),
  'dark': Color(0xFF705746), 'steel': Color(0xFF8E8EA8), 'fairy': Color(0xFFD685AD),
};

Color _statColor(int v) => v < 50
    ? Colors.red
    : v < 80
        ? Colors.orange
        : v < 100
            ? Colors.amber
            : v < 130
                ? Colors.lightGreen
                : Colors.green;

String _num(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Ficha del Pokémon: estadísticas, evolución, ubicaciones por juego y más.
class PokemonInfo extends StatefulWidget {
  final Game game;
  final List<Game> games;
  final GameSpecies gs;
  final DexDetails? details;
  final Map<int, Species> byDex;
  final AppSettings settings;
  const PokemonInfo({
    super.key,
    required this.game,
    required this.games,
    required this.gs,
    required this.details,
    required this.byDex,
    required this.settings,
  });

  @override
  State<PokemonInfo> createState() => _PokemonInfoState();
}

class _PokemonInfoState extends State<PokemonInfo> {
  String? variety;

  @override
  void didUpdateWidget(covariant PokemonInfo old) {
    super.didUpdateWidget(old);
    if (!identical(old.gs, widget.gs)) variety = null;
  }

  Future<void> _openUrl(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  @override
  Widget build(BuildContext context) {
    final sp = widget.gs.species;
    final info = widget.details?.species(sp.dex);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 24),
          if (info == null)
            Text(
              'Sin datos de ficha. Ejecuta  python tools\\build_details.py  y reinicia la app.',
              style: Theme.of(context).textTheme.bodySmall,
            )
          else
            ..._sections(context, info),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () =>
                      _openUrl('https://pokemondb.net/pokedex/${sp.name}'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('PokémonDB'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openUrl(
                      'https://www.serebii.net/pokedex-sv/${sp.name}/'),
                  icon: const Icon(Icons.open_in_new, size: 16),
                  label: const Text('Serebii'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _varLabel(Species sp, VarietyInfo v) {
    if (v.name == sp.name) return 'Base';
    final suffix = v.name.startsWith('${sp.name}-')
        ? v.name.substring(sp.name.length + 1)
        : v.name;
    return suffix
        .split('-')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Widget _title(ThemeData t, String s) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(s, style: t.textTheme.titleSmall),
      );

  Widget _fact(ThemeData t, String l, String v) => SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l, style: t.textTheme.labelSmall),
            Text(v, style: t.textTheme.bodyMedium),
          ],
        ),
      );

  List<Widget> _sections(BuildContext context, SpeciesInfo info) {
    final t = Theme.of(context);
    final sp = widget.gs.species;
    final ids = widget.gs.entries.map((e) => e.id).toSet();
    final vs = info.varieties
        .where((v) => v.isDefault || ids.contains(v.name))
        .toList();
    final cur =
        vs.firstWhere((v) => v.name == variety, orElse: () => vs.first);
    final abilities = widget.details?.abilities ?? const <String, String>{};
    final total = cur.stats.fold<int>(0, (a, b) => a + b);
    const statNames = [
      'PS', 'Ataque', 'Defensa', 'At. Esp.', 'Def. Esp.', 'Velocidad'
    ];

    return [
      if (vs.length > 1)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final v in vs)
                ChoiceChip(
                  label: Text(_varLabel(sp, v)),
                  selected: identical(v, cur),
                  onSelected: (_) => setState(() => variety = v.name),
                ),
            ],
          ),
        ),
      if (info.genus.isNotEmpty) Text(info.genus, style: t.textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final ty in cur.types) _TypeChip(ty),
      ]),
      if (info.text.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(info.text,
              style: t.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic)),
        ),
      _title(t, 'Datos'),
      Wrap(spacing: 12, runSpacing: 10, children: [
        _fact(t, 'Altura', '${_num(cur.height / 10)} m'),
        _fact(t, 'Peso', '${_num(cur.weight / 10)} kg'),
        if (cur.exp > 0) _fact(t, 'Exp. base', '${cur.exp}'),
        if (info.catchRate != null)
          _fact(t, 'Ratio de captura', '${info.catchRate}'),
        _fact(
            t,
            'Género',
            info.female < 0
                ? 'Sin género'
                : '♂ ${_num(100 - info.female * 12.5)}% · ♀ ${_num(info.female * 12.5)}%'),
        if (info.growth.isNotEmpty) _fact(t, 'Crecimiento', info.growth),
        if (info.egg.isNotEmpty) _fact(t, 'Grupo huevo', info.egg.join(', ')),
        if (info.hatch != null)
          _fact(t, 'Pasos de huevo', '${(info.hatch! + 1) * 255}'),
        if (info.happy != null) _fact(t, 'Amistad base', '${info.happy}'),
      ]),
      _title(t, 'Habilidades'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (id, hidden) in cur.abilities)
          Chip(
            visualDensity: VisualDensity.compact,
            label: Text('${abilities[id] ?? id}${hidden ? ' (oculta)' : ''}'),
          ),
      ]),
      _title(t, 'Estadísticas base'),
      for (var i = 0; i < 6; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(
                width: 78,
                child: Text(statNames[i], style: t.textTheme.bodySmall)),
            SizedBox(
              width: 34,
              child: Text('${cur.stats[i]}',
                  textAlign: TextAlign.right,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: (cur.stats[i] / 255).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                color: _statColor(cur.stats[i]),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('Total: $total', style: t.textTheme.labelLarge),
      ),
      _title(t, 'Evolución'),
      _evolution(t, info),
      ..._where(t, cur),
    ];
  }

  Widget _evolution(ThemeData t, SpeciesInfo info) {
    final tree = widget.details?.chain(info.chain);
    final edges = tree == null ? <(int, String, int)>[] : evoEdges(tree);
    if (edges.isEmpty) {
      return Text('No evoluciona.', style: t.textTheme.bodySmall);
    }
    Widget mon(int d) {
      final s = widget.byDex[d];
      final isCur = d == widget.gs.species.dex;
      return SizedBox(
        width: 76,
        child: Column(children: [
          Sprite(s?.entries.first.sprite,
              size: 48, pixel: widget.settings.pixelSprites),
          Text(
            s?.displayName(widget.settings.spanish) ?? '#$d',
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
                fontWeight: isCur ? FontWeight.bold : FontWeight.normal),
          ),
        ]),
      );
    }

    return Column(children: [
      for (final (from, req, to) in edges)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            mon(from),
            const Icon(Icons.arrow_forward, size: 16),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(req,
                    textAlign: TextAlign.center, style: t.textTheme.bodySmall),
              ),
            ),
            const Icon(Icons.arrow_forward, size: 16),
            mon(to),
          ]),
        ),
    ]);
  }

  List<Widget> _where(ThemeData t, VarietyInfo cur) {
    final g = widget.game;
    final here = cur.enc[g.id];
    final others = cur.enc.entries.where((e) => e.key != g.id).toList();
    final names = {for (final x in widget.games) x.id: x.name};
    return [
      _title(t, 'Dónde conseguirlo'),
      if (g.id != 'home') ...[
        Text(g.name, style: t.textTheme.labelLarge),
        if (here == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'PokéAPI no tiene ubicaciones para este juego. Consulta los enlaces de abajo.',
              style: t.textTheme.bodySmall,
            ),
          )
        else
          ..._versionTiles(t, here, expanded: true),
      ],
      if (others.isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(g.id == 'home' ? 'Ubicaciones por juego' : 'Otros juegos'),
          children: [
            for (final o in others) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(names[o.key] ?? o.key,
                      style: t.textTheme.labelLarge),
                ),
              ),
              ..._versionTiles(t, o.value, expanded: false),
            ],
          ],
        )
      else if (g.id == 'home')
        Text('Sin ubicaciones en los datos de PokéAPI.',
            style: t.textTheme.bodySmall),
    ];
  }

  List<Widget> _versionTiles(
      ThemeData t, Map<String, List<Encounter>> m,
      {required bool expanded}) {
    return [
      for (final e in m.entries)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: expanded && m.length <= 2,
          title: Text(
              '${e.key} · ${e.value.length} ${e.value.length == 1 ? 'zona' : 'zonas'}'),
          children: [
            for (final r in e.value)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(r.area),
                subtitle: Text([...r.methods, ...r.conds].join(' · ')),
                trailing: Text(
                  [
                    if (r.hi > 0) r.lo == r.hi ? 'Nv ${r.lo}' : 'Nv ${r.lo}–${r.hi}',
                    if (r.chance > 0) '${r.chance}%',
                  ].join(' · '),
                  style: t.textTheme.labelMedium,
                ),
              ),
          ],
        ),
    ];
  }
}

class _TypeChip extends StatelessWidget {
  final String type;
  const _TypeChip(this.type);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: _typeColor[type] ?? Colors.grey,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _typeEs[type] ?? type,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );
}
