import 'package:flutter/material.dart';

class PlayerScreen extends StatelessWidget {
  final String documentId;
  const PlayerScreen({super.key, required this.documentId});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Now Playing')),
      body: Center(child: Text('Player for document: $documentId')));
  }
}
