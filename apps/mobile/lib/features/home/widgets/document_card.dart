import 'package:flutter/material.dart';

class DocumentCard extends StatelessWidget {
  final String title;
  final String status;
  final VoidCallback onTap;
  const DocumentCard({super.key, required this.title, required this.status, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Card(child: ListTile(title: Text(title), subtitle: Text(status),
      trailing: const Icon(Icons.play_arrow), onTap: onTap));
  }
}
