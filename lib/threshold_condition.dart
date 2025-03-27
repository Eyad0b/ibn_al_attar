// threshold_condition.dart
class ThresholdCondition {
  final String monitoredColumn;
  final double threshold;
  final String statusColumn;

  ThresholdCondition({
    required this.monitoredColumn,
    required this.threshold,
    required this.statusColumn,
  });

  Map<String, dynamic> toMap() {
    return {
      'monitoredColumn': monitoredColumn,
      'threshold': threshold,
      'statusColumn': statusColumn,
    };
  }

  factory ThresholdCondition.fromMap(Map<String, dynamic> map) {
    return ThresholdCondition(
      monitoredColumn: map['monitoredColumn'] as String,
      threshold: (map['threshold'] as num).toDouble(),
      statusColumn: map['statusColumn'] as String,
    );
  }
}