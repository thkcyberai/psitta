import 'package:flutter/material.dart';

class VoiceSelectorScreen extends StatelessWidget {
  const VoiceSelectorScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Choose Voice')),
      body: const Center(child: Text('Voice catalog loading...')));
  }
}
