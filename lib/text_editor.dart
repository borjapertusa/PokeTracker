import 'package:flutter/material.dart';
import 'settings.dart';

String editableText(AppSettings settings, String key, String fallback) =>
    settings.detailOverrides['text:$key'] ?? fallback;

Future<void> editTextValue(BuildContext context, AppSettings settings, String key,
    String current, String title) async {
  final controller = TextEditingController(text: editableText(settings, key, current));
  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Editar $title'),
      content: SizedBox(width: 520, child: TextField(
        controller: controller, minLines: 3, maxLines: 9,
        decoration: const InputDecoration(border: OutlineInputBorder(), alignLabelWithHint: true),
      )),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ),
  );
  if (saved == true) {
    settings.update(() => settings.detailOverrides['text:$key'] = controller.text.trim());
  }
  controller.dispose();
}
