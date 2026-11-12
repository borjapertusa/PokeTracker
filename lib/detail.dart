import 'package:flutter/material.dart';

import 'details.dart';
import 'info.dart';
import 'models.dart';
import 'progress.dart';
import 'settings.dart';
import 'widgets.dart';

String dexNumber(Game game, GameSpecies gs) =>
    '#${gs.no.toString().padLeft(game.id == 'home' ? 4 : 3, '0')}';

/// Pantalla completa de detalle (se usa cuando la ventana es estrecha).
class DetailScreen extends StatelessWidget {
  final Game game;
  final GameSpecies gs;
  final Progress progress;
  final AppSettings settings;
  final List<Game> games;
  final DexDetails? details;
  final Map<int, Species> byDex;
  const DetailScreen({
    super.key,
    required this.games,
    required this.details,
    required this.byDex,
    required this.game,
    required this.gs,
    required this.progress,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar:
            AppBar(title: Text(gs.displayName(settings.spanish))),
        body: DetailView(
            game: game,
            gs: gs,
            progress: progress,
            settings: settings,
            games: games,
            details: details,
            byDex: byDex,
            showLocations: true),
      );
}

/// Contenido del detalle: se usa como panel lateral en ventanas anchas.
class DetailView extends StatelessWidget {
  final Game game;
  final GameSpecies gs;
  final Progress progress;
  final AppSettings settings;
  final List<Game> games;
  final DexDetails? details;
  final Map<int, Species> byDex;
  final bool showLocations;
  final bool showMoves;

