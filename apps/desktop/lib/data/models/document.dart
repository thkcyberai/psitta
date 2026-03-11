/// Document model — mirrors backend DocumentResponse schema.
///
/// TODO: Generate with freezed + json_serializable.
/// Run: dart run build_runner build
class Document {
  const Document({
    required this.id,
    required this.title,
    required this.status,
    required this.sourceType,
    this.pageCount,
    this.wordCount,
    this.projectId,
    this.coverType,
    this.coverValue,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        sourceType: json['source_type'] as String,
        pageCount: json['page_count'] as int?,
        wordCount: (json['word_count'] ?? json['wordCount']) as int?,
        projectId: json['project_id'] as String?,
        coverType: json['cover_type'] as String?,
        coverValue: json['cover_value'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  final String id;
  final String title;
  final String status;
  final String sourceType;
  final int? pageCount;
  final int? wordCount;
  final String? projectId;
  final String? coverType;
  final String? coverValue;
  final DateTime createdAt;
}
