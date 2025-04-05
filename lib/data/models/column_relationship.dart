import 'package:equatable/equatable.dart';

class ColumnRelationship extends Equatable {
  final String sourceColumn;
  final String targetColumn;

  const ColumnRelationship({
    required this.sourceColumn,
    required this.targetColumn,
  });

  factory ColumnRelationship.fromMap(Map<String, dynamic> map) {
    return ColumnRelationship(
      sourceColumn: map['sourceColumn'] as String,
      targetColumn: map['targetColumn'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sourceColumn': sourceColumn,
      'targetColumn': targetColumn,
    };
  }

  void validate({
    required List<String> numericColumns,
    required List<ColumnRelationship> existingRelationships,
  }) {
    if (sourceColumn.isEmpty || targetColumn.isEmpty) {
      throw 'Both columns must be selected';
    }
    if (sourceColumn == targetColumn) {
      throw 'Source and target cannot be the same';
    }
    if (!numericColumns.contains(sourceColumn) ||
        !numericColumns.contains(targetColumn)) {
      throw 'Both columns must be numeric';
    }
    if (existingRelationships.any((r) =>
    r.sourceColumn == sourceColumn && r.targetColumn == targetColumn)) {
      throw 'This relationship already exists';
    }
  }

  @override
  List<Object> get props => [sourceColumn, targetColumn];
}