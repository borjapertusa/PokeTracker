import 'package:flutter/material.dart';

import 'game_store.dart';
import 'models.dart';
import 'new_tracker_dialog.dart';
import 'progress.dart';
import 'widgets.dart';

const _roman = ['', 'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

String _groupOf(Game g) {
  if (g.custom) return 'MIS JUEGOS';
  if (g.gen == 0) return 'GENERAL';
  if (g.id == 'pokopia' || g.id == 'pokopia-dlc') return 'POKOPIA';
  return 'GENERACIÓN ${g.gen < _roman.length ? _roman[g.gen] : g.gen}';
}

/// Lista de Pokédex con su progreso. Arriba: crear un tracker nuevo y ordenar.
/// En cada Pokédex, el menú ⋮ permite renombrar, mover (orden manual) y eliminar.
class GameList extends StatelessWidget {
  final GameStore store;
  final Game current;
  final Progress progress;
  final ValueChanged<Game> onSelect;
  const GameList({
    super.key,
    required this.store,
    required this.current,
    required this.progress,
    required this.onSelect,
  });

  // ------------------------------------------------------------------ acciones

  Future<void> _create(BuildContext context) async {
    final req = await showDialog<TrackerRequest>(
      context: context,
      builder: (_) =>
          NewTrackerDialog(maxGen: store.maxGen, copyable: store.copyable),
    );
    if (req == null) return;
    final created = store.add(req);
    if (created.isNotEmpty) onSelect(created.first);
  }

  Future<void> _rename(BuildContext context, Game g) async {
    final ctrl = TextEditingController(text: g.name);
    final res = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Renombrar Pokédex'),
        content: SizedBox(
          width: 360,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ),
        actions: [
          if (store.isRenamed(g))
            TextButton(
              onPressed: () => Navigator.pop(c, store.originalName(g)),
              child: const Text('Restaurar original'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (res != null) store.rename(g, res);
  }

  Future<void> _remove(BuildContext context, Game g) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(g.custom
            ? 'Eliminar «${g.name}»'
            : 'Quitar «${g.name}» de la lista'),
        content: Text(g.custom
            ? 'Se borrará esta Pokédex junto con su progreso, sus cajas y los '
                'datos de entrenador de todos los perfiles. No se puede deshacer.'
            : 'Se ocultará de la lista. Tu progreso y tus cajas se conservan y '
                'puedes volver a mostrarla desde el botón de ordenar (⇅).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(g.custom ? 'Eliminar' : 'Quitar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final wasCurrent = g.id == current.id;
    store.remove(g);
    if (wasCurrent) onSelect(store.games.first);
  }

  Future<void> _restore(BuildContext context) => showDialog<void>(
        context: context,
        builder: (c) => ListenableBuilder(
          listenable: store,
          builder: (c, _) {
            final hidden = store.hiddenGames;
            return AlertDialog(
              title: const Text('Pokédex quitadas de la lista'),
              content: SizedBox(
                width: 360,
                child: hidden.isEmpty
                    ? const Text('No hay ninguna.')
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final g in hidden)
                              ListTile(
                                dense: true,
                                leading: GameIcon(g, size: 34),
                                title: Text(g.name),
                                trailing: const Icon(Icons.restore),
                                onTap: () => store.restore(g),
                              ),
                          ],
                        ),
                      ),
              ),
              actions: [
                if (hidden.length > 1)
                  TextButton(
                    onPressed: store.restoreAll,
                    child: const Text('Restaurar todas'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        ),
      );

  // ------------------------------------------------------------------- piezas

  Widget _header(BuildContext context) {
    final hidden = store.hiddenGames.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: () => _create(context),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo tracker'),
            ),
          ),
          PopupMenuButton<Object>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.swap_vert),
            onSelected: (v) {
              if (v is GameSort) {
                store.setSort(v);
              } else if (v == 'restore') {
                _restore(context);
              }
            },
            itemBuilder: (_) => <PopupMenuEntry<Object>>[
              for (final s in GameSort.values)
                CheckedPopupMenuItem<Object>(
                  value: s,
                  checked: store.sort == s,
                  child: Text(gameSortLabels[s]!),
                ),
              if (hidden > 0) ...[
                const PopupMenuDivider(),
                PopupMenuItem<Object>(
                  value: 'restore',
                  child: Text('Restaurar quitadas ($hidden)'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, Game g, int index, int count) {
    final theme = Theme.of(context);
    final all = g.allEntries;
    final t = all.length;
    final n = progress.count(g, all);
    final sh = g.shiny ? progress.count(g, all, shiny: true) : 0;
    final ratio = t == 0 ? 0.0 : (n + sh) / ((g.shiny ? 2 : 1) * t);
    final manual = store.sort == GameSort.manual;
    return ListTile(
      dense: true,
      leading: GameIcon(g, size: 34),
      selected: g.id == current.id,
      selectedTileColor: theme.colorScheme.secondaryContainer,
      title: Row(children: [
        Expanded(child: Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis)),
        if (t > 0 && ratio >= 1.0)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Tooltip(message: 'Pokédex completada al 100%', child: Icon(Icons.workspace_premium, color: Color(0xFFFFB300), size: 19)),
          ),
      ]),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(g.shiny ? '$n/$t  ·  ✨ $sh/$t' : '$n/$t',
                style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: ratio, minHeight: 3),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: 'Opciones de esta Pokédex',
        icon: const Icon(Icons.more_vert, size: 20),
        onSelected: (v) {
          switch (v) {
            case 'rename':
              _rename(context, g);
            case 'up':
              store.move(g, -1);
            case 'down':
              store.move(g, 1);
            case 'remove':
              _remove(context, g);
          }
        },
        itemBuilder: (_) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'rename',
            child: ListTile(
              dense: true,
              leading: Icon(Icons.edit_outlined),
              title: Text('Renombrar'),
            ),
          ),
          if (manual) ...[
            PopupMenuItem<String>(
              value: 'up',
              enabled: index > 0,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_upward),
                title: Text('Subir'),
              ),
            ),
            PopupMenuItem<String>(
              value: 'down',
              enabled: index < count - 1,
              child: const ListTile(
                dense: true,
                leading: Icon(Icons.arrow_downward),
                title: Text('Bajar'),
              ),
            ),
          ],
          if (g.id != 'home')
            PopupMenuItem<String>(
              value: 'remove',
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.delete_outline),
                title: Text(g.custom ? 'Eliminar' : 'Quitar de la lista'),
              ),
            ),
        ],
      ),
      onTap: () => onSelect(g),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, progress]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final games = store.sorted(progress);
        final grouped = store.sort == GameSort.generation;
        final items = <Widget>[];
        String? lastGroup;
        for (var i = 0; i < games.length; i++) {
          final g = games[i];
          if (grouped) {
            final group = _groupOf(g);
            if (group != lastGroup) {
              lastGroup = group;
              items.add(Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  group,
                  style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary, letterSpacing: 1),
                ),
              ));
            }
          }
          items.add(_tile(context, g, i, games.length));
        }
        return Column(
          children: [
            _header(context),
            Expanded(child: ListView(children: items)),
          ],
        );
      },
    );
  }
}
