import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'progress.dart';

void _snack(BuildContext context, String msg) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

/// Copia el progreso (JSON) al portapapeles.
Future<void> exportProgress(BuildContext context, Progress p) async {
  await Clipboard.setData(ClipboardData(text: p.export()));
  if (context.mounted) _snack(context, 'Progreso copiado al portapapeles');
}

/// Pide un JSON exportado y lo combina con el progreso actual.
Future<void> importProgress(BuildContext context, Progress p) async {
  final ctrl = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Importar progreso'),
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration:
              const InputDecoration(hintText: 'Pega aquí el JSON exportado'),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
            onPressed: () => Navigator.pop(c, ctrl.text),
            child: const Text('Importar')),
      ],
    ),
  );
  if (text == null || !context.mounted) return;
  _snack(context, p.import(text) ? 'Progreso combinado' : 'JSON no válido');
}
