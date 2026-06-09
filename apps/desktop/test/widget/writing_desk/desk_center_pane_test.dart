// Widget tests for WD-3: DeskCenterPane.
//
// Verifies: loading state, read mode shows DocumentReadingView, edit mode
// shows QuillEditor, save is called on toggle to read, and the pane builds
// under all 4 themes.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:psitta/core/theme/app_theme.dart';
import 'package:psitta/data/models/document.dart';
import 'package:psitta/data/models/psitta_document.dart';
import 'package:psitta/data/providers/providers.dart';
import 'package:psitta/data/services/preferences_service.dart';
import 'package:psitta/features/editor/chunk_editor_provider.dart';
import 'package:psitta/features/editor/document_editor_repository.dart';
import 'package:psitta/features/player/widgets/document_reading_view.dart';
import 'package:psitta/features/writing_desk/desk_center_pane.dart';
import 'package:psitta/features/writing_desk/desk_providers.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────

class MockDocumentEditorRepository extends Mock
    implements DocumentEditorRepository {}

class _TrackingChunkEditorNotifier extends ChunkEditorNotifier {
  _TrackingChunkEditorNotifier(super.repository);
  bool saveChunkTextsCalled = false;

  @override
  Future<bool> saveChunkTexts({
    required String documentId,
    required Map<String, String> chunkTexts,
    Map<String, List<Map<String, dynamic>>>? chunkFormatted,
  }) async {
    saveChunkTextsCalled = true;
    return true;
  }
}

// ── Fixtures ──────────────────────────────────────────────────────────────────

PsittaDocument _emptyDoc() => const PsittaDocument(
      id: 'doc-123',
      title: 'Test Document',
      blocks: [],
      plainText: '',
      sentences: [],
      chunkMap: [],
    );

Map<String, dynamic> _stubChunksData({bool withChunk = false}) {
  if (!withChunk) {
    return {
      'document_id': 'doc-123',
      'total_chunks': 0,
      'chunks': <dynamic>[],
      'chunk_positions': null,
    };
  }
  return {
    'document_id': 'doc-123',
    'total_chunks': 1,
    'chunks': <dynamic>[
      {
        'id': 'c1',
        'sequence_index': 0,
        'chunk_type': 'paragraph',
        'text_content': 'hello world',
        'tone': null,
        'page_number': 1,
        'character_count': 11,
        'is_edited': false,
        'edited_at': null,
        'original_text': null,
        'sentence_boundaries': null,
        'title': 'Section 1',
        'formatted_content': <dynamic>[
          <String, dynamic>{
            'type': 'paragraph',
            'runs': <dynamic>[
              <String, dynamic>{'text': 'hello world'},
            ],
          },
        ],
      },
    ],
    'chunk_positions': null,
  };
}

Document _stubDocument() => Document.fromJson(<String, dynamic>{
      'id': 'doc-123',
      'title': 'Test Document',
      'status': 'ready',
      'source_type': 'docx',
      'page_count': 1,
      'word_count': 2,
      'project_id': null,
      'cover_type': null,
      'cover_value': null,
      'created_at': '2026-06-01T00:00:00Z',
    });

// ── Pump helpers ──────────────────────────────────────────────────────────────

Future<void> _pump(
  WidgetTester tester, {
  ThemeData? theme,
  List<Override> extra = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        deskDocumentProvider('doc-123')
            .overrideWith((ref) async => _emptyDoc()),
        documentsProvider
            .overrideWith((ref) async => [_stubDocument()]),
        chunksProvider('doc-123')
            .overrideWith((ref) async => _stubChunksData()),
        ...extra,
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.creatorStudioDark,
        home: const Scaffold(
          body: DeskCenterPane(documentId: 'doc-123'),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    registerFallbackValue(<String, String>{});
    registerFallbackValue(<String, List<Map<String, dynamic>>>{});
  });

  // ── Loading state ────────────────────────────────────────────────────────
  testWidgets('loading state shows progress indicator', (tester) async {
    // Use a Completer that never resolves so no pending timer is created.
    final completer = Completer<PsittaDocument>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deskDocumentProvider('doc-123')
              .overrideWith((ref) => completer.future),
          documentsProvider.overrideWith((ref) async => [_stubDocument()]),
          chunksProvider('doc-123')
              .overrideWith((ref) async => _stubChunksData()),
        ],
        child: MaterialApp(
          theme: AppTheme.creatorStudioDark,
          home: const Scaffold(
            body: DeskCenterPane(documentId: 'doc-123'),
          ),
        ),
      ),
    );
    // Pump once without settle to catch the loading frame.
    await tester.pump();
    expect(find.byKey(const ValueKey('desk-center-loading')), findsOneWidget);
  });

  // ── Read mode ────────────────────────────────────────────────────────────
  testWidgets('read mode shows DocumentReadingView', (tester) async {
    await _pump(tester);
    expect(find.byType(DocumentReadingView), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-reading-body')), findsOneWidget);
  });

  // ── Edit mode ────────────────────────────────────────────────────────────
  testWidgets('tapping toggle-edit enters edit mode with QuillEditor',
      (tester) async {
    await _pump(tester);

    // Initial state: read mode toggle button present.
    expect(find.byKey(const ValueKey('desk-toggle-edit')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('desk-toggle-edit')));
    await tester.pumpAndSettle();

    // Edit mode: QuillEditor visible, toggle-read button present.
    expect(find.byType(quill.QuillEditor), findsAtLeastNWidgets(1));
    expect(find.byKey(const ValueKey('desk-editor-body')), findsOneWidget);
    expect(find.byKey(const ValueKey('desk-toggle-read')), findsOneWidget);
  });

  // ── Save on toggle read ──────────────────────────────────────────────────
  testWidgets('saveChunkTexts is called on toggle back to read', (tester) async {
    final mockRepo = MockDocumentEditorRepository();
    final tracker = _TrackingChunkEditorNotifier(mockRepo);

    await _pump(tester, extra: [
      chunkEditorProvider.overrideWith((ref) => tracker),
      chunksProvider('doc-123')
          .overrideWith((ref) async => _stubChunksData(withChunk: true)),
    ]);

    // Enter edit mode.
    await tester.tap(find.byKey(const ValueKey('desk-toggle-edit')));
    await tester.pumpAndSettle();

    // Exit edit mode → triggers save.
    await tester.tap(find.byKey(const ValueKey('desk-toggle-read')));
    await tester.pumpAndSettle();

    expect(tracker.saveChunkTextsCalled, isTrue);
  });

  // ── 4-skin build ─────────────────────────────────────────────────────────
  for (final themeName in ThemeNames.all) {
    testWidgets('builds under the "$themeName" theme', (tester) async {
      await _pump(tester, theme: AppTheme.forName(themeName));
      expect(tester.takeException(), isNull);
      expect(find.byType(DeskCenterPane), findsOneWidget);
    });
  }
}
