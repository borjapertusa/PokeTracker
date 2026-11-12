import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'details.dart';
import 'evolution_chart.dart';
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

/// Tabla de tipos: para cada tipo atacante, a qué tipos defensores le hace
/// ×2, ×½ y ×0.
const _typeChart = <String, List<List<String>>>{
  'normal': [[], ['rock', 'steel'], ['ghost']],
  'fire': [['grass', 'ice', 'bug', 'steel'], ['fire', 'water', 'rock', 'dragon'], []],
  'water': [['fire', 'ground', 'rock'], ['water', 'grass', 'dragon'], []],
  'electric': [['water', 'flying'], ['electric', 'grass', 'dragon'], ['ground']],
  'grass': [['water', 'ground', 'rock'], ['fire', 'grass', 'poison', 'flying', 'bug', 'dragon', 'steel'], []],
  'ice': [['grass', 'ground', 'flying', 'dragon'], ['fire', 'water', 'ice', 'steel'], []],
  'fighting': [['normal', 'ice', 'rock', 'dark', 'steel'], ['poison', 'flying', 'psychic', 'bug', 'fairy'], ['ghost']],
  'poison': [['grass', 'fairy'], ['poison', 'ground', 'rock', 'ghost'], ['steel']],
  'ground': [['fire', 'electric', 'poison', 'rock', 'steel'], ['grass', 'bug'], ['flying']],
  'flying': [['grass', 'fighting', 'bug'], ['electric', 'rock', 'steel'], []],
  'psychic': [['fighting', 'poison'], ['psychic', 'steel'], ['dark']],
  'bug': [['grass', 'psychic', 'dark'], ['fire', 'fighting', 'poison', 'flying', 'ghost', 'steel', 'fairy'], []],
  'rock': [['fire', 'ice', 'flying', 'bug'], ['fighting', 'ground', 'steel'], []],
  'ghost': [['psychic', 'ghost'], ['dark'], ['normal']],
  'dragon': [['dragon'], ['steel'], ['fairy']],
  'dark': [['psychic', 'ghost'], ['fighting', 'dark', 'fairy'], []],
  'steel': [['ice', 'rock', 'fairy'], ['fire', 'water', 'electric', 'steel'], []],
  'fairy': [['fighting', 'dragon', 'dark'], ['fire', 'poison', 'steel'], []],
};

