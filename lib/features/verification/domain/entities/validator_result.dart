class ValidatorResult {
  final bool passed;
  final String validatorName; // e.g. "GPS Geofence", "In-App Fresh Capture", "Object Detection", "Duration", "Word Count", "Walking Distance", "Drawing Canvas", "Gameplay Session"
  final double confidence;
  final String? actualValue; // e.g. "45m", "In-App Camera Capture", "flower (confidence: 0.94)", "10:15", "120 words"
  final String? requiredValue; // e.g. "within 75m", "Fresh In-App Photo", "flower", "10:00", "100 words"
  final String message;

  const ValidatorResult({
    required this.passed,
    required this.validatorName,
    this.confidence = 1.0,
    this.actualValue,
    this.requiredValue,
    required this.message,
  });

  Map<String, dynamic> toJson() {
    return {
      'passed': passed,
      'validatorName': validatorName,
      'confidence': confidence,
      'actualValue': actualValue,
      'requiredValue': requiredValue,
      'message': message,
    };
  }

  factory ValidatorResult.fromJson(Map<String, dynamic> json) {
    return ValidatorResult(
      passed: json['passed'] as bool? ?? false,
      validatorName: json['validatorName'] as String? ?? 'Validator',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 1.0,
      actualValue: json['actualValue'] as String?,
      requiredValue: json['requiredValue'] as String?,
      message: json['message'] as String? ?? '',
    );
  }
}

class VerificationReport {
  final bool isSuccessful;
  final List<ValidatorResult> results;
  final String overallMessage;

  const VerificationReport({
    required this.isSuccessful,
    required this.results,
    required this.overallMessage,
  });

  int get passedCount => results.where((r) => r.passed).length;
  int get totalCount => results.length;
  bool get allPassed => results.isNotEmpty && results.every((r) => r.passed);
}
