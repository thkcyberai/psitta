/// Fixed-window chunk slicer for the M13 unified DOCX editor.
///
/// The unified editor holds the whole document inside a single Quill
/// Document. At save time the flat block-dict list is mechanically
/// partitioned into ~500-word chunks so the existing per-chunk backend
/// storage and TTS synthesis pipeline continue to work unchanged.
///
/// M13.1a ships this slicer with a simple forward-greedy packer: fill the
/// current chunk until it crosses the target word count, then cut. M13.1b
/// will add chunk-preservation (content-hash + positional matching against
/// the pre-edit snapshot) so unchanged chunks keep their TTS audio cache.
library;

/// Target words per sliced chunk. ~500 words = ~3000 characters ≈ 2
/// minutes of synthesized speech, which matches the existing backend
/// ingest-time chunking cadence closely enough for TTS cache behavior.
const int kTargetChunkWords = 500;

/// A single chunk produced by [sliceBlocksIntoChunks].
///
/// Contains the block-dict slice (what the backend will store in
/// `formatted_content`), the concatenated plain text (what the backend
/// will store in `text_content`), and the word count used by the slicer
/// (useful for diagnostics and the M13.1b diff check).
class SlicedChunk {
  const SlicedChunk({
    required this.blockDicts,
    required this.plainText,
    required this.wordCount,
  });

  final List<Map<String, dynamic>> blockDicts;
  final String plainText;
  final int wordCount;
}

/// Partition a flat block-dict list into ~[targetWords] chunks.
///
/// Cuts are block-aligned: a block is never split across chunks. The
/// final chunk may be under-full (typical). An empty document yields one
/// empty paragraph chunk so the backend's non-null text_content
/// invariant holds.
List<SlicedChunk> sliceBlocksIntoChunks(
  List<Map<String, dynamic>> blockDicts, {
  int targetWords = kTargetChunkWords,
}) {
  final chunks = <SlicedChunk>[];
  var currentBlocks = <Map<String, dynamic>>[];
  var currentWords = 0;
  final currentText = StringBuffer();

  for (final block in blockDicts) {
    final runs = (block['runs'] as List?) ?? const [];
    final blockText = runs
        .map((r) => ((r as Map)['text'] as String?) ?? '')
        .join();
    final blockWords = blockText
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .length;

    currentBlocks.add(block);
    currentWords += blockWords;
    if (currentText.isNotEmpty) currentText.write('\n\n');
    currentText.write(blockText);

    if (currentWords >= targetWords) {
      chunks.add(SlicedChunk(
        blockDicts: List<Map<String, dynamic>>.from(currentBlocks),
        plainText: currentText.toString(),
        wordCount: currentWords,
      ));
      currentBlocks = <Map<String, dynamic>>[];
      currentWords = 0;
      currentText.clear();
    }
  }

  if (currentBlocks.isNotEmpty) {
    chunks.add(SlicedChunk(
      blockDicts: currentBlocks,
      plainText: currentText.toString(),
      wordCount: currentWords,
    ));
  }

  // Empty-document guarantee: the backend's document_chunks row was
  // seeded with one empty paragraph, so a save after no edits must still
  // emit one chunk that round-trips to the same shape.
  if (chunks.isEmpty) {
    chunks.add(const SlicedChunk(
      blockDicts: [
        {
          'type': 'paragraph',
          'runs': [
            {'text': ''}
          ]
        }
      ],
      plainText: '',
      wordCount: 0,
    ));
  }

  return chunks;
}
