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
            AppBar(title: Text(gs.species.displayName(settings.spanish))),
        body: DetailView(
            game: game,
            gs: gs,
            progress: progress,
            settings: settings,
            games: games,
            details: details,
            byDex: byDex),
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
  const DetailView({
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([progress, settings]),
      builder: (context, _) {
        final es = gs.entries;
        final t = es.length;
        final sz = settings.spriteSize.clamp(64.0, 128.0).toDouble();
        final n = progress.count(game, es);
        final sh = progress.count(game, es, shiny: true);
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${dexNumber(game, gs)}  ${gs.species.displayName(settings.spanish)}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(game.name, style: theme.textTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    game.shiny
                        ? 'Normales $n/$t  ·  ✨ $sh/$t'
                        : 'Registrados $n/$t',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => progress.setAll(game, es,
                            shiny: false, value: true),
                        child: Text(
                            game.shiny ? 'Todos normales' : 'Marcar todos'),
                      ),
                      if (game.shiny)
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
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: game.shiny ? sz * 2 + 56 : sz + 56,
                  mainAxisExtent: sz + 72 + 56 * settings.textScale,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => EntryCard(
                    game: game,
                    entry: es[i],
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
              child: PokemonInfo(
                game: game,
                games: games,
                gs: gs,
                details: details,
                byDex: byDex,
                settings: settings,
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
  final Progress progress;
  final double size;
  final bool pixel;
  final bool threeD;
  const EntryCard({
    super.key,
    required this.game,
    required this.entry,
    required this.progress,
    required this.size,
    required this.pixel,
    this.threeD = false,
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
        onTap: () => progress.toggle(key, shiny: shiny),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Sprite(url, size: size, pixel: pixel, threeD: threeD),
            Checkbox(
              value: progress.has(key, shiny: shiny),
              onChanged: (_) => progress.toggle(key, shiny: shiny),
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
                if (game.shiny) _half(entry.shiny, true),
              ]),
            ],
          ),
        ),
      );
}
