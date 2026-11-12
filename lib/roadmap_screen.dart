import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tarjeta del roadmap: título y cuerpo libres.
class RoadmapCard {
  final String id;
  String title;
  String body;
  bool done;
  RoadmapCard({
    required this.id,
    required this.title,
    required this.body,
    this.done = false,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'title': title, 'body': body, 'done': done};

  factory RoadmapCard.fromJson(Map<String, dynamic> j) => RoadmapCard(
        id: j['id'].toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        done: j['done'] == true,
      );
}

/// Roadmap: tarjetas para apuntar qué quieres hacer a continuación en la app.
/// Se guardan en el equipo (SharedPreferences).
class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key});

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  static const _key = 'roadmap_cards_v1';
  SharedPreferences? _prefs;
  final List<RoadmapCard> _cards = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    final cards = <RoadmapCard>[];
    if (raw != null) {
      try {
        for (final j in (jsonDecode(raw) as List)) {
          cards.add(RoadmapCard.fromJson(Map<String, dynamic>.from(j as Map)));
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _cards
        ..clear()
        ..addAll(cards);
      _loaded = true;
    });
  }

  void _save() => _prefs?.setString(
      _key, jsonEncode([for (final c in _cards) c.toJson()]));

  Future<void> _edit([RoadmapCard? card]) async {
    final title = TextEditingController(text: card?.title ?? '');
    final body = TextEditingController(text: card?.body ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(card == null ? 'Nueva tarjeta' : 'Editar tarjeta'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Título', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: body,
                minLines: 5,
                maxLines: 12,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                    labelText: 'Descripción',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    final newTitle = title.text.trim();
    final newBody = body.text.trim();
    title.dispose();
    body.dispose();
    if (ok != true || (newTitle.isEmpty && newBody.isEmpty)) return;
    setState(() {
      if (card == null) {
        _cards.insert(
          0,
          RoadmapCard(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: newTitle.isEmpty ? 'Sin título' : newTitle,
            body: newBody,
          ),
        );
      } else {
        card.title = newTitle.isEmpty ? 'Sin título' : newTitle;
        card.body = newBody;
      }
    });
    _save();
  }

  Future<void> _delete(RoadmapCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar tarjeta'),
        content: Text('¿Eliminar «${card.title}»?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cards.remove(card));
    _save();
  }

  void _toggle(RoadmapCard card) {
    setState(() => card.done = !card.done);
    _save();
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _cards.length) return;
    setState(() => _cards.insert(to, _cards.removeAt(from)));
    _save();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Roadmap')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva tarjeta'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _cards.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aún no hay tarjetas.\nCrea una para apuntar qué quieres hacer a continuación en la app.',
                      textAlign: TextAlign.center,
                      style: t.textTheme.bodyLarge,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        alignment: WrapAlignment.center,
                        children: [
                          for (var i = 0; i < _cards.length; i++)
                            _card(t, i, _cards[i]),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }

  Widget _card(ThemeData t, int index, RoadmapCard c) {
    final muted = t.colorScheme.onSurfaceVariant;
    return SizedBox(
      width: 340,
      child: Card(
        margin: EdgeInsets.zero,
        color: c.done ? t.colorScheme.surfaceContainerLow : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: c.done ? t.colorScheme.outlineVariant : t.colorScheme.primary.withValues(alpha: .5)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    c.title,
                    style: t.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: c.done ? TextDecoration.lineThrough : null,
                      color: c.done ? muted : null,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones',
                  onSelected: (v) {
                    switch (v) {
                      case 'edit':
                        _edit(c);
                      case 'done':
                        _toggle(c);
                      case 'up':
                        _move(index, index - 1);
                      case 'down':
                        _move(index, index + 1);
                      case 'delete':
                        _delete(c);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(
                        value: 'done',
                        child: Text(c.done ? 'Marcar pendiente' : 'Marcar hecha')),
                    if (index > 0)
                      const PopupMenuItem(value: 'up', child: Text('Mover antes')),
                    if (index < _cards.length - 1)
                      const PopupMenuItem(value: 'down', child: Text('Mover después')),
                    const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ]),
              if (c.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SelectableText(
                    c.body,
                    style: t.textTheme.bodyMedium?.copyWith(
                        color: c.done ? muted : null),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
