import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'details.dart';
import 'location_names_es.dart';
import 'models.dart';
import 'move_dex.dart';
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
  final bool showLocations;
  final bool showMoves;
  const PokemonInfo({
    super.key,
    required this.game,
    required this.games,
    required this.gs,
    required this.details,
    required this.byDex,
    required this.settings,
    this.showLocations = true,
    this.showMoves = false,
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
          if (widget.showMoves) PokemonMovesSection(pokemon: sp.name, spanish: widget.settings.spanish),
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

  String _speciesOverride(int dex, String field, String fallback) =>
      widget.settings.detailOverrides['$dex:species:$field'] ?? fallback;

  String _varietyOverride(int dex, String varietyName, String field, String fallback) =>
      widget.settings.detailOverrides['$dex:$varietyName:$field'] ?? fallback;

  Future<void> _editDetails(SpeciesInfo info, VarietyInfo cur) async {
    final dex = widget.gs.species.dex;
    final varietyName = cur.name;
    final fields = <String, String>{
      'genus': _speciesOverride(dex, 'genus', info.genus),
      'description': _speciesOverride(dex, 'description', info.text),
      'height': _varietyOverride(dex, varietyName, 'height', _num(cur.height / 10)),
      'weight': _varietyOverride(dex, varietyName, 'weight', _num(cur.weight / 10)),
      'exp': _varietyOverride(dex, varietyName, 'exp', '${cur.exp}'),
      'catch': _speciesOverride(dex, 'catch', '${info.catchRate ?? ''}'),
      'egg': _speciesOverride(dex, 'egg', info.egg.map(eggGroupName).join(', ')),
      'growth': _speciesOverride(dex, 'growth', info.growth),
      'hatch': _speciesOverride(dex, 'hatch', info.hatch == null ? '' : '${(info.hatch! + 1) * 255}'),
      'happy': _speciesOverride(dex, 'happy', '${info.happy ?? ''}'),
      'stats': _varietyOverride(dex, varietyName, 'stats', cur.stats.join(', ')),
    };
    final controllers = {for (final e in fields.entries) e.key: TextEditingController(text: e.value)};
    final labels = <String, String>{
      'genus': 'Categoría', 'description': 'Descripción', 'height': 'Altura (m)',
      'weight': 'Peso (kg)', 'exp': 'Experiencia base', 'catch': 'Ratio de captura',
      'egg': 'Grupos huevo (separados por comas)', 'growth': 'Crecimiento',
      'hatch': 'Pasos de huevo', 'happy': 'Amistad base',
      'stats': 'Estadísticas base (PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad)',
    };
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Editar datos · ${widget.gs.displayName(widget.settings.spanish)}'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final key in fields.keys)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: TextField(
                      controller: controllers[key],
                      maxLines: key == 'description' ? 3 : 1,
                      decoration: InputDecoration(
                        labelText: labels[key],
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
        ],
      ),
    );
    try {
      // Espera a que Flutter termine de retirar la ruta del diálogo. Notificar
      // a los ListenableBuilder durante la transición puede dejar dependientes
      // de InheritedElements todavía montados (assert _dependents.isEmpty).
      if (saved == true) {
        await WidgetsBinding.instance.endOfFrame;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      // No persistimos ni notificamos a toda la aplicación si el usuario
      // pulsa Guardar sin haber cambiado ningún dato.
      final changed = fields.keys.any(
        (key) => controllers[key]!.text.trim() != fields[key]!.trim(),
      );

      if (saved == true && mounted && changed) {
        widget.settings.update(() {
          for (final key in fields.keys) {
            final target =
                (key == 'height' || key == 'weight' || key == 'exp' || key == 'stats')
                    ? '$dex:$varietyName:$key'
                    : '$dex:species:$key';
            widget.settings.detailOverrides[target] =
                controllers[key]!.text.trim();
          }
        });
        if (mounted) setState(() {});
      }
    } finally {
      for (final c in controllers.values) {
        c.dispose();
      }
    }
  }

  String _varLabel(Species sp, VarietyInfo v) {
    if (v.name == sp.name) return 'Base';
    final suffix = v.name.startsWith('${sp.name}-')
        ? v.name.substring(sp.name.length + 1)
        : v.name;
    return localizedFormName(suffix);
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
    const statNames = [
      'PS', 'Ataque', 'Defensa', 'At. Esp.', 'Def. Esp.', 'Velocidad'
    ];
    final genus = _speciesOverride(sp.dex, 'genus', info.genus);
    final description = _speciesOverride(sp.dex, 'description', info.text);
    final height = double.tryParse(_varietyOverride(sp.dex, cur.name, 'height', _num(cur.height / 10))) ?? cur.height / 10;
    final weight = double.tryParse(_varietyOverride(sp.dex, cur.name, 'weight', _num(cur.weight / 10))) ?? cur.weight / 10;
    final exp = int.tryParse(_varietyOverride(sp.dex, cur.name, 'exp', '${cur.exp}')) ?? cur.exp;
    final catchRate = _speciesOverride(sp.dex, 'catch', '${info.catchRate ?? ''}');
    final egg = _speciesOverride(sp.dex, 'egg', info.egg.map(eggGroupName).join(', '));
    final growth = _speciesOverride(sp.dex, 'growth', info.growth);
    final hatch = _speciesOverride(sp.dex, 'hatch', info.hatch == null ? '' : '${(info.hatch! + 1) * 255}');
    final happy = _speciesOverride(sp.dex, 'happy', '${info.happy ?? ''}');
    final statValues = _varietyOverride(sp.dex, cur.name, 'stats', cur.stats.join(', '))
        .split(',').map((v) => int.tryParse(v.trim())).toList();
    final total = statValues.length == 6 && statValues.every((v) => v != null)
        ? statValues.cast<int>().fold<int>(0, (a, b) => a + b)
        : cur.stats.fold<int>(0, (a, b) => a + b);

    return [
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () => _editDetails(info, cur),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Editar datos'),
        ),
      ),
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
      if (genus.isNotEmpty) Text(genus, style: t.textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final ty in cur.types) _TypeChip(ty),
      ]),
      if (description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description,
              style: t.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic)),
        ),
      _title(t, 'Datos'),
      Wrap(spacing: 12, runSpacing: 10, children: [
        _fact(t, 'Altura', '${_num(height)} m'),
        _fact(t, 'Peso', '${_num(weight)} kg'),
        if (exp > 0) _fact(t, 'Exp. base', '$exp'),
        if (catchRate.isNotEmpty) _fact(t, 'Ratio de captura', catchRate),
        _fact(
            t,
            'Género',
            info.female < 0
                ? 'Sin género'
                : '♂ ${_num(100 - info.female * 12.5)}% · ♀ ${_num(info.female * 12.5)}%'),
        if (growth.isNotEmpty) _fact(t, 'Crecimiento', growth),
        if (egg.isNotEmpty) _fact(t, 'Grupo huevo', egg),
        if (hatch.isNotEmpty) _fact(t, 'Pasos de huevo', hatch),
        if (happy.isNotEmpty) _fact(t, 'Amistad base', happy),
      ]),
      _title(t, 'Habilidades'),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (id, hidden) in cur.abilities)
          Tooltip(
            waitDuration: const Duration(milliseconds: 350),
            preferBelow: false,
            message: widget.details?.abilityEffects[id] ??
                'Efecto no disponible. Actualiza la ficha con tools\\build_details.py.',
            child: Chip(
              avatar: const Icon(Icons.info_outline, size: 16),
              visualDensity: VisualDensity.compact,
              label: Text('${abilities[id] ?? id}${abilityRoleLabel(id, hidden) == 'Principal' ? '' : ' (${abilityRoleLabel(id, hidden)})'}'),
            ),
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
              child: Text('${i < statValues.length && statValues[i] != null ? statValues[i] : cur.stats[i]}',
                  textAlign: TextAlign.right,
                  style: t.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LinearProgressIndicator(
                value: ((i < statValues.length && statValues[i] != null ? statValues[i]! : cur.stats[i]) / 255).clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                color: _statColor(i < statValues.length && statValues[i] != null ? statValues[i]! : cur.stats[i]),
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
      if (widget.showLocations) ..._where(t, cur),
    ];
  }

  Widget _evolution(ThemeData t, SpeciesInfo info) {
    final tree = widget.details?.chain(info.chain);
    if (tree == null || (tree.to.isEmpty && tree.dex != widget.gs.species.dex)) {
      return Text('No evoluciona.', style: t.textTheme.bodySmall);
    }

    // Cada evolución se representa como una rama independiente. Wrap permite
    // que las ramas pasen a varias filas cuando la ventana es estrecha.
    return LayoutBuilder(
      builder: (context, _) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLowest,
          border: Border.all(color: t.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 5,
                children: [
                  _evolutionLegend(t, const Color(0xFF2878D0), 'Desde forma base'),
                  _evolutionLegend(t, const Color(0xFF299B58), 'Desde 1.ª evolución'),
                  _evolutionLegend(t, const Color(0xFFE04444), 'Mega'),
                  _evolutionLegend(t, const Color(0xFFE58A24), 'Gigamax'),
                ],
              ),
              const SizedBox(height: 12),
              Center(child: _evolutionNode(tree, t, 0)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _evolutionLegend(ThemeData t, Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_downward, size: 14, color: color),
          const SizedBox(width: 3),
          Text(label, style: t.textTheme.labelSmall),
        ],
      );

  Widget _evolutionNode(EvoNode node, ThemeData t, int depth) {
    final species = widget.byDex[node.dex];
    final isCurrent = node.dex == widget.gs.species.dex;
    final name = species?.displayName(widget.settings.spanish) ?? '#${node.dex}';
    final baseEntry = species == null
        ? null
        : (species.entries.where((e) => e.kind == 'base').isNotEmpty
            ? species.entries.firstWhere((e) => e.kind == 'base')
            : species.entries.first);
    final specialForms = species?.entries
            .where((e) => e.kind == 'mega' || e.kind == 'gmax')
            .toList() ??
        const <DexEntry>[];
    final edgeColor = depth == 0
        ? const Color(0xFF2878D0)
        : const Color(0xFF299B58);

    final card = Container(
      width: 94,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: isCurrent
            ? t.colorScheme.primaryContainer
            : t.colorScheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isCurrent
              ? t.colorScheme.primary
              : t.colorScheme.outlineVariant,
          width: isCurrent ? 1.8 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Sprite(
            baseEntry?.sprite,
            size: 48,
            pixel: widget.settings.pixelSprites,
            threeD: widget.settings.threeDSprites,
          ),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );

    if (node.to.isEmpty && specialForms.isEmpty) return card;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        const SizedBox(height: 5),
        if (specialForms.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
              for (final form in specialForms)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: SizedBox(
                  width: 132,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.south,
                        size: 19,
                        color: form.kind == 'mega'
                            ? const Color(0xFFE04444)
                            : const Color(0xFFE58A24),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          form.kind == 'mega' ? 'Megaevolución' : 'Gigamax',
                          textAlign: TextAlign.center,
                          style: t.textTheme.labelSmall?.copyWith(
                            color: form.kind == 'mega'
                                ? const Color(0xFFE04444)
                                : const Color(0xFFE58A24),
                          ),
                        ),
                      ),
                      _evolutionFormCard(form, name, t),
                    ],
                  ),
                ),
                ),
            ],
            ),
          ),
        if (node.to.isNotEmpty) const SizedBox(height: 5),
        if (node.to.isNotEmpty) Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 10,
          runSpacing: 12,
          children: [
            for (final (requirement, child) in node.to)
              SizedBox(
                width: 132,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.south,
                      size: 19,
                      color: edgeColor,
                    ),
                    if (requirement.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          requirement,
                          textAlign: TextAlign.center,
                          style: t.textTheme.labelSmall?.copyWith(
                            color: edgeColor,
                          ),
                        ),
                      ),
                    _evolutionNode(child, t, depth + 1),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _evolutionFormCard(DexEntry form, String baseName, ThemeData t) {
    final formName = form.kind == 'mega'
        ? 'Mega $baseName'
        : '$baseName Gigamax';
    return Container(
      width: 94,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: t.colorScheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: form.kind == 'mega'
              ? const Color(0xFFE04444)
              : const Color(0xFFE58A24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Sprite(
            form.sprite,
            size: 48,
            pixel: widget.settings.pixelSprites,
            threeD: widget.settings.threeDSprites,
          ),
          Text(
            formName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  List<Widget> _where(ThemeData t, VarietyInfo cur) {
    final g = widget.game;
    final here = cur.enc[g.id];
    final others = cur.enc.entries.where((e) => e.key != g.id).toList();
    final names = {for (final x in widget.games) x.id: x.name};
    return [
      _title(t, 'Dónde conseguirlo'),
      if (g.id != 'home') ...[
        Row(mainAxisSize: MainAxisSize.min, children: [GameIcon(g, size: 32), const SizedBox(width: 8), Flexible(child: Text(g.name, style: t.textTheme.labelLarge))]),
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
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.games.any((x) => x.id == o.key))
                      GameIcon(widget.games.firstWhere((x) => x.id == o.key), size: 30),
                    const SizedBox(width: 8),
                    Flexible(child: Text(names[o.key] ?? o.key, style: t.textTheme.labelLarge)),
                  ]),
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
                title: Text(locationNameEs(r.area)),
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
