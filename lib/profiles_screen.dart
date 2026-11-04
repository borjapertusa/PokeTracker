import 'package:flutter/material.dart';

import 'boxes.dart';
import 'boxes_screen.dart';
import 'models.dart';
import 'profiles.dart';
import 'settings.dart';
import 'widgets.dart';

/// Icono de un perfil: su Pokémon favorito, o la inicial del nombre.
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final EntryIndex entryIndex;
  final double size;
  final bool pixel;
  const ProfileAvatar({
    super.key,
    required this.profile,
    required this.entryIndex,
    this.size = 40,
    this.pixel = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = profile.avatar?.split('|');
    final mon = parts == null ? null : entryIndex[parts[0]];
    final shiny = parts != null && parts.length > 1;
    final path = mon == null
        ? null
        : (shiny ? (mon.$2.shiny ?? mon.$2.sprite) : mon.$2.sprite);
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: scheme.secondaryContainer,
      child: path != null
          ? Sprite(path, size: size * 0.9, pixel: pixel)
          : Text(
              profile.name.isEmpty ? '?' : profile.name.substring(0, 1).toUpperCase(),
              style: TextStyle(
                  fontSize: size * 0.45,
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w600),
            ),
    );
  }
}

/// Selector rápido de perfil (para la barra superior).
class ProfileMenu extends StatelessWidget {
  final ProfileStore profiles;
  final EntryIndex entryIndex;
  final AppSettings settings;
  final VoidCallback onManage;
  const ProfileMenu({
    super.key,
    required this.profiles,
    required this.entryIndex,
    required this.settings,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([profiles, settings]),
      builder: (context, _) {
        final a = profiles.active;
        return PopupMenuButton<String>(
          tooltip: 'Cambiar de perfil',
          onSelected: (v) => v == '_manage' ? onManage() : profiles.select(v),
          itemBuilder: (_) => [
            for (final p in profiles.profiles)
              PopupMenuItem(
                value: p.id,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProfileAvatar(
                        profile: p,
                        entryIndex: entryIndex,
                        size: 28,
                        pixel: settings.pixelSprites),
                    const SizedBox(width: 10),
                    Flexible(
                        child: Text(p.name, overflow: TextOverflow.ellipsis)),
                    if (p.id == a.id) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check, size: 18),
                    ],
                  ],
                ),
              ),
            const PopupMenuDivider(),
            const PopupMenuItem(
                value: '_manage', child: Text('Gestionar perfiles…')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProfileAvatar(
                    profile: a,
                    entryIndex: entryIndex,
                    size: 32,
                    pixel: settings.pixelSprites),
                const SizedBox(width: 8),
                Text(a.name, style: Theme.of(context).textTheme.titleMedium),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lista de perfiles: usar, crear y editar.
class ProfilesScreen extends StatelessWidget {
  final ProfileStore profiles;
  final List<Game> games;
  final EntryIndex entryIndex;
  final AppSettings settings;
  const ProfilesScreen({
    super.key,
    required this.profiles,
    required this.games,
    required this.entryIndex,
    required this.settings,
  });

  void _edit(BuildContext context, Profile p) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileEditScreen(
            profiles: profiles,
            profile: p,
            games: games,
            entryIndex: entryIndex,
            settings: settings,
          ),
        ),
      );

  Future<void> _create(BuildContext context) async {
    final ctrl =
        TextEditingController(text: 'Perfil ${profiles.profiles.length + 1}');
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Nuevo perfil'),
        content: SizedBox(
          width: 320,
          child: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(
                labelText: 'Nombre del perfil', border: OutlineInputBorder()),
            onSubmitted: (v) => Navigator.pop(c, v),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: const Text('Crear')),
        ],
      ),
    );
    if (name == null || name.trim().isEmpty || !context.mounted) return;
    _edit(context, profiles.create(name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfiles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        icon: const Icon(Icons.add),
        label: const Text('Nuevo perfil'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([profiles, settings]),
        builder: (context, _) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                for (final p in profiles.profiles)
                  Card(
                    child: ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      leading: ProfileAvatar(
                          profile: p,
                          entryIndex: entryIndex,
                          size: 48,
                          pixel: settings.pixelSprites),
                      title: Text(p.name),
                      subtitle: Text(p.id == profiles.activeId
                          ? 'Perfil activo'
                          : '${p.games.length} ${p.games.length == 1 ? 'juego' : 'juegos'} con datos'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (p.id != profiles.activeId)
                            TextButton(
                                onPressed: () => profiles.select(p.id),
                                child: const Text('Usar')),
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit),
                            onPressed: () => _edit(context, p),
                          ),
                        ],
                      ),
                      onTap: () => _edit(context, p),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Edición de un perfil: nombre, icono y nombre/ID de entrenador por juego.
class ProfileEditScreen extends StatefulWidget {
  final ProfileStore profiles;
  final Profile profile;
  final List<Game> games;
  final EntryIndex entryIndex;
  final AppSettings settings;
  const ProfileEditScreen({
    super.key,
    required this.profiles,
    required this.profile,
    required this.games,
    required this.entryIndex,
    required this.settings,
  });

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.profile.name);

  ProfileStore get profiles => widget.profiles;
  Profile get profile => widget.profile;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final home = widget.games.firstWhere((g) => g.id == 'home');
    final v = await showDialog<String>(
      context: context,
      builder: (_) => PokemonPickerDialog(
        game: home,
        games: widget.games,
        filled: profile.avatar != null,
        settings: widget.settings,
        title: 'Elige tu Pokémon favorito',
        removeLabel: 'Quitar icono',
      ),
    );
    if (v == null) return;
    profiles.setAvatar(profile, v.isEmpty ? null : v);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar perfil'),
        content: Text(
            'Se eliminará "${profile.name}" con todo su progreso, sus cajas y sus datos de entrenador. No se puede deshacer.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    profiles.delete(profile.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListenableBuilder(
                listenable: profiles,
                builder: (context, _) => Row(
                  children: [
                    ProfileAvatar(
                        profile: profile,
                        entryIndex: widget.entryIndex,
                        size: 88,
                        pixel: widget.settings.pixelSprites),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _pickAvatar,
                            icon: const Icon(Icons.catching_pokemon),
                            label: const Text('Elegir Pokémon favorito'),
                          ),
                          if (profile.avatar != null)
                            TextButton(
                              onPressed: () => profiles.setAvatar(profile, null),
                              child: const Text('Quitar icono'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _name,
                maxLength: 24,
                decoration: const InputDecoration(
                    labelText: 'Nombre del perfil',
                    border: OutlineInputBorder()),
                onChanged: (v) => profiles.rename(profile, v),
              ),
              const SizedBox(height: 8),
              Text('Datos por juego', style: theme.textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Nombre e ID de entrenador de tu partida en cada juego (opcional).',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final g in widget.games)
                _GameFields(
                    key: ValueKey('${profile.id}/${g.id}'),
                    profiles: profiles,
                    profile: profile,
                    game: g),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: profiles.profiles.length > 1 ? _delete : null,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(profiles.profiles.length > 1
                      ? 'Eliminar perfil'
                      : 'No se puede eliminar el único perfil'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _GameFields extends StatefulWidget {
  final ProfileStore profiles;
  final Profile profile;
  final Game game;
  const _GameFields({
    super.key,
    required this.profiles,
    required this.profile,
    required this.game,
  });

  @override
  State<_GameFields> createState() => _GameFieldsState();
}

class _GameFieldsState extends State<_GameFields> {
  late final TextEditingController _n = TextEditingController(
      text: widget.profile.games[widget.game.id]?.name ?? '');
  late final TextEditingController _t = TextEditingController(
      text: widget.profile.games[widget.game.id]?.tid ?? '');

  @override
  void dispose() {
    _n.dispose();
    _t.dispose();
    super.dispose();
  }

  void _save() => widget.profiles
      .setGame(widget.profile, widget.game.id, name: _n.text, tid: _t.text);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.game.name,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _n,
                    maxLength: 16,
                    decoration: const InputDecoration(
                        labelText: 'Nombre en el juego',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder()),
                    onChanged: (_) => _save(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _t,
                    maxLength: 16,
                    decoration: const InputDecoration(
                        labelText: 'ID de entrenador',
                        counterText: '',
                        isDense: true,
                        border: OutlineInputBorder()),
                    onChanged: (_) => _save(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
