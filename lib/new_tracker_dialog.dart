import 'package:flutter/material.dart';

import 'game_store.dart';
import 'models.dart';
import 'widgets.dart';

class _DexRow {
  final TextEditingController name;
  DexSource source = DexSource.national;
  int gen = 1;
  String? copyOf;
  bool nationalForGame = false;
  bool includeDlc = false;
  _DexRow(String text) : name = TextEditingController(text: text);
}

/// Diálogo para crear el tracker de un juego nuevo, con una o varias Pokédex.
/// Devuelve un [TrackerRequest] (o null si se cancela).
class NewTrackerDialog extends StatefulWidget {
  final int maxGen;
  final List<Game> copyable; // juegos oficiales cuya lista se puede copiar
  const NewTrackerDialog({
    super.key,
    required this.maxGen,
    required this.copyable,
  });

  @override
  State<NewTrackerDialog> createState() => _NewTrackerDialogState();
}

class _NewTrackerDialogState extends State<NewTrackerDialog> {
  final _name = TextEditingController();
  late final List<_DexRow> _rows;
  final _removed = <TextEditingController>[]; // se liberan al cerrar el diálogo
  bool _shiny = true, _genders = true, _forms = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.name.dispose();
    }
    for (final c in _removed) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _rows = [_newRow('Pokédex 1')];
  }

  /// Por defecto, la Pokédex regional de un juego (no la nacional): solo se usa
  /// la nacional si se elige expresamente.
  _DexRow _newRow(String text) {
    final r = _DexRow(text);
    if (widget.copyable.isNotEmpty) {
      r.source = DexSource.copy;
      r.copyOf = widget.copyable.first.id;
    }
    return r;
  }

  void _addRow() =>
      setState(() => _rows.add(_newRow('Pokédex ${_rows.length + 1}')));

  void _removeRow(int i) => setState(() => _removed.add(_rows.removeAt(i).name));

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Escribe un nombre para el juego');
      return;
    }
    Navigator.pop(
      context,
      TrackerRequest(
        name: name,
        shiny: _shiny,
        genders: _genders,
        forms: _forms,
        dexes: [
          for (final r in _rows)
            DexSpec(
              name: r.name.text.trim(),
              source: r.source,
              copyOf: r.copyOf,
              nationalForGame: r.nationalForGame,
              includeDlc: r.includeDlc,
            ),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
    Map<T, Game>? gameItems,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          items: [
            for (final e in items.entries)
              DropdownMenuItem<T>(value: e.key, child: gameItems != null && gameItems[e.key] != null
                  ? Row(children: [GameIcon(gameItems[e.key]!, size: 30), const SizedBox(width: 8), Expanded(child: Text(e.value, overflow: TextOverflow.ellipsis))])
                  : Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _rowEditor(int i, bool multi) {
    final theme = Theme.of(context);
    final r = _rows[i];
    final help = switch (r.source) {
      DexSource.national => 'Todas las especies, con su número nacional (como Pokémon HOME).',
      DexSource.copy => r.nationalForGame
          ? 'Todas las especies, con el icono y la generación del juego elegido.'
          : 'Solo los Pokémon de la Pokédex regional del juego seleccionado, con su numeración.',
    };
    return Card(
      key: ObjectKey(r),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (multi) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: r.name,
                      decoration: const InputDecoration(
                        labelText: 'Nombre de la Pokédex',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Quitar esta Pokédex',
                    icon: const Icon(Icons.close),
                    onPressed: () => _removeRow(i),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            _dropdown<DexSource>(
              label: 'Contenido',
              value: r.source,
              items: {
                if (widget.copyable.isNotEmpty)
                  DexSource.copy: 'Pokédex regional de un juego',
                DexSource.national: 'Nacional (todos los Pokémon)',
              },
              onChanged: (v) => setState(() {
                r.source = v;
                if (v == DexSource.copy) {
                  r.copyOf ??= widget.copyable.first.id;
                }
              }),
            ),
            if (r.source == DexSource.copy && r.copyOf != null) ...[
              const SizedBox(height: 8),
              _dropdown<String>(
                label: 'Juego',
                value: r.copyOf!,
                items: {for (final g in widget.copyable) g.id: g.name},
                gameItems: {for (final g in widget.copyable) g.id: g},
                onChanged: (v) => setState(() { r.copyOf = v; r.includeDlc = false; }),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero, dense: true,
                title: const Text('Usar la Pokédex nacional de este juego'),
                subtitle: const Text('Todas las especies, con el icono y generación del juego elegido.'),
                value: r.nationalForGame,
                onChanged: (v) => setState(() => r.nationalForGame = v),
              ),
              if (!r.nationalForGame && const ['sword-shield','scarlet-violet','legends-za'].contains(r.copyOf))
                SwitchListTile(
                  contentPadding: EdgeInsets.zero, dense: true,
                  title: const Text('Incluir los DLC'),
                  subtitle: const Text('Añade las secciones de expansiones disponibles.'),
                  value: r.includeDlc,
                  onChanged: (v) => setState(() => r.includeDlc = v),
                ),
            ],
            const SizedBox(height: 6),
            Text(help, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final multi = _rows.length > 1;
    return AlertDialog(
      title: const Text('Nuevo tracker'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nombre del juego',
                  hintText: 'p. ej. Pokémon Esmeralda Kaizo',
                  border: const OutlineInputBorder(),
                  errorText: _error,
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Variocolor'),
                subtitle: const Text('Registrar también la casilla ✨'),
                value: _shiny,
                onChanged: (v) => setState(() => _shiny = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Diferencias de género'),
                subtitle: const Text('Entradas separadas ♂ / ♀ cuando existan'),
                value: _genders,
                onChanged: (v) => setState(() => _genders = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Formas alternativas'),
                subtitle: const Text('Mega, Gigamax, regionales y otras formas'),
                value: _forms,
                onChanged: (v) => setState(() => _forms = v),
              ),
              const Divider(),
              Text(multi ? 'Pokédex del juego' : 'Pokédex',
                  style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              for (var i = 0; i < _rows.length; i++) _rowEditor(i, multi),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('Añadir otra Pokédex'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check),
          label: Text(multi ? 'Crear Pokédex' : 'Crear'),
        ),
      ],
    );
  }
}
