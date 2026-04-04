class DocumentModel {
  final String id;
  final String name;
  final String type;
  final String fileUrl;
  final String fileName;
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.uploadedAt,
  });

  factory DocumentModel.fromMap(String id, Map<String, dynamic> data) {
    return DocumentModel(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      uploadedAt: DateTime.parse(data['uploadedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'uploadedAt': uploadedAt.toIso8601String(),
    };
  }
}