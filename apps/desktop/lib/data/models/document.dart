/// Document model — mirrors backend DocumentResponse schema.
///
/// TODO: Generate with freezed + json_serializable.
/// Run: dart run build_runner build
class Document {
  final String id;
  final String title;
  final String status;
  final String sourceType;
  final int? pageCount;
  final DateTime createdAt;

  const Document({
    required this.id,
    required this.title,
    required this.status,
    required this.sourceType,
    this.pageCount,
    required this.createdAt,
  });

  factory Document.fromJson(Map<String, dynamic> json) => Document(
        id: json['id'] as String,
        title: json['title'] as String,
        status: json['status'] as String,
        sourceType: json['source_type'] as String,
        pageCount: json['page_count'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
