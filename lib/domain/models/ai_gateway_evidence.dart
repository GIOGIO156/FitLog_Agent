class AiGatewayEvidence {
  const AiGatewayEvidence({
    required this.workflow,
    required this.contextObjects,
    required this.documentSources,
    required this.missingDimensions,
    required this.safetyFlags,
    required this.userFinalAction,
  });

  final String workflow;
  final List<String> contextObjects;
  final List<AiGatewayDocumentSource> documentSources;
  final List<String> missingDimensions;
  final List<String> safetyFlags;
  final String userFinalAction;

  bool get hasVisibleEvidence =>
      contextObjects.isNotEmpty ||
      documentSources.isNotEmpty ||
      missingDimensions.isNotEmpty ||
      safetyFlags.isNotEmpty;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'workflow': workflow,
      'context_objects': contextObjects,
      'document_sources': documentSources
          .map((source) => source.toJson())
          .toList(growable: false),
      'missing_dimensions': missingDimensions,
      'safety_flags': safetyFlags,
      'user_final_action': userFinalAction,
    };
  }

  factory AiGatewayEvidence.fromJson(Map<String, dynamic> json) {
    return AiGatewayEvidence(
      workflow: (json['workflow'] ?? 'auto').toString(),
      contextObjects: _stringList(json['context_objects']),
      documentSources: _documentSources(json['document_sources']),
      missingDimensions: _stringList(json['missing_dimensions']),
      safetyFlags: _stringList(json['safety_flags']),
      userFinalAction: (json['user_final_action'] ?? 'none').toString(),
    );
  }

  static AiGatewayEvidence? fromJsonOrNull(Object? value) {
    if (value is! Map) {
      return null;
    }
    return AiGatewayEvidence.fromJson(Map<String, dynamic>.from(value));
  }
}

class AiGatewayDocumentSource {
  const AiGatewayDocumentSource({
    required this.docPath,
    required this.heading,
    required this.sectionId,
    required this.status,
    required this.score,
    required this.excerpt,
  });

  final String docPath;
  final String heading;
  final String sectionId;
  final String status;
  final double score;
  final String excerpt;

  String get label => heading.trim().isEmpty ? docPath : heading;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'doc_path': docPath,
      'heading': heading,
      'section_id': sectionId,
      'status': status,
      'score': score,
      'excerpt': excerpt,
    };
  }

  factory AiGatewayDocumentSource.fromJson(Map<String, dynamic> json) {
    return AiGatewayDocumentSource(
      docPath: (json['doc_path'] ?? '').toString(),
      heading: (json['heading'] ?? '').toString(),
      sectionId: (json['section_id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      score: _doubleValue(json['score']),
      excerpt: (json['excerpt'] ?? '').toString(),
    );
  }
}

List<AiGatewayDocumentSource> _documentSources(Object? value) {
  if (value is! List) {
    return const <AiGatewayDocumentSource>[];
  }
  return value
      .whereType<Map>()
      .map((item) {
        return AiGatewayDocumentSource.fromJson(
          Map<String, dynamic>.from(item),
        );
      })
      .where((source) => source.docPath.trim().isNotEmpty)
      .toList(growable: false);
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

double _doubleValue(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
