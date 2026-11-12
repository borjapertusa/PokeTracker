import 'package:flutter/material.dart';

import 'balls.dart';
import 'boxes.dart';
import 'models.dart';
import 'settings.dart';
import 'widgets.dart';

class _SlotRef {
  final int box, slot;
  const _SlotRef(this.box, this.slot);
}

/// Cajas simuladas (5 filas x 6 columnas) para ordenar Pokémon de un juego.
class BoxesScreen extends StatefulWidget {
  final Game game;
  final List<Game> games;
  final BoxStore store;
  final EntryIndex entryIndex;
  final AppSettings settings;
  const BoxesScreen({
    super.key,
    required this.game,
    required this.games,
    required this.store,
    required this.entryIndex,
    required this.settings,
  });

  @override
  State<BoxesScreen> createState() => _BoxesScreenState();
}

class _BoxesScreenState extends State<BoxesScreen> {
  int cur = 0;

  BoxStore get store => widget.store;
  Game get game => widget.game;

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<bool> _confirm(String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true), child: Text(ok)),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _rename(int i, String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambiar nombre de la caja'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 30,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (name != null) store.rename(game.id, i, name);
  }

  Future<void> _pick(int b, int s, bool filled) async {
    final v = await showDialog<String>(
      context: context,
      builder: (_) => PokemonPickerDialog(
        game: game,
        games: widget.games,
        filled: filled,
        settings: widget.settings,
        showBalls: true,
        currentValue: store.boxesOf(game.id)[b].slots[s],
      ),
    );
    if (v == null) return;
    store.setSlot(game.id, b, s, v.isEmpty ? null : v);
  }

  Future<void> _fill() async {
    final n = game.uniqueSpecies.length;
    final boxes = (n / boxSize).ceil();
    final ok = await _confirm(
      'Rellenar con la Pokédex',
      'Se reemplazarán TODAS las cajas de ${game.name} por los $n Pokémon de su Pokédex '
          '(forma base) en orden, en $boxes cajas de $boxSize. Después podrás reordenarlos.',
      'Rellenar',
    );
    if (!ok) return;
    store.fill(game.id, [for (final gs in game.uniqueSpecies) gs.entries.first.id]);
    setState(() => cur = 0);
  }

  Future<void> _menu(String action, List<DexBox> boxes) async {
    switch (action) {
      case 'clear':
        store.clearBox(game.id, cur);
      case 'left':
        if (cur > 0) {
          store.moveBox(game.id, cur, -1);
          setState(() => cur -= 1);
        }
      case 'right':
        if (cur < boxes.length - 1) {
          store.moveBox(game.id, cur, 1);
          setState(() => cur += 1);
        }
      case 'delete':
        final ok = await _confirm(
          'Eliminar caja',
          'Se eliminará "${boxes[cur].name}" y los Pokémon que contiene.',
          'Eliminar',
        );
        if (ok) {
          store.removeBox(game.id, cur);
          setState(() => cur = 0);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, widget.settings]),
      builder: (context, _) {
        final boxes = store.boxesOf(game.id);
        if (cur >= boxes.length) cur = boxes.length - 1;
        return Scaffold(
          appBar: AppBar(
            title: Text('Cajas · ${game.name}'),
            actions: [
              IconButton(
                tooltip: 'Rellenar con la Pokédex',
                icon: const Icon(Icons.auto_fix_high),
                onPressed: _fill,
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, c) {
              final main = _boxView(boxes, boxes[cur]);
              if (c.maxWidth >= 800) {
                return Row(
                  children: [
                    SizedBox(width: 240, child: _rail(boxes)),
                    const VerticalDivider(width: 1),
                    Expanded(child: main),
                  ],
                );
              }
              return Column(
                children: [
                  SizedBox(height: 60, child: _strip(boxes)),
                  const Divider(height: 1),
                  Expanded(child: main),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// Zona donde soltar un Pokémon arrastrado para pasarlo a otra caja.
  Widget _dropOnBox(
      List<DexBox> boxes, int i, Widget Function(bool hover) build) {
    return DragTarget<_SlotRef>(
      onWillAcceptWithDetails: (d) => d.data.box != i,
      onAcceptWithDetails: (d) {
        if (!store.moveToBox(game.id, d.data.box, d.data.slot, i)) {
          _snack('"${boxes[i].name}" está llena');
        }
      },
      builder: (context, cand, _) => build(cand.isNotEmpty),
    );
  }

  Widget _rail(List<DexBox> boxes) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: boxes.length,
            itemBuilder: (_, i) => _dropOnBox(
              boxes,
              i,
              (hover) => ListTile(
                selected: i == cur,
                tileColor: hover ? scheme.primaryContainer : null,
                title: Text(boxes[i].name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${boxes[i].filled}/$boxSize'),
                onTap: () => setState(() => cur = i),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.tonalIcon(
            onPressed: () {
              store.addBox(game.id);
              setState(() => cur = store.boxesOf(game.id).length - 1);
            },
            icon: const Icon(Icons.add),
            label: const Text('Añadir caja'),
          ),
        ),
      ],
    );
  }

  Widget _strip(List<DexBox> boxes) {
    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      children: [
        for (var i = 0; i < boxes.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _dropOnBox(
              boxes,
              i,
              (hover) => ChoiceChip(
                label: Text('${boxes[i].name} (${boxes[i].filled})'),
                selected: i == cur,
                backgroundColor: hover
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                onSelected: (_) => setState(() => cur = i),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Añadir caja',
          icon: const Icon(Icons.add),
          onPressed: () {
            store.addBox(game.id);
            setState(() => cur = store.boxesOf(game.id).length - 1);
          },
        ),
      ],
    );
  }

  Widget _boxView(List<DexBox> boxes, DexBox box) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - 32 - gap * (boxCols - 1)) / boxCols;
        final h = (c.maxHeight - 110 - gap * (boxRows - 1)) / boxRows;
        final cell = (w < h ? w : h).clamp(56.0, 120.0).toDouble();
        final width = cell * boxCols + gap * (boxCols - 1);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(box.name,
                            style: theme.textTheme.titleLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      Text('${box.filled}/$boxSize',
                          style: theme.textTheme.labelLarge),
                      IconButton(
                        tooltip: 'Cambiar nombre',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _rename(cur, box.name),
                      ),
                      PopupMenuButton<String>(
                        tooltip: 'Más opciones',
                        onSelected: (a) => _menu(a, boxes),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'clear', child: Text('Vaciar caja')),
                          PopupMenuItem(
                              value: 'left',
                              enabled: cur > 0,
                              child: const Text('Mover caja a la izquierda')),
                          PopupMenuItem(
                              value: 'right',
                              enabled: cur < boxes.length - 1,
                              child: const Text('Mover caja a la derecha')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('Eliminar caja')),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  for (var r = 0; r < boxRows; r++)
                    Padding(
                      padding: EdgeInsets.only(bottom: r < boxRows - 1 ? gap : 0),
                      child: Row(
                        children: [
                          for (var k = 0; k < boxCols; k++) ...[
                            if (k > 0) const SizedBox(width: gap),
                            _slot(boxes, cur, r * boxCols + k, cell),
                          ],
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Pulsa un hueco para elegir Pokémon. Arrastra para reordenar; '
                    'suéltalo sobre otra caja de la lista para moverlo allí.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _slot(List<DexBox> boxes, int b, int s, double cell) {
    final scheme = Theme.of(context).colorScheme;
    final spanish = widget.settings.spanish;
    final pixel = widget.settings.pixelSprites;
    final v = boxes[b].slots[s];
    final data = v == null ? null : parseSlot(v);
    final mon = data == null ? null : widget.entryIndex[data.id];
    final shiny = data?.shiny ?? false;
    final ball = data?.ball;
    final path = mon == null
        ? null
        : (shiny ? (mon.$2.shiny ?? mon.$2.sprite) : mon.$2.sprite);

    Widget content(bool hover) => Container(
          width: cell,
          height: cell,
          decoration: BoxDecoration(
            color: hover
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: hover ? scheme.primary : scheme.outlineVariant),
          ),
          child: v == null
              ? Icon(Icons.add, color: scheme.outline)
              : mon == null
                  ? const Icon(Icons.help_outline)
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        Sprite(path, size: cell * 0.86, pixel: pixel, threeD: widget.settings.threeDSprites),
                        if (shiny)
                          const Positioned(
                              top: 2,
                              right: 4,
                              child: Text('✨', style: TextStyle(fontSize: 12))),
                        if (ball != null)
                          Positioned(
                              bottom: 1,
                              left: 2,
                              child: BallIcon(ball, size: cell * 0.3)),
                      ],
                    ),
        );

    return DragTarget<_SlotRef>(
      onWillAcceptWithDetails: (d) => !(d.data.box == b && d.data.slot == s),
      onAcceptWithDetails: (d) =>
          store.swap(game.id, d.data.box, d.data.slot, b, s),
      builder: (context, cand, _) {
        final tap = InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _pick(b, s, v != null),
          child: content(cand.isNotEmpty),
        );
        final tipped = mon == null
            ? tap
            : Tooltip(
                message: _tip(mon.$1, mon.$2, shiny, spanish) +
                    (ballById(ball) == null
                        ? ''
                        : '\nCapturado en ${spanish ? ballById(ball)!.es : ballById(ball)!.en}'),
                waitDuration: const Duration(milliseconds: 400),
                child: tap,
              );
        return Draggable<_SlotRef>(
          data: _SlotRef(b, s),
          maxSimultaneousDrags: v == null ? 0 : 1,
          feedback: Material(
            color: Colors.transparent,
            child: Opacity(
              opacity: 0.85,
              child: Sprite(path, size: cell * 0.9, pixel: pixel, threeD: widget.settings.threeDSprites),
            ),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: content(false)),
          child: tipped,
        );
      },
    );
  }

  String _tip(Species s, DexEntry e, bool shiny, bool spanish) {
    final form = e.label == 'Base' ? '' : ' · ${e.label}';
    final g = e.gender == 'female'
        ? ' ♀'
        : e.gender == 'male'
            ? ' ♂'
            : '';
    return '${s.displayName(spanish)}$g$form${shiny ? ' ✨' : ''}';
  }
}

/// Selector de Pokémon para un hueco. Devuelve 'id' o 'id|s' (variocolor);
/// '' = quitar el Pokémon del hueco; null = cancelar.
class PokemonPickerDialog extends StatefulWidget {
  final Game game;
  final List<Game> games;
  final bool filled;
  final AppSettings settings;
  final String title;
  final String removeLabel;

  /// Muestra el desplegable de balls y devuelve el hueco con la ball elegida.
  final bool showBalls;

  /// Contenido actual del hueco (si se está editando uno ya ocupado).
  final String? currentValue;
  const PokemonPickerDialog({
    super.key,
    required this.game,
    required this.games,
    required this.filled,
    required this.settings,
    this.title = 'Elegir Pokémon',
    this.removeLabel = 'Quitar de la caja',
    this.showBalls = false,
    this.currentValue,
  });

  @override
  State<PokemonPickerDialog> createState() => _PokemonPickerDialogState();
}

class _PokemonPickerDialogState extends State<PokemonPickerDialog> {
  String query = '';
  bool all = false;
  bool shiny = false;
  late String? ball = widget.currentValue == null ? null : parseSlot(widget.currentValue!).ball;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final game = widget.game;
    final spanish = widget.settings.spanish;
    final home = widget.games.firstWhere((g) => g.id == 'home');
    final src = all ? home.species : game.species;
    final q = query.trim().toLowerCase();
    final items = <(Species, DexEntry)>[];
    for (final gs in src) {
      final s = gs.species;
      final hit = q.isEmpty ||
          s.nameEs.toLowerCase().contains(q) ||
          s.name.contains(q) ||
          '${s.dex}' == q ||
          '${gs.no}' == q;
      for (final e in gs.entries) {
        if (hit || e.label.toLowerCase().contains(q)) items.add((s, e));
      }
    }
    final canShiny = game.shiny || all;
    final useShiny = shiny && canShiny;
    // Variocolor disponible según la lista que se está viendo (HOME o el juego).
    final shinyGame = all ? home : game;

    return Dialog(
      child: SizedBox(
        width: 760,
        height: 600,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                      child: Text(widget.title,
                          style: theme.textTheme.titleLarge)),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Nombre, forma o nº',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => query = v),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Switch(
                        value: all,
                        onChanged: (v) => setState(() => all = v)),
                    const Text('Todos los Pokémon'),
                  ]),
                  if (canShiny)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                          value: shiny,
                          onChanged: (v) => setState(() => shiny = v)),
                      const Text('✨ Variocolor'),
                    ]),
                  if (widget.filled)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(context, ''),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(widget.removeLabel),
                    ),
                ],
              ),
              if (widget.showBalls) ...[
                const SizedBox(height: 8),
                Row(children: [
                  SizedBox(
                    width: 300,
                    child: BallDropdown(
                      value: ball,
                      spanish: spanish,
                      onChanged: (v) => setState(() => ball = v),
                    ),
                  ),
                  if (widget.currentValue != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.check),
                      label: const Text('Guardar solo la ball'),
                      onPressed: () {
                        final d = parseSlot(widget.currentValue!);
                        Navigator.pop(context, encodeSlot(d.id, d.shiny, ball));
                      },
                    ),
                  ],
                ]),
              ],
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Sin resultados'))
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 104,
                          mainAxisExtent: 116,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final (s, e) = items[i];
                          final asShiny = useShiny && shinyGame.shinyFor(e);
                          final path =
                              asShiny ? (e.shiny ?? e.sprite) : e.sprite;
                          final g = e.gender == 'female'
                              ? ' ♀'
                              : e.gender == 'male'
                                  ? ' ♂'
                                  : '';
                          final form =
                              e.label == 'Base' ? '' : ' · ${e.label}';
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(
                                context,
                                widget.showBalls
                                    ? encodeSlot(e.id, asShiny, ball)
                                    : '${e.id}${asShiny ? '|s' : ''}'),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Column(
                                children: [
                                  Sprite(path,
                                      size: 64,
                                      pixel: widget.settings.pixelSprites,
                                      threeD: widget.settings.threeDSprites),
                                  Text(
                                    '${s.displayName(spanish)}$g$form',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
