import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boxes.dart';
import 'boxes_screen.dart';
import 'data_actions.dart';
import 'detail.dart';
import 'details.dart';
import 'game_store.dart';
import 'games_sidebar.dart';
import 'models.dart';
import 'profiles.dart';
import 'profiles_screen.dart';
import 'progress.dart';
import 'settings.dart';
import 'settings_drawer.dart';
import 'widgets.dart';

enum DexFilter { all, missing, missingShiny, complete }

const _filterLabels = {
  DexFilter.all: 'Todos',
  DexFilter.missing: 'Faltan normales',
  DexFilter.missingShiny: 'Faltan ✨',
  DexFilter.complete: 'Completos',
};

class HomeScreen extends StatefulWidget {
  final List<Game> games;
  final GameStore store;
  final Progress progress;
  final AppSettings settings;
  final DexDetails? details;
  final Map<int, Species> byDex;
  final BoxStore boxes;
  final EntryIndex entryIndex;
  final ProfileStore profiles;
  const HomeScreen({
    super.key,
    required this.games,
    required this.store,
    required this.progress,
    required this.settings,
    required this.details,
    required this.byDex,
    required this.boxes,
    required this.entryIndex,
    required this.profiles,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  String query = '';
  int gen = 0;
  DexFilter filter = DexFilter.all;
  GameSpecies? selected;
  bool leftOpen = true;
  bool rightOpen = true;
  late String _gameId =
      widget.games.any((g) => g.id == widget.settings.lastGame)
          ? widget.settings.lastGame
          : widget.games.first.id;

  /// Pokédex abierta. Se busca por id para que siga bien al renombrarla y para
  /// volver a HOME si se elimina.
  Game get game => widget.games.firstWhere((g) => g.id == _gameId,
      orElse: () => widget.games.first);

  Progress get p => widget.progress;
  AppSettings get st => widget.settings;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _export() => exportProgress(context, p);

  Future<void> _import() => importProgress(context, p);

  /// Perfil activo y, si los hay, nombre e ID de entrenador en este juego.
  String _trainerLine() {
    final pr = widget.profiles.active;
    final gp = pr.games[game.id];
    return [
      pr.name,
      if (gp != null && gp.name.isNotEmpty) gp.name,
      if (gp != null && gp.tid.isNotEmpty) 'ID ${gp.tid}',
    ].join(' · ');
  }

  void _openBoxes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BoxesScreen(
          game: game,
          games: widget.games,
          store: widget.boxes,
          entryIndex: widget.entryIndex,
          settings: st,
        ),
      ),
    );
  }

  void _selectGame(Game g) {
    setState(() {
      _gameId = g.id;
      selected = null;
      rightOpen = false;
      if (!g.shiny && filter == DexFilter.missingShiny) filter = DexFilter.all;
    });
    st.update(() => st.lastGame = g.id);
  }

  void _open(GameSpecies gs, bool wide) {
    setState(() {
      selected = gs;
      rightOpen = true;
    });
  }

  Future<void> _openFullscreen(GameSpecies gs) async {
    setState(() {
      selected = gs;
      rightOpen = true;
    });
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Dialog.fullscreen(
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.escape): () => Navigator.of(dialogContext).pop(),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
          appBar: AppBar(
            title: Text(gs.species.displayName(st.spanish)),
            leading: IconButton(
              tooltip: 'Cerrar (Esc)',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ),
          body: DetailView(
            game: game,
            gs: gs,
            progress: p,
            settings: st,
            games: widget.games,
            details: widget.details,
            byDex: widget.byDex,
          ),
            ),
          ),
        ),
      ),
    );
  }

  (int, int) _counts(GameSpecies gs) => (
        p.count(game, gs.entries),
        game.shiny ? p.count(game, gs.entries, shiny: true) : 0,
      );

  double _ratio(GameSpecies gs) {
    final (n, sh) = _counts(gs);
    final t = gs.entries.length;
    return t == 0 ? 0 : (n + sh) / ((game.shiny ? 2 : 1) * t);
  }

  String _label(GameSpecies gs) {
    final (n, sh) = _counts(gs);
    final t = gs.entries.length;
    return game.shiny ? '$n/$t  ·  ✨ $sh/$t' : '$n/$t';
  }

  List<GameSpecies> _filtered() {
    final q = query.trim().toLowerCase();
    return game.species.where((gs) {
      final s = gs.species;
      if (gen != 0 && s.gen != gen) return false;
      if (q.isNotEmpty &&
          !(s.nameEs.toLowerCase().contains(q) ||
              s.name.contains(q) ||
              '${gs.no}' == q ||
              '${s.dex}' == q)) {
        return false;
      }
      final t = gs.entries.length;
      final (n, sh) = _counts(gs);
      return switch (filter) {
        DexFilter.all => true,
        DexFilter.missing => n < t,
        DexFilter.missingShiny => game.shiny && sh < t,
        DexFilter.complete => n == t && (!game.shiny || sh == t),
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([p, st, widget.profiles, widget.store]),
      builder: (context, _) {
        final list = _filtered();
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
                _searchFocus.requestFocus(),
            const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
                _scaffoldKey.currentState?.openEndDrawer(),
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (selected != null || rightOpen) {
                setState(() { selected = null; rightOpen = false; });
              }
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              key: _scaffoldKey,
              endDrawer: SettingsDrawer(
                  settings: st, onExport: _export, onImport: _import),
              body: SafeArea(
                child: LayoutBuilder(
                  builder: (context, c) {
                    final showRight = selected != null && rightOpen;
                    final sideBudget = (c.maxWidth - 360).clamp(0.0, c.maxWidth).toDouble();
                    final leftLimit = showRight ? sideBudget * 0.45 : sideBudget;
                    final leftWidth = leftOpen
                        ? st.leftSidebarWidth.clamp(0.0, leftLimit).toDouble()
                        : 0.0;
                    final rightLimit = (sideBudget - leftWidth).clamp(0.0, sideBudget).toDouble();
                    final rightWidth = showRight
                        ? st.rightSidebarWidth.clamp(0.0, rightLimit).toDouble()
                        : 0.0;
                    return Row(
                      children: [
                        if (leftOpen && leftWidth > 1) ...[
                          SizedBox(
                            width: leftWidth,
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surfaceContainerLow,
                              child: GameList(
                                store: widget.store,
                                current: game,
                                progress: p,
                                onSelect: _selectGame,
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                        ],
                        Expanded(child: _browse(list, true, leftOpen)),
                        if (showRight && rightWidth > 1) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: rightWidth,
                            child: Column(
                              children: [
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: 'Cerrar panel (Esc)',
                                    icon: const Icon(Icons.close),
                                    onPressed: () => setState(() { selected = null; rightOpen = false; }),
                                  ),
                                ),
                                Expanded(
                                  child: DetailView(
                                    game: game,
                                    gs: selected!,
                                    progress: p,
                                    settings: st,
                                    games: widget.games,
                                    details: widget.details,
                                    byDex: widget.byDex,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _browse(List<GameSpecies> list, bool wide, bool sidebar) {
    final theme = Theme.of(context);
    final all = game.allEntries;
    final total = all.length;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(sidebar ? 16 : 8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Menú principal',
                icon: const Icon(Icons.home_outlined),
                onPressed: () => Navigator.maybePop(context),
              ),
              IconButton(
                tooltip: leftOpen ? 'Ocultar lateral izquierdo' : 'Mostrar lateral izquierdo',
                icon: const Icon(Icons.menu),
                onPressed: () => setState(() => leftOpen = !leftOpen),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.name,
                        style: theme.textTheme.titleLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(_trainerLine(),
                        style: theme.textTheme.labelMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Tooltip(
                message: widget.profiles.active.name,
                child: ProfileAvatar(
                  profile: widget.profiles.active,
                  entryIndex: widget.entryIndex,
                  size: 32,
                  pixel: st.pixelSprites,
                  threeD: st.threeDSprites,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Buscar por nombre o nº (Ctrl+F)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => query = '');
                            },
                          ),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              SegmentedButton<ViewMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                      value: ViewMode.grid,
                      icon: Icon(Icons.grid_view),
                      tooltip: 'Cuadrícula'),
                  ButtonSegment(
                      value: ViewMode.list,
                      icon: Icon(Icons.view_list),
                      tooltip: 'Lista'),
                ],
                selected: {st.viewMode},
                onSelectionChanged: (s) =>
                    st.update(() => st.viewMode = s.first),
              ),
              FilledButton.tonalIcon(
                onPressed: _openBoxes,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Cajas'),
              ),
              IconButton.filledTonal(
                tooltip: 'Opciones (Ctrl+,)',
                icon: const Icon(Icons.settings),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                  child: _Bar(game.shiny ? 'Normales' : 'Registrados',
                      p.count(game, all), total)),
              if (game.shiny) ...[
                const SizedBox(width: 24),
                Expanded(
                    child: _Bar('✨ Variocolor',
                        p.count(game, all, shiny: true), total)),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var g = 0; g <= 9; g++)
                ChoiceChip(
                  label: Text(g == 0 ? 'Todas' : 'Gen $g'),
                  selected: gen == g,
                  onSelected: (_) => setState(() => gen = g),
                ),
              const SizedBox(width: 12),
              for (final f in DexFilter.values)
                if (f != DexFilter.missingShiny || game.shiny)
                  ChoiceChip(
                    label: Text(_filterLabels[f]!),
                    selected: filter == f,
                    onSelected: (_) => setState(() => filter = f),
                  ),
            ],
          ),
        ),
        Expanded(
          child: list.isEmpty
              ? const Center(child: Text('Sin resultados'))
              : st.viewMode == ViewMode.grid
                  ? _grid(list, wide)
                  : _list(list, wide),
        ),
      ],
    );
  }

  Widget _grid(List<GameSpecies> list, bool wide) {
    final sz = st.spriteSize;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: sz + 56,
        mainAxisExtent: sz + 32 + 56 * st.textScale,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) => _card(list[i], wide),
    );
  }

  Widget _card(GameSpecies gs, bool wide) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sel = wide && identical(gs, selected);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: sel ? scheme.primary : scheme.outlineVariant,
          width: sel ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _open(gs, wide),
        onDoubleTap: () => _openFullscreen(gs),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Sprite(gs.entries.first.sprite,
                  size: st.spriteSize, pixel: st.pixelSprites,
                  threeD: st.threeDSprites),
              Text(dexNumber(game, gs), style: theme.textTheme.labelSmall),
              Text(
                gs.species.displayName(st.spanish),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(_label(gs), style: theme.textTheme.labelSmall),
              const Spacer(),
              LinearProgressIndicator(value: _ratio(gs), minHeight: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<GameSpecies> list, bool wide) {
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (_, i) {
        final gs = list[i];
        return InkWell(
          onTap: () => _open(gs, wide),
          onDoubleTap: () => _openFullscreen(gs),
          child: ListTile(
          selected: identical(gs, selected),
          leading: Sprite(gs.entries.first.sprite,
              size: st.spriteSize.clamp(40.0, 64.0).toDouble(),
              pixel: st.pixelSprites,
                  threeD: st.threeDSprites),
          title: Text(
              '${dexNumber(game, gs)}  ${gs.species.displayName(st.spanish)}'),
          subtitle: Text(_label(gs)),
          trailing: SizedBox(
            width: 90,
            child: LinearProgressIndicator(value: _ratio(gs), minHeight: 4),
          ),
          ),
        );
      },
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int done, total;
  const _Bar(this.label, this.done, this.total);

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0 : (done * 100 / total).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label   $done/$total  ($pct%)'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: total == 0 ? 0 : done / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }
}
