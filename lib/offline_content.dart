import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pokepc_dataset.dart';
import 'pokepc_local_repository.dart';
import 'settings.dart';

class OfflineContentScreen extends StatefulWidget {
  final AppSettings settings;
  const OfflineContentScreen({super.key, required this.settings});

  @override
  State<OfflineContentScreen> createState() => _OfflineContentScreenState();
}

class _OfflineContentScreenState extends State<OfflineContentScreen> {
  Map<String, bool> _files = {};
  int _assetCount = 0;
  Map<String, dynamic>? _installed;
  PokepcLocalSummary _localSummary = const PokepcLocalSummary.notInstalled();
  bool _updating = false;
  int _completed = 0;
  int _total = 1;
  String _progressLabel = '';
  String? _updateError;

  @override
  void initState() {
    super.initState();
    _inspect();
  }

  Future<void> _inspect() async {
    const paths = <String>[
      'assets/data/pokedex.json',
      'assets/data/games.json',
      'assets/data/details.json',
      'assets/data/items.json',
      'assets/data/machines.json',
      'assets/data/za_machines.json',
    ];
    final result = <String, bool>{};
    for (final path in paths) {
      try {
        await rootBundle.loadString(path);
        result[path] = true;
      } catch (_) {
        result[path] = false;
      }
    }
    var count = 0;
    try {
      final manifest = jsonDecode(await rootBundle.loadString('AssetManifest.json')) as Map;
      count = manifest.keys
          .where((k) => k.startsWith('assets/sprites/') ||
              k.startsWith('assets/sprites3d/') ||
              k.startsWith('assets/items/'))
          .length;
    } catch (_) {}
    final installed = await PokepcDatasetUpdater.readInstalledMetadata();
    final localSummary = await PokepcLocalRepository.inspect();
    if (mounted) {
      setState(() {
        _files = result;
        _assetCount = count;
        _installed = installed;
        _localSummary = localSummary;
      });
    }
  }

  Future<void> _updateDataset() async {
    if (_updating) return;
    setState(() {
      _updating = true;
      _completed = 0;
      _total = 1;
      _progressLabel = 'Preparando descarga…';
      _updateError = null;
    });
    try {
      final result = await PokepcDatasetUpdater.update(
        onProgress: (message, completed, total) {
          if (!mounted) return;
          setState(() {
            _progressLabel = message;
            _completed = completed;
            _total = total < 1 ? 1 : total;
          });
        },
      );
      if (!mounted) return;
      await _inspect();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.alreadyLatest
            ? 'PokéPC ${result.version} ya está actualizado.'
            : 'PokéPC ${result.version}: ${result.files} archivos y ${result.icons} iconos HOME 3D descargados.'),
      ));
    } catch (error) {
      if (!mounted) return;
      setState(() => _updateError = error.toString());
    } finally {
      if (mounted) setState(() => _updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _files.values.where((v) => v).length;
    final progress = (_completed / _total).clamp(0.0, 1.0);
    final installedVersion = _installed?['version']?.toString();
    final snapshotReady = _installed?['snapshotSchema'] == 3;
    final installedAt = _installed?['downloadedAtUtc']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Contenido local')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.offline_bolt_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text('Modo sin conexión',
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  const Text(
                    'Los catálogos descargados se guardan en el disco y estarán disponibles aunque no tengas conexión. La conexión solo será necesaria para buscar y descargar actualizaciones.',
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('No utilizar Internet para imágenes'),
                    subtitle: const Text('Usar exclusivamente recursos incluidos en el equipo'),
                    value: widget.settings.offlineMode,
                    onChanged: (v) => widget.settings.update(
                        () => widget.settings.offlineMode = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Base de datos de PokéPC',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.storage_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        installedVersion == null
                            ? 'Todavía no hay una base de datos de PokéPC instalada'
                            : snapshotReady
                                ? 'PokéPC Dataset v$installedVersion'
                                : 'Hay una copia antigua de PokéPC que debe actualizarse',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (installedVersion != null)
                      const Icon(Icons.check_circle, color: Colors.green),
                  ]),
                  if (installedAt != null) ...[
                    const SizedBox(height: 8),
                    Text('Descargada: ${_formatDate(installedAt)}',
                        style: Theme.of(context).textTheme.bodySmall),
                    Text(
                      '${_installed?['pokemonCount'] ?? 0} registros Pokémon · ${_installed?['gameCount'] ?? 0} juegos · ${_installed?['pokedexCount'] ?? 0} Pokédex',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_localSummary.installed) ...[
                    const SizedBox(height: 6),
                    Text(
                      '${_localSummary.homeIcons} iconos HOME 3D disponibles localmente',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _updating ? null : _updateDataset,
                      icon: _updating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_download_outlined),
                      label: Text(_updating
                          ? 'Descargando base de datos…'
                          : installedVersion == null || !snapshotReady
                              ? 'Descargar / reparar base de datos'
                              : 'Buscar y descargar actualizaciones'),
                    ),
                  ),
                  if (_updating) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 6),
                    Text('$_completed de $_total · $_progressLabel',
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (_updateError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'No se pudo completar la actualización. La base de datos anterior se ha mantenido.\n$_updateError',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    'Almacenamiento portable: ${PokepcDatasetUpdater.portableDataDirectory.path}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Se descarga una instantánea estable de PokéPC v8, sus traducciones ES-ES/inglés y los iconos HOME 3D disponibles. Si la versión no ha cambiado, se evita repetir la descarga. La instalación anterior solo se sustituye cuando la nueva copia termina correctamente.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Catálogos incluidos en la versión actual',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text('$ready de ${_files.length} catálogos heredados encontrados en el paquete inicial.'),
          const SizedBox(height: 8),
          for (final entry in _files.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                entry.value ? Icons.check_circle : Icons.warning_amber_rounded,
                color: entry.value
                    ? Colors.green
                    : Theme.of(context).colorScheme.error,
              ),
              title: Text(entry.key.split('/').last),
              subtitle: Text(entry.value
                  ? 'Disponible en los recursos iniciales'
                  : 'No incluido en los recursos iniciales'),
            ),
          const Divider(height: 28),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: const Text('Imágenes e iconos iniciales'),
            subtitle: Text('$_assetCount recursos locales detectados en sprites, HOME 3D e iconos de objetos.'),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _updating ? null : _inspect,
              icon: const Icon(Icons.refresh),
              label: const Text('Volver a comprobar'),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(parsed.day)}/${two(parsed.month)}/${parsed.year} ${two(parsed.hour)}:${two(parsed.minute)}';
  }
}