/// Multiplicador de daño que recibe un Pokémon de los tipos [defending] por un
/// ataque de tipo [attacking].
double _typeMultiplier(String attacking, List<String> defending) {
  final row = _typeChart[attacking];
  if (row == null) return 1;
  var m = 1.0;
  for (final d in defending) {
    if (row[2].contains(d)) {
      return 0;
    } else if (row[0].contains(d)) {
      m *= 2;
    } else if (row[1].contains(d)) {
      m *= .5;
    }
  }
  return m;
}

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

  /// Ventana grande: todo el contenido centrado y con más aire.
  final bool expanded;
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
    this.expanded = false,
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
        crossAxisAlignment:
            widget.expanded ? CrossAxisAlignment.center : CrossAxisAlignment.start,
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
              alignment: widget.expanded ? WrapAlignment.center : WrapAlignment.start,
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

  bool get _c => widget.expanded;

  /// Debilidades, resistencias e inmunidades de una forma según sus tipos.
  Widget _matchups(ThemeData t, List<String> types) {
    final groups = <double, List<String>>{};
    for (final a in _typeChart.keys) {
      final m = _typeMultiplier(a, types);
      if (m != 1) groups.putIfAbsent(m, () => []).add(a);
    }
    const order = <(double, String)>[
      (4, 'Debilidad ×4'),
      (2, 'Debilidad ×2'),
      (.5, 'Resistencia ×½'),
      (.25, 'Resistencia ×¼'),
      (0, 'Inmunidad ×0'),
    ];
    final rows = <Widget>[];
    for (final (m, label) in order) {
      final list = groups[m];
      if (list == null || list.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: _c ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(label, style: t.textTheme.labelMedium),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              alignment: _c ? WrapAlignment.center : WrapAlignment.start,
              children: [for (final ty in list) TypeChip(ty)],
            ),
          ],
        ),
      ));
    }
    if (rows.isEmpty) {
      return Text('Recibe daño normal de todos los tipos.', style: t.textTheme.bodySmall);
    }
    return Column(
      crossAxisAlignment: _c ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _title(ThemeData t, String s) => Padding(
        padding: EdgeInsets.only(top: _c ? 24 : 16, bottom: 8),
        child: Text(s,
            textAlign: _c ? TextAlign.center : TextAlign.start,
            style: _c ? t.textTheme.titleMedium : t.textTheme.titleSmall),
      );

  Widget _fact(ThemeData t, String l, String v) => SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment:
              _c ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            Text(l, style: t.textTheme.labelSmall),
            Text(v,
                textAlign: _c ? TextAlign.center : TextAlign.start,
                style: t.textTheme.bodyMedium),
          ],
        ),
      );

  /// Habilidades. Ventana lateral: cuadrícula compacta, con la descripción al
  /// pasar el ratón. Ventana grande: tarjetas con la descripción visible.
  Widget _abilities(ThemeData t, VarietyInfo cur) {
    final names = widget.details?.abilities ?? const <String, String>{};
    final effects = widget.details?.abilityEffects ?? const <String, String>{};
    const missing =
        'Efecto no disponible. Actualiza la ficha con tools\\build_details.py.';
    Color roleColor(String role) => switch (role) {
          'Oculta' => Colors.deepPurple,
          'Principal' => t.colorScheme.primary,
          _ => Colors.teal,
        };
    final cards = <Widget>[];
    for (final (id, hidden) in cur.abilities) {
      final name = names[id] ?? id;
      final role = abilityRoleLabel(id, hidden);
      final color = roleColor(role);
      final effect = (widget.settings.spanish ? DescriptionsEs.ability(id) : null) ??
          effects[id] ??
          missing;
      if (_c) {
        cards.add(Container(
          width: 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: .55), width: 1.4),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  textAlign: TextAlign.center,
                  style: t.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(role,
                    style: TextStyle(
                        color: color, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 8),
              Text(effect,
                  textAlign: TextAlign.center, style: t.textTheme.bodySmall),
            ],
          ),
        ));
      } else {
        cards.add(Tooltip(
          waitDuration: const Duration(milliseconds: 250),
          preferBelow: false,
          constraints: const BoxConstraints(maxWidth: 320),
          message: effect,
          child: Container(
            width: 150,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: t.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: .55)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(role,
                    style: TextStyle(
                        color: color, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ));
      }
    }
    return Wrap(
      spacing: _c ? 12 : 8,
      runSpacing: _c ? 12 : 8,
      alignment: _c ? WrapAlignment.center : WrapAlignment.start,
      children: cards,
    );
  }

  /// Estadísticas efectivas de una forma (con los datos editados por el usuario).
  List<int> _effectiveStats(Species sp, VarietyInfo v) {
    final parsed = _varietyOverride(sp.dex, v.name, 'stats', v.stats.join(', '))
        .split(',')
        .map((x) => int.tryParse(x.trim()))
        .toList();
    return parsed.length == 6 && parsed.every((x) => x != null)
        ? parsed.cast<int>()
        : List<int>.from(v.stats);
  }

  /// Bloques de estadísticas: las formas con las mismas estadísticas que otra se
  /// agrupan en el primer bloque (la base); solo las distintas tienen el suyo.
  List<Widget> _statBlocks(ThemeData t, Species sp, List<VarietyInfo> vs) {
    const statNames = [
      'PS', 'Ataque', 'Defensa', 'At. Esp.', 'Def. Esp.', 'Velocidad'
    ];
    final groups = <String, (List<int>, List<VarietyInfo>)>{};
    for (final v in vs) {
      final stats = _effectiveStats(sp, v);
      groups.putIfAbsent(stats.join(','), () => (stats, <VarietyInfo>[])).$2.add(v);
    }
    Widget block((List<int>, List<VarietyInfo>) g) {
      final stats = g.$1;
      final total = stats.fold<int>(0, (a, b) => a + b);
      final label = groups.length > 1
          ? g.$2.map((v) => _varLabel(sp, v)).join(' · ')
          : null;
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _c ? 520 : double.infinity),
        child: Column(
          crossAxisAlignment:
              _c ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            if (label != null)
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 4),
                child: Text(label,
                    textAlign: _c ? TextAlign.center : TextAlign.start,
                    style: t.textTheme.labelLarge
                        ?.copyWith(color: t.colorScheme.primary)),
              ),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(
                      width: 78,
                      child: Text(statNames[i], style: t.textTheme.bodySmall)),
                  SizedBox(
                    width: 34,
                    child: Text('${stats[i]}',
                        textAlign: TextAlign.right,
                        style: t.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: (stats[i] / 255).clamp(0.0, 1.0).toDouble(),
                      minHeight: 8,
                      color: _statColor(stats[i]),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Total: $total', style: t.textTheme.labelLarge),
            ),
          ],
        ),
      );
    }

    return [for (final g in groups.values) block(g)];
  }

  List<Widget> _sections(BuildContext context, SpeciesInfo info) {
    final t = Theme.of(context);
    final sp = widget.gs.species;
    final ids = widget.gs.entries.map((e) => e.id).toSet();
    final vs = info.varieties
        .where((v) => v.isDefault || ids.contains(v.name))
        .toList();
    final cur =
        vs.firstWhere((v) => v.name == variety, orElse: () => vs.first);
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
            alignment: _c ? WrapAlignment.center : WrapAlignment.start,
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
      if (genus.isNotEmpty)
        Text(genus,
            textAlign: _c ? TextAlign.center : TextAlign.start,
            style: t.textTheme.titleSmall),
      const SizedBox(height: 6),
      Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: _c ? WrapAlignment.center : WrapAlignment.start,
          children: [
        for (final ty in cur.types) TypeChip(ty),
      ]),
      if (description.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(description,
              textAlign: _c ? TextAlign.center : TextAlign.start,
              style: t.textTheme.bodySmall
                  ?.copyWith(fontStyle: FontStyle.italic)),
        ),
      _title(t, 'Datos'),
      Wrap(
          spacing: 12,
          runSpacing: 10,
          alignment: _c ? WrapAlignment.center : WrapAlignment.start,
          children: [
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
      _title(t, 'Debilidades y resistencias'),
      _matchups(t, cur.types),
      _title(t, 'Habilidades'),
      _abilities(t, cur),
      _title(t, 'Estadísticas base'),
      ..._statBlocks(t, sp, vs),
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
    return EvolutionChart(
      tree: tree,
      currentDex: widget.gs.species.dex,
      byDex: widget.byDex,
      settings: widget.settings,
    );
  }

  /// Juegos en los que está disponible la forma seleccionada.
  List<Widget> _where(ThemeData t, VarietyInfo cur) => [
        _title(t, 'Juegos en los que está disponible'),
        AvailableGames(
          species: widget.gs.species,
          variety: cur.name,
          isDefault: cur.isDefault,
          center: _c,
        ),
      ];
}

class TypeChip extends StatelessWidget {
  final String type;
  const TypeChip(this.type);

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
