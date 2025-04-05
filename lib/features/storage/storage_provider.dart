// lib/features/storage/storage_provider.dart
import 'package:flutter/foundation.dart';
import 'package:ibn_al_attar/data/models/column_relationship.dart';
import 'package:ibn_al_attar/data/models/table_column.dart';
import 'package:ibn_al_attar/data/models/threshold_condition.dart';


class StorageProvider with ChangeNotifier {
  List<TableColumn> _columns = [];
  List<Map<String, dynamic>> _rows = [];
  List<ColumnRelationship> _relationships = [];
  List<ThresholdCondition> _thresholds = [];

  // Getters
  List<TableColumn> get columns => _columns;
  List<Map<String, dynamic>> get rows => _rows;
  List<ColumnRelationship> get relationships => _relationships;
  List<ThresholdCondition> get thresholds => _thresholds;

  // Initialize from Firestore data
  void initialize({
    required List<TableColumn> columns,
    required List<Map<String, dynamic>> rows,
    required List<ColumnRelationship> relationships,
    required List<ThresholdCondition> thresholds,
  }) {
    _columns = columns;
    _rows = rows;
    _relationships = relationships;
    _thresholds = thresholds;
    notifyListeners();
  }

  // Relationship management
  void addRelationship(ColumnRelationship relationship) {
    _relationships.add(relationship);
    notifyListeners();
  }

  void updateRelationship(int index, ColumnRelationship newRelationship) {
    _relationships[index] = newRelationship;
    notifyListeners();
  }

  void deleteRelationship(int index) {
    _relationships.removeAt(index);
    notifyListeners();
  }

  // Column operations
  void addColumn(TableColumn column) {
    _columns.add(column);
    // Initialize column in all rows
    for (var row in _rows) {
      row[column.name] = column.type == DataType.number ? 0 : '';
    }
    notifyListeners();
  }

  // Threshold management
  void addThreshold(ThresholdCondition threshold) {
    _thresholds.add(threshold);
    notifyListeners();
  }

  // State validation
  bool get isValidState {
    return _columns.isNotEmpty &&
        _rows.every((row) => row.keys.length == _columns.length);
  }

  // Clear all data
  void clear() {
    _columns = [];
    _rows = [];
    _relationships = [];
    _thresholds = [];
    notifyListeners();
  }

  // Convert to Firestore format
  Map<String, dynamic> toFirestoreFormat() {
    return {
      'columns': _columns.map((c) => c.toMap()).toList(),
      'rows': _rows,
      'relationships': _relationships.map((r) => r.toMap()).toList(),
      'thresholds': _thresholds.map((t) => t.toMap()).toList(),
    };
  }
}