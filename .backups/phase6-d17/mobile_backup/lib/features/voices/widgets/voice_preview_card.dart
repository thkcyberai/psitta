import 'package:flutter/material.dart';

class VoicePreviewCard extends StatelessWidget {
  final String voiceName;
  final String language;
  final VoidCallback onPreview;
  final VoidCallback onSelect;
  const VoicePreviewCard({super.key, required this.voiceName,
    required this.language, required this.onPreview, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(voiceName), subtitle: Text(language),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(icon: const Icon(Icons.volume_up), onPressed: onPreview),
        IconButton(icon: const Icon(Icons.check_circle_outline), onPressed: onSelect),
      ])));
  }
}
