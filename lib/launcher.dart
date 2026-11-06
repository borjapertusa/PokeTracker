import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'abilities_dex.dart';

import 'boxes.dart';
import 'data_actions.dart';
import 'details.dart';
import 'game_store.dart';
import 'models.dart';
import 'profiles.dart';
import 'profiles_screen.dart';
import 'progress.dart';
import 'screens.dart';
import 'general_dex.dart';
import 'global_moves_dex.dart';
import 'objects_dex.dart';
import 'settings.dart';
import 'settings_drawer.dart';
import 'offline_content.dart';
import 'tm_dex.dart';

/// Una sección de la app que aparece en la pantalla de inicio.
class AppSection {
  final String id, title, subtitle;
  final IconData icon;
  final Widget Function(BuildContext context) builder;
  final String? stat; // texto breve opcional (p. ej. progreso)
  const AppSection({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.builder,
    this.stat,
  });
}

/// Pantalla que aparece al abrir la app: elige a qué sección ir.
class LauncherScreen extends StatefulWidget {
  final List<Game> games;
  final GameStore store;
  final Progress progress;
  final AppSettings settings;
  final DexDetails? details;
  final Map<int, Species> byDex;
  final List<Species> allSpecies;
  final BoxStore boxes;
  final EntryIndex entryIndex;
  final ProfileStore profiles;
  const LauncherScreen({
    super.key,
    required this.games,
    required this.store,
    required this.progress,
    required this.settings,
    required this.details,
    required this.byDex,
    required this.allSpecies,
    required this.boxes,
    required this.entryIndex,
    required this.profiles,
  });

  @override
  State<LauncherScreen> createState() => _LauncherScreenState();
}

class _LauncherScreenState extends State<LauncherScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Secciones de la app. Para añadir una nueva, añade otro AppSection a esta lista.
  List<AppSection> _sections() {
    final home = widget.games.first; // Pokémon HOME: incluye todo
    final all = home.allEntries;
    final t = all.length;
    final n = widget.progress.count(home, all);
    final sh = widget.progress.count(home, all, shiny: true);
    return [
      AppSection(
        id: 'offline_content',
        title: 'Contenido local',
        subtitle: 'Comprueba qué catálogos e imágenes están incluidos y configura el uso sin conexión.',
        icon: Icons.offline_bolt_outlined,
        stat: 'Gestión offline',
        builder: (_) => OfflineContentScreen(settings: widget.settings),
      ),
      AppSection(
        id: 'tracker',
        title: 'Tracker',
        subtitle:
            'Registra tus Pokémon por juego: formas, género y variocolor, con fichas y cajas.',
        icon: Icons.catching_pokemon,
        stat: 'HOME: $n/$t  ·  ✨ $sh/$t',
        builder: (_) => HomeScreen(
          games: widget.games,
          store: widget.store,
          progress: widget.progress,
          settings: widget.settings,
          details: widget.details,
          byDex: widget.byDex,
          boxes: widget.boxes,
          entryIndex: widget.entryIndex,
          profiles: widget.profiles,
        ),
      ),
      AppSection(
        id: 'abilities',
        title: 'Habilidades',
        subtitle: 'Consulta las habilidades, sus efectos en combate y fuera de él, y qué Pokémon las pueden tener.',
        icon: Icons.auto_awesome,
        stat: '${widget.details?.abilities.length ?? 0} habilidades',
        builder: (_) => AbilityDexScreen(
          species: widget.allSpecies,
          details: widget.details,
          settings: widget.settings,
        ),
      ),
      AppSection(
        id: 'items',
        title: 'Objetos',
        subtitle: 'Consulta los objetos de cada grupo de ediciones, sus efectos, descripciones, precios y usos evolutivos.',
        icon: Icons.inventory_2_outlined,
        stat: 'Objetodex por juego',
        builder: (_) => ObjectsDexScreen(
          spanish: widget.settings.spanish,
          details: widget.details,
          species: widget.allSpecies,
          settings: widget.settings,
        ),
      ),
      AppSection(
        id: 'tm_hm_tr',
        title: 'MT/MO/DT',
        subtitle: 'Consulta las máquinas técnicas, ocultas y técnicas especiales de cada grupo de juegos, con el movimiento que enseñan y sus datos.',
        icon: Icons.album_outlined,
        stat: 'Máquinas por juego',
        builder: (_) => TmDexScreen(spanish: widget.settings.spanish, settings: widget.settings),
      ),
      AppSection(
        id: 'moves',
        title: 'Movimientos',
        subtitle: 'Consulta potencia, precisión, PP, efectos, cambios históricos y Pokémon que aprenden cada movimiento.',
        icon: Icons.flash_on_outlined,
        stat: 'Pokédex de movimientos',
        builder: (_) => MovesDexScreen(spanish: widget.settings.spanish, settings: widget.settings),
      ),
      AppSection(
        id: 'general_dex',
        title: 'Pokédex',
        subtitle: 'Enciclopedia Pokémon: consulta especies, formas, estadísticas, habilidades, evoluciones y más, sin registrar progreso.',
        icon: Icons.menu_book_outlined,
        stat: '${widget.allSpecies.length} especies',
        builder: (_) => GeneralDexScreen(
          species: widget.allSpecies,
          byDex: widget.byDex,
          details: widget.details,
          settings: widget.settings,
        ),
      ),
    ];
  }

  Widget _profilesScreen() => ProfilesScreen(
        profiles: widget.profiles,
        games: widget.games,
        entryIndex: widget.entryIndex,
        settings: widget.settings,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.comma, control: true): () =>
            _scaffoldKey.currentState?.openEndDrawer(),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          key: _scaffoldKey,
          endDrawer: SettingsDrawer(
            settings: widget.settings,
            onExport: () => exportProgress(context, widget.progress),
            onImport: () => importProgress(context, widget.progress),
          ),
          appBar: AppBar(
            title: ProfileMenu(
              profiles: widget.profiles,
              entryIndex: widget.entryIndex,
              settings: widget.settings,
              onManage: () => Navigator.push(
                  context, MaterialPageRoute(builder: (_) => _profilesScreen())),
            ),
            actions: [
              IconButton(
                tooltip: 'Opciones (Ctrl+,)',
                icon: const Icon(Icons.settings),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: ListenableBuilder(
            listenable: Listenable.merge([widget.progress, widget.settings, widget.profiles]),
            builder: (context, _) {
              final sections = _sections();
              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.catching_pokemon,
                            size: 56, color: theme.colorScheme.primary),
                        const SizedBox(height: 12),
                        Text('Pokédex Tracker',
                            style: theme.textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text('Elige una sección',
                            style: theme.textTheme.bodyMedium),
                        const SizedBox(height: 32),
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final s in sections) _SectionCard(section: s),
                            const _ComingCard(),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final AppSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 280,
      height: 200,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: section.builder)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(section.icon, size: 36, color: theme.colorScheme.primary),
                const SizedBox(height: 12),
                Text(section.title, style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(section.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall),
                const Spacer(),
                if (section.stat != null)
                  Text(section.stat!,
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hueco reservado para las próximas secciones.
class _ComingCard extends StatelessWidget {
  const _ComingCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.outline;
    return SizedBox(
      width: 280,
      height: 200,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_circle_outline, size: 36, color: muted),
              const SizedBox(height: 12),
              Text('Más secciones',
                  style: theme.textTheme.titleMedium?.copyWith(color: muted)),
              Text('Próximamente',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted)),
            ],
          ),
        ),
      ),
    );
  }
}
