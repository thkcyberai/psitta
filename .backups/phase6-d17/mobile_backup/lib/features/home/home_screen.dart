import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Psitta')),
      body: const Center(child: Text('Upload a document to get started')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {}, icon: const Icon(Icons.upload_file), label: const Text('Upload')),
    );
  }
}
