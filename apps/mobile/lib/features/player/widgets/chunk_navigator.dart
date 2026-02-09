import 'package:flutter/material.dart';

class ChunkNavigator extends StatelessWidget {
  final List<String> chunkTitles;
  final int currentIndex;
  final ValueChanged<int> onChunkSelected;
  const ChunkNavigator({super.key, required this.chunkTitles,
    required this.currentIndex, required this.onChunkSelected});
  @override
  Widget build(BuildContext context) {
    return ListView.builder(shrinkWrap: true, itemCount: chunkTitles.length,
      itemBuilder: (context, index) => ListTile(dense: true,
        selected: index == currentIndex, title: Text(chunkTitles[index]),
        onTap: () => onChunkSelected(index)));
  }
}
