import 'package:equatable/equatable.dart';

class ThresholdCondition extends Equatable {
  final String monitoredColumn;
  final double threshold;
  // final String statusColumn;
  final String targetBooleanColumn;

  const ThresholdCondition( {
    required this.monitoredColumn,
    required this.threshold,
    // required this.statusColumn,
    required this.targetBooleanColumn,
  });

  factory ThresholdCondition.fromMap(Map<String, dynamic> map) {
    return ThresholdCondition(
      targetBooleanColumn: map['targetBooleanColumn'] as String,
      monitoredColumn: map['monitoredColumn'] as String,
      threshold: (map['threshold'] as num).toDouble(),
      // statusColumn: map['statusColumn'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'monitoredColumn': monitoredColumn,
      'threshold': threshold,
      'targetBooleanColumn': targetBooleanColumn,
      // 'statusColumn': statusColumn,
    };
  }

  void validate(List<String> existingColumns) {
    if (!existingColumns.contains(monitoredColumn)) {
      throw 'Monitored column does not exist';
    }
    if (threshold <= 0) {
      throw 'Threshold must be positive';
    }
  }

  @override
  List<Object> get props => [monitoredColumn, threshold, targetBooleanColumn];
}