  /// Ventana grande (doble clic): contenido centrado y sprites ampliables.
  final bool expanded;
  const DetailView({
    super.key,
    required this.games,
    required this.details,
    required this.byDex,
    required this.game,
    required this.gs,
    required this.progress,
    required this.settings,
    this.showLocations = false,
    this.showMoves = false,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([progress, settings]),
      builder: (context, _) {
        final es = gs.entries;
        final t = es.length;
        final sz = settings.spriteSize.clamp(64.0, 128.0).toDouble() * (expanded ? 1.3 : 1.0);
        final n = progress.count(game, es);
        final sh = progress.count(game, es, shiny: true);
        final shT = game.shinyTotal(es); // entradas con variocolor registrable
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment:
                    expanded ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dexNumber(game, gs)}  ${gs.displayName(settings.spanish)}',
                    textAlign: expanded ? TextAlign.center : TextAlign.start,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Row(mainAxisSize: MainAxisSize.min, children: [GameIcon(game, size: 34), const SizedBox(width: 8), Flexible(child: Text(game.name, style: theme.textTheme.labelMedium))]),
                  const SizedBox(height: 4),
                  Text(
                    game.shiny
                        ? (shT > 0
                            ? 'Normales $n/$t  ·  ✨ $sh/$shT'
                            : 'Normales $n/$t')
                        : 'Registrados $n/$t',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: expanded ? WrapAlignment.center : WrapAlignment.start,
                    children: [
                      OutlinedButton(
                        onPressed: () => progress.setAll(game, es,
                            shiny: false, value: true),
                        child: Text(
                            game.shiny ? 'Todos normales' : 'Marcar todos'),
                      ),
                      if (shT > 0)
                        OutlinedButton(
                          onPressed: () => progress.setAll(game, es,
                              shiny: true, value: true),
                          child: const Text('Todos ✨'),
                        ),
                      TextButton(
                        onPressed: () {
                          progress.setAll(game, es,
                              shiny: false, value: false);
                          progress.setAll(game, es,
                              shiny: true, value: false);
                        },
                        child: const Text('Limpiar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
            if (expanded)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final entry in es)
                        SizedBox(
                          width: shT > 0 ? sz * 2 + 80 : sz + 80,
                          height: sz + 100 + 56 * settings.textScale,
                          child: EntryCard(
                            game: game,
                            entry: entry,
                            species: gs.species,
                            progress: progress,
                            size: sz,
                            pixel: settings.pixelSprites,
                            threeD: settings.threeDSprites,
                            onZoom: (shiny) => showSpriteZoom(context,
                                game: game,
                                entry: entry,
                                settings: settings,
                                shiny: shiny),
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: shT > 0 ? sz * 2 + 80 : sz + 80,
                  mainAxisExtent: sz + 100 + 56 * settings.textScale,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => EntryCard(
                    game: game,
                    entry: es[i],
                    species: gs.species,
                    progress: progress,
                    size: sz,
                    pixel: settings.pixelSprites,
                    threeD: settings.threeDSprites,
                  ),
                  childCount: t,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: expanded ? 1100 : double.infinity),
                  child: PokemonInfo(
                    game: game,
                    games: games,
                    gs: gs,
                    details: details,
                    byDex: byDex,
                    settings: settings,
                    showLocations: showLocations,
                    showMoves: showMoves,
                    expanded: expanded,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class EntryCard extends StatelessWidget {
  final Game game;
  final DexEntry entry;
  final Species species;
  final Progress progress;
  final double size;
  final bool pixel;
  final bool threeD;

  /// Si se indica, cada sprite muestra una lupa que lo abre ampliado
  /// (parámetro: true = variocolor).
  final void Function(bool shiny)? onZoom;
  const EntryCard({
    super.key,
    required this.game,
    required this.entry,
    required this.species,
    required this.progress,
    required this.size,
    required this.pixel,
    this.threeD = false,
    this.onZoom,
  });

  static const _kinds = {
    'mega': 'Mega',
    'gmax': 'Gigamax',
    'regional': 'Regional',
    'cosmetic': 'Cosmética',
    'other': 'Otra forma',
  };

  String get _title =>
      entry.label +
      (game.genders
          ? switch (entry.gender) {
              'male' => ' ♂',
              'female' => ' ♀',
              _ => '',
            }
          : '');

  Widget _half(String? url, bool shiny) {
    final key = game.key(entry);
    return Expanded(
      child: InkWell(
        onTap: () => progress.toggleEntry(game, species, entry, shiny: shiny),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            onZoom == null
                ? Sprite(url, size: size, pixel: pixel, threeD: threeD)
                : Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Sprite(url, size: size, pixel: pixel, threeD: threeD),
                      Tooltip(
                        message: 'Ampliar',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => onZoom!(shiny),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.zoom_in, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
            Checkbox(
              value: progress.has(key, shiny: shiny),
              onChanged: (_) => progress.toggleEntry(game, species, entry, shiny: shiny),
            ),
            Text(shiny ? '✨ Variocolor' : (game.shiny ? 'Normal' : 'Registrado'),
                style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Text(_title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleSmall),
              if (_kinds[entry.kind] != null)
                Text(_kinds[entry.kind]!, style: const TextStyle(fontSize: 11)),
              const Spacer(),
              Row(children: [
                _half(entry.sprite, false),
                // Sin variocolor disponible no se muestra ni la imagen ni la casilla.
                if (game.shinyFor(entry)) _half(entry.shiny, true),
              ]),
            ],
          ),
        ),
      );
}


/// Sprite ampliado (forma normal o variocolor) en una ventana.
Future<void> showSpriteZoom(
  BuildContext context, {
  required Game game,
  required DexEntry entry,
  required AppSettings settings,
  bool shiny = false,
}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _SpriteZoom(
          game: game, entry: entry, settings: settings, startShiny: shiny),
    );

class _SpriteZoom extends StatefulWidget {
  final Game game;
  final DexEntry entry;
  final AppSettings settings;
  final bool startShiny;
  const _SpriteZoom({
    required this.game,
    required this.entry,
    required this.settings,
    required this.startShiny,
  });

  @override
  State<_SpriteZoom> createState() => _SpriteZoomState();
}

class _SpriteZoomState extends State<_SpriteZoom> {
  late bool _shiny = widget.startShiny && widget.game.shinyFor(widget.entry);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final e = widget.entry;
    final canShiny = widget.game.shinyFor(e);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Expanded(
                    child: Text(e.label,
                        style: t.textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis)),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]),
              const SizedBox(height: 8),
              Sprite(_shiny ? e.shiny : e.sprite,
                  size: 340,
                  pixel: widget.settings.pixelSprites,
                  threeD: widget.settings.threeDSprites),
              if (canShiny) ...[
                const SizedBox(height: 12),
                SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: false, label: Text('Normal')),
                    ButtonSegment(value: true, label: Text('✨ Variocolor')),
                  ],
                  selected: {_shiny},
                  onSelectionChanged: (s) => setState(() => _shiny = s.first),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
