import 'package:flutter/material.dart';

import 'details.dart';
import 'models.dart';
import 'settings.dart';
import 'widgets.dart';

const _kBase = Color(0xFF2878D0);
const _kStage = Color(0xFF299B58);
const _kMega = Color(0xFFE04444);
const _kGmax = Color(0xFFE58A24);

/// Esquema de evolución como árbol. En ventanas anchas se dibuja en horizontal
/// (izquierda → derecha, cada rama en su fila); en estrechas, en vertical.
/// Megaevoluciones y Gigamax salen como ramas de la especie que las tiene.
class EvolutionChart extends StatelessWidget {
  final EvoNode tree;
  final int currentDex;
  final Map<int, Species> byDex;
  final AppSettings settings;

  /// null = automático según el ancho disponible.
  final bool? horizontal;

  const EvolutionChart({
    super.key,
    required this.tree,
    required this.currentDex,
    required this.byDex,
    required this.settings,
    this.horizontal,
  });

  static const _horizontalFrom = 600.0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return LayoutBuilder(builder: (context, box) {
      final axis = (horizontal ??
              (box.hasBoundedWidth && box.maxWidth >= _horizontalFrom))
          ? Axis.horizontal
          : Axis.vertical;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
          color: t.colorScheme.surfaceContainerLowest,
          border: Border.all(color: t.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
                spacing: 14,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
              _legend(t, _kBase, 'Desde forma base'),
              _legend(t, _kStage, 'Desde 1.ª evolución'),
              _legend(t, _kMega, 'Mega'),
              _legend(t, _kGmax, 'Gigamax'),
            ]),
            const SizedBox(height: 10),
            // Siempre desplazable en horizontal: un árbol ancho nunca se corta.
            // El árbol se centra si cabe; si no, se desplaza en horizontal.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: box.hasBoundedWidth
                      ? (box.maxWidth - 20).clamp(0.0, double.infinity)
                      : 0,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: _node(t, tree, axis, 0),
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _legend(ThemeData t, Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: c),
          const SizedBox(width: 4),
          Text(label, style: t.textTheme.labelSmall),
        ],
      );

  DexEntry? _baseEntry(Species? s) {
    if (s == null || s.entries.isEmpty) return null;
    for (final e in s.entries) {
      if (e.kind == 'base') return e;
    }
    return s.entries.first;
  }

  Widget _card(ThemeData t, DexEntry? entry, String name,
      {bool current = false, Color? border}) {
    final scheme = t.colorScheme;
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 7),
      decoration: BoxDecoration(
        color: current ? scheme.primaryContainer : scheme.surface,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: current ? scheme.primary : (border ?? scheme.outlineVariant),
          width: current ? 1.8 : 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Sprite(entry?.sprite,
              size: 52,
              pixel: settings.pixelSprites,
              threeD: settings.threeDSprites),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.textTheme.labelSmall?.copyWith(
                fontWeight: current ? FontWeight.bold : FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _arrow(ThemeData t, Axis axis, Color color, String label) {
    final text = label.trim().isEmpty
        ? null
        : ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 118),
            child: Text(label,
                textAlign: TextAlign.center,
                style: t.textTheme.labelSmall?.copyWith(color: color)),
          );
    if (axis == Axis.horizontal) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (text != null) text,
          Icon(Icons.arrow_forward, size: 22, color: color),
        ]),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (text != null) text,
        Icon(Icons.arrow_downward, size: 20, color: color),
      ]),
    );
  }

  Widget _node(ThemeData t, EvoNode node, Axis axis, int depth) {
    final species = byDex[node.dex];
    final name = species?.displayName(settings.spanish) ?? '#${node.dex}';
    final card = _card(t, _baseEntry(species), name,
        current: node.dex == currentDex);

    // Ramas: evoluciones + formas Mega/Gigamax de esta especie.
    final edges = <(Color, String, Widget)>[
      for (final (req, child) in node.to)
        (depth == 0 ? _kBase : _kStage, req, _node(t, child, axis, depth + 1)),
      for (final form in (species?.entries ?? const <DexEntry>[])
          .where((e) => e.kind == 'mega' || e.kind == 'gmax'))
        (
          form.kind == 'mega' ? _kMega : _kGmax,
          form.kind == 'mega' ? 'Megaevolución' : 'Gigamax',
          _card(
            t,
            form,
            form.kind == 'mega' ? 'Mega $name' : '$name Gigamax',
            border: form.kind == 'mega' ? _kMega : _kGmax,
          ),
        ),
    ];
    if (edges.isEmpty) return card;

    if (axis == Axis.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          card,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (color, label, child) in edges)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [_arrow(t, axis, color, label), child],
                  ),
                ),
            ],
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        card,
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (color, label, child) in edges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [_arrow(t, axis, color, label), child],
                ),
              ),
          ],
        ),
      ],
    );
  }
}
