import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'boxes.dart';
import 'boxes_screen.dart';
import 'data_actions.dart';
import 'web_export.dart';
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
  // Número de columnas real del grid, recalculado al cambiar el tamaño disponible.
  int _gridColumnCount = 1;
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

  /// Acciones masivas sobre todas las entradas de la Pokédex abierta.
  /// Normales incluye únicamente formas base, regionales y diferencias de género.
  List<DexEntry> _bulkEntries(String kind) => game.allEntries.where((e) {
        switch (kind) {
          case 'normal':
            // Incluye todas las formas registrables: base, regionales, Mega y Gigamax.
            return true;
          case 'mega':
            return e.kind == 'mega';
          case 'gmax':
            return e.kind == 'gmax';
          default:
            return false;
        }
      }).toList();

  Future<void> _bulkSet(String kind, bool shiny, String label) async {
    final entries = _bulkEntries(kind).where((e) => !shiny || game.shinyFor(e)).toList();
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esta Pokédex no contiene entradas de $label.')),
      );
      return;
    }
    final allMarked = entries.every((e) => p.has(game.key(e), shiny: shiny));
    final mark = !allMarked;
    final action = mark ? 'marcar' : 'desmarcar';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${mark ? 'Marcar' : 'Desmarcar'} $label'),
        content: Text('¿Quieres $action como capturados ${entries.length} registros de $label en «${game.name}»?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(mark ? 'Marcar todos' : 'Desmarcar todos')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    p.setAll(game, entries, shiny: shiny, value: mark);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${entries.length} registros ${mark ? 'marcados' : 'desmarcados'}: $label.')),
    );
  }


  Widget _bulkMenu() => PopupMenuButton<String>(
        tooltip: 'Acciones masivas de captura',
        icon: const Icon(Icons.checklist),
        onSelected: (value) {
          final parts = value.split(':');
          final kind = parts[0];
          final shiny = parts[1] == 'shiny';
          final label = switch (kind) {
            'normal' => shiny ? 'todos los variocolor disponibles' : 'todos los registros normales y formas',
            'mega' => shiny ? 'todos los Mega variocolor' : 'todos los Mega',
            _ => shiny ? 'todos los Gigamax variocolor' : 'todos los Gigamax',
          };
          _bulkSet(kind, shiny, label);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'normal:normal', child: Text('Marcar/desmarcar todos los normales')),
          PopupMenuItem(value: 'normal:shiny', child: Text('Marcar/desmarcar todos los variocolor')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'mega:normal', child: Text('Marcar/desmarcar todos los Mega')),
          PopupMenuItem(value: 'mega:shiny', child: Text('Marcar/desmarcar todos los Mega variocolor')),
          PopupMenuDivider(),
          PopupMenuItem(value: 'gmax:normal', child: Text('Marcar/desmarcar todos los Gigamax')),
          PopupMenuItem(value: 'gmax:shiny', child: Text('Marcar/desmarcar todos los Gigamax variocolor')),
        ],
      );

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
            title: Text(gs.displayName(st.spanish)),
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
            showLocations: true,
            showMoves: true,
            expanded: true,
          ),
            ),
          ),
        ),
      ),
    );
  }

  /// Recorre la Pokédex con las flechas, respetando búsqueda, generación y filtro.
  void _moveSelection(int delta) {
    if (_searchFocus.hasFocus) return;
    final items = _filtered();
    if (items.isEmpty) return;

    final current = selected == null
        ? -1
        : items.indexWhere((item) => item.species.dex == selected!.species.dex);
    final next = current < 0
        ? (delta > 0 ? 0 : items.length - 1)
        : (current + delta).clamp(0, items.length - 1).toInt();

    setState(() {
      selected = items[next];
      rightOpen = true;
    });
  }

  /// Arriba/abajo desplaza una fila completa en cuadrícula. En vista de lista
  /// equivale a anterior/siguiente. El número de columnas se adapta al ancho
  /// real disponible, incluidos los paneles laterales abiertos o cerrados.
  void _moveVerticalSelection(int direction) {
    if (_searchFocus.hasFocus) return;
    final items = _filtered();
    if (items.isEmpty) return;
    final current = selected == null
        ? -1
        : items.indexWhere((item) => item.species.dex == selected!.species.dex);
    final step = st.viewMode == ViewMode.grid ? _gridColumnCount : 1;
    final next = current < 0
        ? (direction > 0 ? 0 : items.length - 1)
        : (current + direction * step).clamp(0, items.length - 1).toInt();
    setState(() {
      selected = items[next];
      rightOpen = true;
    });
  }

  /// Contadores de una especie calculados en una sola pasada.
  ({int n, int sh, int shT, int t, double ratio}) _stats(GameSpecies gs) {
    final es = gs.entries;
    final t = es.length;
    final n = p.count(game, es);
    final shT = game.shinyTotal(es);
    final sh = shT > 0 ? p.count(game, es, shiny: true) : 0;
    final total = t + shT;
    return (n: n, sh: sh, shT: shT, t: t, ratio: total == 0 ? 0.0 : (n + sh) / total);
  }

  String _label(({int n, int sh, int shT, int t, double ratio}) s) =>
      s.shT > 0 ? '${s.n}/${s.t}  ·  ✨ ${s.sh}/${s.shT}' : '${s.n}/${s.t}';

  List<GameSpecies> _filtered() {
    final q = query.trim().toLowerCase();
    final needStats = filter != DexFilter.all;
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
      if (!needStats) return true;
      final c = _stats(gs);
      return switch (filter) {
        DexFilter.all => true,
        DexFilter.missing => c.n < c.t,
        DexFilter.missingShiny => c.sh < c.shT,
        DexFilter.complete => c.n == c.t && c.sh == c.shT,
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
            const SingleActivator(LogicalKeyboardKey.arrowRight): () => _moveSelection(1),
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _moveSelection(-1),
            const SingleActivator(LogicalKeyboardKey.arrowDown): () => _moveVerticalSelection(1),
            const SingleActivator(LogicalKeyboardKey.arrowUp): () => _moveVerticalSelection(-1),
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              key: _scaffoldKey,
              endDrawer: SettingsDrawer(
                  settings: st,
                  onExport: _export,
                  onImport: _import,
                  onExportHtml: () => exportTrackingPage(context,
                      games: widget.games,
                      progress: p,
                      profiles: widget.profiles,
                      settings: st)),
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

  Widget _dailyChallenge() {
    final targets = p.dailyChallenge(game);
    final entries = <(GameSpecies, bool)>[];
    for (final target in targets) {
      final id = target['dex'] as int;
      final shiny = target['shiny'] == true;
      for (final gs in game.species) {
        if (gs.species.dex == id) { entries.add((gs, shiny)); break; }
      }
    }
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          title: const Center(child: Text('Desafío del día', style: TextStyle(fontWeight: FontWeight.bold))),
          trailing: const Icon(Icons.expand_more),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
          children: [
            Align(alignment: Alignment.center, child: TextButton.icon(
              onPressed: () => p.rerollDailyChallenge(game),
              icon: const Icon(Icons.shuffle, size: 18), label: const Text('Aleatorizar 4'))),
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (final item in entries)
                Builder(builder: (context) {
                  final gs = item.$1; final shiny = item.$2;
                  final entry = shiny ? gs.entries.firstWhere(game.shinyFor, orElse: () => gs.entries.first) : gs.entries.first;
                  return InkWell(
                    borderRadius: BorderRadius.circular(10), onTap: () => _open(gs, true),
                    child: Container(width: 112, padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.outlineVariant), borderRadius: BorderRadius.circular(10)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Sprite(shiny ? entry.shiny ?? entry.sprite : entry.sprite, size: 58, pixel: st.pixelSprites, threeD: st.threeDSprites),
                        Text(gs.displayName(st.spanish), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelMedium),
                        Text(shiny ? '✨ Variocolor' : 'Normal', style: Theme.of(context).textTheme.labelSmall),
                        Text('#${gs.species.dex}', style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  );
                }),
              if (entries.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('¡Has completado todos los objetivos de esta Pokédex!')),
            ]),
          ],
        ),
      ),
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
              GameIcon(game, size: 42),
              const SizedBox(width: 10),
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
        _dailyChallenge(),
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
              _bulkMenu(),
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
                        p.count(game, all, shiny: true), game.shinyTotal(all))),
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

  List<(String, List<GameSpecies>)> _sectionGroups(List<GameSpecies> list) {
    final groups = <String, List<GameSpecies>>{};
    for (final gs in list) {
      groups.putIfAbsent(gs.section ?? '', () => []).add(gs);
    }
    return groups.entries.map((e) => (e.key, e.value)).toList();
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Row(children: [
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Divider(color: Theme.of(context).colorScheme.outlineVariant)),
        ]),
      );

  Widget _grid(List<GameSpecies> list, bool wide) {
    final sz = st.spriteSize;
    const spacing = 10.0;
    final maxExtent = sz + 56;
    final groups = _sectionGroups(list);
    return LayoutBuilder(builder: (context, constraints) {
      final usableWidth = (constraints.maxWidth - 32).clamp(0.0, double.infinity);
      _gridColumnCount = (usableWidth / (maxExtent + spacing)).ceil().clamp(1, 1000);
      // Slivers: solo se construyen las tarjetas visibles (antes, con
      // shrinkWrap, se construían todas a la vez).
      return CustomScrollView(
        key: ValueKey('grid-${game.id}'),
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          for (final group in groups) ...[
            if (group.$1.isNotEmpty) SliverToBoxAdapter(child: _sectionTitle(group.$1)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: maxExtent,
                  mainAxisExtent: sz + 32 + 56 * st.textScale,
                  crossAxisSpacing: spacing,
                  mainAxisSpacing: spacing,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _card(group.$2[i], wide),
                  childCount: group.$2.length,
                ),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      );
    });
  }

  Widget _card(GameSpecies gs, bool wide) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sel = wide && identical(gs, selected);
    final stats = _stats(gs);
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
                gs.displayName(st.spanish),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(_label(stats), style: theme.textTheme.labelSmall),
              const Spacer(),
              LinearProgressIndicator(value: stats.ratio, minHeight: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(List<GameSpecies> list, bool wide) {
    final groups = _sectionGroups(list);
    return CustomScrollView(
      key: ValueKey('list-${game.id}'),
      slivers: [
        for (final group in groups) ...[
          if (group.$1.isNotEmpty) SliverToBoxAdapter(child: _sectionTitle(group.$1)),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final gs = group.$2[i];
                final stats = _stats(gs);
                return InkWell(
                  onTap: () => _open(gs, wide),
                  onDoubleTap: () => _openFullscreen(gs),
                  child: ListTile(
                    selected: identical(gs, selected),
                    leading: Sprite(gs.entries.first.sprite,
                        size: st.spriteSize.clamp(40.0, 64.0).toDouble(),
                        pixel: st.pixelSprites, threeD: st.threeDSprites),
                    title: Text('${dexNumber(game, gs)}  ${gs.displayName(st.spanish)}'),
                    subtitle: Text(_label(stats)),
                    trailing: SizedBox(width: 90,
                        child: LinearProgressIndicator(value: stats.ratio, minHeight: 4)),
                  ),
                );
              },
              childCount: group.$2.length,
            ),
          ),
        ],
      ],
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
