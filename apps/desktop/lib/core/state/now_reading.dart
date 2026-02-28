import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global wallboard text shown in the top header.
/// Player screen updates this as playback moves between chunks.
///
/// v1: Chunk-level (no word timestamps yet).
/// v2: Word-level highlighting when alignment exists.
final nowReadingTextProvider = StateProvider<String>((ref) => '');
