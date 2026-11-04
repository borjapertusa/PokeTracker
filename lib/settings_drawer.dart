import 'package:flutter/material.dart';

import 'settings.dart';

/// Panel de opciones que se abre desde la derecha (botón ⚙ o Ctrl+,).
class SettingsDrawer extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onExport;
  final VoidCallback onImport;
  const SettingsDrawer({
    super.key,
    required this.settings,
    required this.onExport,
    required this.onImport,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: 360,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final st = settings;
            Widget section(String t) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(t, style: theme.textTheme.titleSmall),
                );
            Widget pad(Widget w) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: w,
                );

            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                          child: Text('Opciones',
                              style: theme.textTheme.titleLarge)),
                      IconButton(
                        tooltip: 'Cerrar',
                        icon: const Icon(Icons.close),
                        onPressed: () => Scaffold.of(context).closeEndDrawer(),
                      ),
                    ],
                  ),
                ),
                section('Tema'),
                pad(SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: ThemeMode.system, label: Text('Sistema')),
                    ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                    ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                  ],
                  selected: {st.themeMode},
                  onSelectionChanged: (s) =>
                      st.update(() => st.themeMode = s.first),
                )),
                section('Color de acento'),
                pad(Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in AppSettings.accents.entries)
                      Tooltip(
                        message: e.key,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => st.update(() => st.accent = e.key),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: e.value,
                            child: st.accent == e.key
                                ? const Icon(Icons.check,
                                    size: 18, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                  ],
                )),
                section('Vista de la lista'),
                pad(SegmentedButton<ViewMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: ViewMode.grid,
                        icon: Icon(Icons.grid_view),
                        label: Text('Cuadrícula')),
                    ButtonSegment(
                        value: ViewMode.list,
                        icon: Icon(Icons.view_list),
                        label: Text('Lista')),
                  ],
                  selected: {st.viewMode},
                  onSelectionChanged: (s) =>
                      st.update(() => st.viewMode = s.first),
                )),
                section('Tamaño del texto: ${(st.textScale * 100).round()}%'),
                Slider(
                  value: st.textScale,
                  min: 0.8,
                  max: 1.5,
                  divisions: 7,
                  label: '${(st.textScale * 100).round()}%',
                  onChanged: (v) => st.update(() => st.textScale = v),
                ),
                section('Tamaño de los sprites: ${st.spriteSize.round()} px'),
                Slider(
                  value: st.spriteSize,
                  min: 48,
                  max: 128,
                  divisions: 10,
                  label: '${st.spriteSize.round()}',
                  onChanged: (v) => st.update(() => st.spriteSize = v),
                ),
                SwitchListTile(
                  title: const Text('Sprites pixelados (nítidos)'),
                  subtitle: const Text('Desactívalo para suavizar al ampliar'),
                  value: st.pixelSprites,
                  onChanged: (v) => st.update(() => st.pixelSprites = v),
                ),
                section('Idioma de los nombres'),
                pad(SegmentedButton<bool>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: true, label: Text('Español')),
                    ButtonSegment(value: false, label: Text('Inglés')),
                  ],
                  selected: {st.spanish},
                  onSelectionChanged: (s) =>
                      st.update(() => st.spanish = s.first),
                )),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.copy),
                  title: const Text('Copiar progreso (JSON)'),
                  subtitle: const Text('Copia de seguridad en el portapapeles'),
                  onTap: onExport,
                ),
                ListTile(
                  leading: const Icon(Icons.download),
                  title: const Text('Importar progreso…'),
                  subtitle: const Text('Pega un JSON exportado; se combina'),
                  onTap: () {
                    Scaffold.of(context).closeEndDrawer();
                    onImport();
                  },
                ),
                pad(Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: st.reset,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restablecer opciones'),
                  ),
                )),
                const SizedBox(height: 16),
              ],
            );
          },
        ),
      ),
    );
  }
}
