import 'package:flutter/material.dart';

import 'settings.dart';
import 'offline_content.dart';

/// Panel de opciones que se abre desde la derecha (botón ⚙ o Ctrl+,).
class SettingsDrawer extends StatelessWidget {
  final AppSettings settings;
  final VoidCallback onExport;
  final VoidCallback onImport;

  /// Genera la página web de seguimiento (para publicarla y compartir un enlace).
  final VoidCallback? onExportHtml;
  const SettingsDrawer({
    super.key,
    required this.settings,
    required this.onExport,
    required this.onImport,
    this.onExportHtml,
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
                ListTile(
                  leading: const Icon(Icons.offline_bolt_outlined),
                  title: const Text('Contenido local'),
                  subtitle: const Text('Gestionar datos e imágenes sin conexión'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Scaffold.of(context).closeEndDrawer();
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => OfflineContentScreen(settings: st),
                    ));
                  },
                ),
                SwitchListTile(
                  title: const Text('Modo sin conexión para imágenes'),
                  subtitle: const Text('No cargar sprites ni iconos desde Internet'),
                  value: st.offlineMode,
                  onChanged: (v) => st.update(() => st.offlineMode = v),
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
                section('Ancho del lateral izquierdo: ${st.leftSidebarWidth.round()} px'),
                Slider(
                  value: st.leftSidebarWidth,
                  min: 200,
                  max: 420,
                  divisions: 22,
                  label: '${st.leftSidebarWidth.round()} px',
                  onChanged: (v) => st.update(() => st.leftSidebarWidth = v),
                ),
                section('Ancho del lateral derecho: ${st.rightSidebarWidth.round()} px'),
                Slider(
                  value: st.rightSidebarWidth,
                  min: 300,
                  max: 700,
                  divisions: 20,
                  label: '${st.rightSidebarWidth.round()} px',
                  onChanged: (v) => st.update(() => st.rightSidebarWidth = v),
                ),
                section('Estilo de sprites'),
                pad(DropdownButtonFormField<SpriteMode>(
                  value: st.spriteMode,
                  isExpanded: true,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: SpriteMode.twoD, child: Text('2D (sprites clásicos)')),
                    DropdownMenuItem(value: SpriteMode.threeD, child: Text('3D (renders de Pokémon HOME)')),
                    DropdownMenuItem(value: SpriteMode.animated, child: Text('3D animados')),
                  ],
                  onChanged: (v) {
                    if (v != null) st.update(() => st.spriteMode = v);
                  },
                )),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Text(
                    switch (st.spriteMode) {
                      SpriteMode.twoD => 'Usa los sprites 2D incluidos en la app.',
                      SpriteMode.threeD => 'Usa los renders 3D descargados con el contenido local. Si falta alguna forma, se muestra el sprite 2D.',
                      SpriteMode.animated => 'Usa sprites animados (Pokémon Showdown). Se descargan la primera vez que se ven y se guardan en el equipo; si no hay conexión o falta alguno, se muestra el render 3D.',
                    },
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                if (onExportHtml != null)
                  ListTile(
                    leading: const Icon(Icons.public),
                    title: const Text('Exportar seguimiento (página web)…'),
                    subtitle: const Text('Crea un HTML con tu progreso para publicarlo y compartir un enlace'),
                    onTap: () {
                      Scaffold.of(context).closeEndDrawer();
                      onExportHtml!();
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
