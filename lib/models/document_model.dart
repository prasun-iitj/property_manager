class DocumentModel {
  final String id;
  final String name;
  final String type;
  final String fileUrl;
  final String fileName;
  final DateTime uploadedAt;
  final bool isLegacy;

  DocumentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.fileUrl,
    required this.fileName,
    required this.uploadedAt,
    this.isLegacy = false,
  });

  factory DocumentModel.fromMap(
    String id,
    Map<String, dynamic> data, {
    bool isLegacy = false,
  }) {
    final rawUploadedAt = data['uploadedAt'];
    DateTime parsedUploadedAt = DateTime.now();

    if (rawUploadedAt is String) {
      parsedUploadedAt =
          DateTime.tryParse(rawUploadedAt) ?? DateTime.now();
    } else if (rawUploadedAt != null && rawUploadedAt.toDate != null) {
      parsedUploadedAt = rawUploadedAt.toDate();
    }

    return DocumentModel(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      fileUrl: data['fileUrl'] ?? '',
      fileName: data['fileName'] ?? '',
      uploadedAt: parsedUploadedAt,
      isLegacy: isLegacy,
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