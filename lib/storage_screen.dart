import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:ibn_al_attar/db_helper.dart';
import 'package:ibn_al_attar/store_data_table_screen.dart';

/// Supported data types for a column.
enum DataType {
  text,
  number,
  date,
}



/// A class representing a column in the table.
class TableColumn {
  String name;
  DataType type;

  TableColumn({required this.name, required this.type});

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
    };
  }

  factory TableColumn.fromMap(Map<String, dynamic> map) {
    return TableColumn(
      name: map['name'] as String,
      type: DataType.values.firstWhere(
            (e) => e.toString() == 'DataType.${map['type']}',
        orElse: () => DataType.text,
      ),
    );
  }
}
// Add this class to manage column relationships
class ColumnRelationship {
  final String sourceColumn;
  final String targetColumn;

  ColumnRelationship({required this.sourceColumn, required this.targetColumn});

  Map<String, dynamic> toMap() {
    return {
      'sourceColumn': sourceColumn,
      'targetColumn': targetColumn,
    };
  }

  factory ColumnRelationship.fromMap(Map<String, dynamic> map) {
    return ColumnRelationship(
      sourceColumn: map['sourceColumn'] as String,
      targetColumn: map['targetColumn'] as String,
    );
  }
}


/// A class representing a row of data.
class TableRowData {
  Map<String, dynamic> data;

  TableRowData({required this.data});

  Map<String, dynamic> toMap() {
    return data;
  }

  factory TableRowData.fromMap(Map<String, dynamic> map) {
    return TableRowData(data: map);
  }
}

class StorageScreen extends StatefulWidget {
  final Map<String, dynamic>? storage;
  final String? docId; // For editing an existing storage

  const StorageScreen({Key? key, this.storage, this.docId}) : super(key: key);

  @override
  _StorageScreenState createState() => _StorageScreenState();
}

class ColumnDependency {
  final String sourceColumn;
  final String targetColumn;
  final String operation;

  ColumnDependency({
    required this.sourceColumn,
    required this.targetColumn,
    required this.operation,
  });
}

class ThresholdCondition {
  final String monitoredColumn;
  final double threshold;
  final String targetBooleanColumn;

  ThresholdCondition({
    required this.monitoredColumn,
    required this.threshold,
    required this.targetBooleanColumn,
  });
}

class _StorageScreenState extends State<StorageScreen> {
  List<TableColumn> columns = [];
  List<TableRowData> rows = [];
  String searchQuery = '';

  // PlutoGrid state manager.
  late PlutoGridStateManager stateManager;

  // A key counter that forces PlutoGrid to rebuild.
  int _gridRefreshKey = 0;

  // Controllers for adding a new column and for search.
  final TextEditingController _newColumnNameController =
  TextEditingController();
  DataType _newColumnType = DataType.text;
  final TextEditingController _searchController = TextEditingController();

  // For row selection using checkboxes.
  final Map<String, bool> _rowSelection = {};

  // Undo stack: each entry is a snapshot of the current state.
  final List<Map<String, dynamic>> _undoStack = [];

  // Focus node for keyboard events.
  final FocusNode _focusNode = FocusNode();

  final Map<String, double> lowStockThresholds = {
    'الصنف': 10,
    'داخل المحل': 5,
  };

  List<ColumnDependency> columnDependencies = [
    ColumnDependency(
      sourceColumn: 'الصادر',
      targetColumn: 'الصنف',
      operation: 'subtract',
    ),
  ];

  List<ThresholdCondition> thresholdConditions = [
    ThresholdCondition(
      monitoredColumn: 'الصنف',
      threshold: 10,
      targetBooleanColumn: 'على وشك النفاذ',
    ),
    ThresholdCondition(
      monitoredColumn: 'داخل المحل',
      threshold: 5,
      targetBooleanColumn: 'على وشك النفاذ',
    ),
  ];
  List<ColumnRelationship> columnRelationships = [];
  final _relationshipFormKey = GlobalKey<FormState>();
  String? _editingRelationshipId;
  final Map<String, dynamic> _previousValues = {};

  // Add this method to show relationship creation dialog
  void _showCreateRelationshipDialog([int? editIndex]) {
    String? source = editIndex != null
        ? columnRelationships[editIndex].sourceColumn
        : null;
    String? target = editIndex != null
        ? columnRelationships[editIndex].targetColumn
        : null;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(editIndex == null ? 'Create Relationship' : 'Edit Relationship'),
            content: Form(
              key: _relationshipFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: source,
                    decoration: const InputDecoration(labelText: 'Source Column'),
                    items: columns
                        .where((c) => c.type == DataType.number)
                        .map((c) => DropdownMenuItem(
                      value: c.name,
                      child: Text(c.name),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => source = value),
                    validator: (value) =>
                    value == null ? 'Select source column' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: target,
                    decoration: const InputDecoration(labelText: 'Target Column'),
                    items: columns
                        .where((c) => c.type == DataType.number)
                        .map((c) => DropdownMenuItem(
                      value: c.name,
                      child: Text(c.name),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => target = value),
                    validator: (value) =>
                    value == null ? 'Select target column' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_relationshipFormKey.currentState!.validate()) {
                    final newRelationship = ColumnRelationship(
                      sourceColumn: source!,
                      targetColumn: target!,
                    );

                    setState(() {
                      if (editIndex != null) {
                        columnRelationships[editIndex] = newRelationship;
                      } else {
                        columnRelationships.add(newRelationship);
                      }
                    });
                    Navigator.pop(context);
                    _updateGrid();
                  }
                },
                child: Text(editIndex == null ? 'Create' : 'Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Modify the onChanged handler
  void _handleCellChange(PlutoGridOnChangedEvent event) {
    final String columnName = event.column.field;
    final dynamic newValue = event.value;
    final String rowId = event.row.cells['id']?.value;
    final int rowIndex = rows.indexWhere((row) => row.data['id'] == rowId);

    if (rowIndex == -1) return;
    _pushUndoState();
    // Store previous value
    // _previousValues[rowId] = {
    //   ...rows[rowIndex].data,
    // };

    setState(() {
      rows[rowIndex].data[columnName] = newValue;
    });

    // Process dependencies.
    for (var dependency in columnDependencies) {
      if (dependency.sourceColumn == columnName) {
        double sourceValue = (newValue ?? 0).toDouble();
        double targetValue = (rows[rowIndex].data[dependency.targetColumn] ?? 0).toDouble();
        if (dependency.operation == 'subtract') {
          setState(() {
            rows[rowIndex].data[dependency.targetColumn] = targetValue - sourceValue;
          });
        } else if (dependency.operation == 'add') {
          setState(() {
            rows[rowIndex].data[dependency.targetColumn] = targetValue + sourceValue;
          });
        }
      }
    }
    _checkLowStock(rowIndex);
    _updateGrid();
  }


  // --- New features ---
  // Flag to track if current changes are saved.
  bool _isSaved = true;
  // A list to log update events.
  final List<String> _updateLogs = [];


  @override
  void initState() {
    super.initState();
    // Load columns and rows from Firebase storage if available.
    if (widget.storage != null) {
      if (widget.storage!['columns'] != null) {
        columns = (widget.storage!['columns'] as List)
            .map((e) => TableColumn.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        columns = [TableColumn(name: 'الصنف', type: DataType.number)];
      }
      if (widget.storage!['rows'] != null) {
        rows = (widget.storage!['rows'] as List)
            .map((e) => TableRowData.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      }
    } else {
      // Initialize default columns.
      columns = [
        TableColumn(name: 'الصنف', type: DataType.number),
        TableColumn(name: 'الوزن الكامل', type: DataType.number),
        TableColumn(name: 'المكتب', type: DataType.text),
        TableColumn(name: 'الوارد', type: DataType.number),
        TableColumn(name: 'الصادر', type: DataType.number),
        TableColumn(name: 'على وشك النفاذ', type: DataType.text),
        TableColumn(name: 'داخل المحل', type: DataType.number),
      ];
      rows = [];
    }
    _ensureRowIds();
    _initializeRowSelection();
  }

  /// Ensure each row has a unique identifier.
  void _ensureRowIds() {
    for (int i = 0; i < rows.length; i++) {
      if (!rows[i].data.containsKey('id')) {
        rows[i].data['id'] =
            DateTime.now().millisecondsSinceEpoch.toString() + "_$i";
      }
    }
  }

  void _initializeRowSelection() {
    for (var row in rows) {
      _rowSelection[row.data['id']] = false;
    }
  }

  /// Filter the rows based on the search query.
  List<TableRowData> get filteredRows {
    if (searchQuery.isEmpty) return rows;
    return rows.where((row) {
      return row.data.values.any((value) =>
      value != null &&
          value.toString().toLowerCase().contains(searchQuery.toLowerCase()));
    }).toList();
  }

  void _markUnsaved() {
    setState(() {
      _isSaved = false;
    });
  }

  // Add this new method for relationship management dialog
  void _showRelationshipsManager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Column Relationships'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: columnRelationships.length,
            itemBuilder: (context, index) {
              final relationship = columnRelationships[index];
              return ListTile(
                title: Text('${relationship.sourceColumn} → ${relationship.targetColumn}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () => _showEditRelationshipDialog(index),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteRelationship(index),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: _showCreateRelationshipDialog,
            child: const Text('Add New'),
          ),
        ],
      ),
    );
  }



  void _deleteRelationship(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: const Text('Are you sure you want to delete this relationship?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => columnRelationships.removeAt(index));
              Navigator.pop(context);
              _updateGrid();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditRelationshipDialog(int index) {
    _editingRelationshipId = columnRelationships[index].sourceColumn;
    _showCreateRelationshipDialog(index);
  }
  /// **Automatically updates dependent column values.**
  void _updateDependentColumn(String changedColumn, int rowIndex) {
    var row = rows[rowIndex];

    for (var dependency in columnDependencies) {
      if (dependency.sourceColumn == changedColumn) {
        double sourceValue = (row.data[dependency.sourceColumn] ?? 0).toDouble();
        double targetValue = (row.data[dependency.targetColumn] ?? 0).toDouble();

        switch (dependency.operation) {
          case 'subtract':
            row.data[dependency.targetColumn] = targetValue - sourceValue;
            break;
          case 'add':
            row.data[dependency.targetColumn] = targetValue + sourceValue;
            break;
        }
      }
    }

    _checkLowStock(rowIndex);
    _updateGrid();
  }

  void _checkLowStock(int rowIndex) {
    var row = rows[rowIndex];
    // For each condition, mark the target Boolean column.
    for (var condition in lowStockThresholds.keys) {
      if (row.data.containsKey(condition)) {
        double value = (row.data[condition] ?? 0).toDouble();
        setState(() {
          row.data['على وشك النفاذ'] = (value < lowStockThresholds[condition]!) ? 'True' : 'False';
        });
      }
    }
  }

  /// Force a rebuild of the PlutoGrid by updating its key.
  void _updateGrid() {
    _markUnsaved();
    // Ensure every row in rows has a selection entry.
    for (var row in rows) {
      if (!_rowSelection.containsKey(row.data['id'])) {
        _rowSelection[row.data['id']] = false;
      }
    }
    setState(() {
      _gridRefreshKey++;
    });
  }

  /// Save (or update) the table to Firestore.
  Future<void> _saveToFirebase() async {
    Map<String, dynamic> tableData = {
      'columns': columns.map((col) => col.toMap()).toList(),
      'rows': rows.map((row) => row.toMap()).toList(),
      'relationships': columnRelationships.map((r) => r.toMap()).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (widget.docId == null) {
      await FirebaseService.addStorage(tableData);
    } else {
      await FirebaseService.updateStorage(widget.docId!, tableData);
    }

    setState(() {
      _isSaved = true;
      _updateLogs.add(
          "Saved at ${DateTime.now().toLocal().toString()}\nDetails: ${jsonEncode(tableData)}");
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Table saved to Firebase!')));
  }
  /// Show a dialog to view update logs.
  void _showUpdateLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Logs'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _updateLogs.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(_updateLogs[index]),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  /// Push current state onto the undo stack.
  void _pushUndoState() {
    var state = {
      "columns": jsonEncode(columns.map((c) => c.toMap()).toList()),
      "rows": jsonEncode(rows.map((r) => r.toMap()).toList()),
    };
    _undoStack.add(state);
  }

  /// Undo the last change (Ctrl+Z).
  void _undo() {
    if (_undoStack.isNotEmpty) {
      var state = _undoStack.removeLast();
      List<dynamic> colsJson = jsonDecode(state["columns"]);
      List<dynamic> rowsJson = jsonDecode(state["rows"]);
      setState(() {
        columns = colsJson.map((e) => TableColumn.fromMap(e)).toList();
        rows = rowsJson.map((e) => TableRowData.fromMap(e)).toList();
        // Reinitialize row selections.
        _rowSelection.clear();
        for (var row in rows) {
          _rowSelection[row.data['id']] = false;
        }
      });
      _updateGrid();
    }
  }

  /// Show a dialog to edit columns.
  void _showEditColumnsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Columns"),
          content: SingleChildScrollView(
            child: Column(
              children: columns.asMap().entries.map((entry) {
                int index = entry.key;
                TableColumn col = entry.value;
                return ListTile(
                  title: Text(col.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _editColumn(index);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            )
          ],
        );
      },
    );
  }

  /// Edit column name and data type.
  void _editColumn(int index) {
    TextEditingController editController =
    TextEditingController(text: columns[index].name);
    DataType newType = columns[index].type;
    _pushUndoState();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Column'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editController,
                decoration:
                const InputDecoration(labelText: 'Column Name'),
              ),
              const SizedBox(height: 10),
              DropdownButton<DataType>(
                value: newType,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      newType = value;
                    });
                  }
                },
                items: DataType.values.map((dt) {
                  return DropdownMenuItem(
                    value: dt,
                    child: Text(dt.toString().split('.').last),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  String oldName = columns[index].name;
                  String newName = editController.text.trim();
                  columns[index].name = newName;
                  columns[index].type = newType;
                  if (oldName != newName) {
                    for (var row in rows) {
                      var value = row.data[oldName];
                      row.data.remove(oldName);
                      row.data[newName] = value;
                    }
                  }
                });
                Navigator.pop(context);
                _updateGrid();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Add a new column via a dialog.
  void _addColumn() {
    _pushUndoState();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Column'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _newColumnNameController,
                decoration: const InputDecoration(labelText: 'Column Name'),
              ),
              DropdownButton<DataType>(
                value: _newColumnType,
                onChanged: (newVal) {
                  if (newVal != null) {
                    setState(() {
                      _newColumnType = newVal;
                    });
                  }
                },
                items: DataType.values.map((dt) {
                  return DropdownMenuItem(
                    value: dt,
                    child: Text(dt.toString().split('.').last),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                _newColumnNameController.clear();
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_newColumnNameController.text.trim().isEmpty) return;
                setState(() {
                  String newColName =
                  _newColumnNameController.text.trim();
                  columns.add(
                      TableColumn(name: newColName, type: _newColumnType));
                  // Initialize the new column in every existing row.
                  for (var row in rows) {
                    row.data[newColName] = null;
                  }
                });
                _newColumnNameController.clear();
                Navigator.pop(context);
                _updateGrid();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  /// Show a dialog for selecting columns for a given action.
  void _columnAction(String action) {
    List<String> availableColumns = columns
        .map((col) => col.name)
        .where((name) => name != 'id')
        .toList();
    List<String> selected = [];
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Select Columns for $action"),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: availableColumns.map((colName) {
                    return CheckboxListTile(
                      title: Text(colName),
                      value: selected.contains(colName),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            selected.add(colName);
                          } else {
                            selected.remove(colName);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                if (action == "delete") {
                  _deleteColumns(selected);
                } else if (action == "duplicate") {
                  _duplicateColumns(selected);
                } else if (action == "copy") {
                  _copyColumns(selected);
                }
              },
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// Delete columns given a list of column names.
  void _deleteColumns(List<String> selectedColumns) {
    _pushUndoState();
    setState(() {
      for (String colName in selectedColumns) {
        columns.removeWhere((col) => col.name == colName);
        for (var row in rows) {
          row.data.remove(colName);
        }
      }
    });
    _updateGrid();
  }

  /// Duplicate columns given a list of column names.
  void _duplicateColumns(List<String> selectedColumns) {
    _pushUndoState();
    setState(() {
      for (String colName in selectedColumns) {
        String newColName = colName + " (copy)";
        TableColumn? orig = columns.firstWhere(
                (col) => col.name == colName,
            orElse: () =>
                TableColumn(name: colName, type: DataType.text));
        DataType type = orig.type;
        columns.add(TableColumn(name: newColName, type: type));
        for (var row in rows) {
          row.data[newColName] = row.data[colName];
        }
      }
    });
    _updateGrid();
  }

  /// Copy columns (their definitions) to clipboard as JSON.
  void _copyColumns(List<String> selectedColumns) {
    List<Map<String, dynamic>> copiedColumns = [];
    for (String colName in selectedColumns) {
      TableColumn? tableCol = columns.firstWhere(
              (col) => col.name == colName,
          orElse: () =>
              TableColumn(name: colName, type: DataType.text));
      copiedColumns.add(tableCol.toMap());
    }
    Clipboard.setData(
        ClipboardData(text: jsonEncode(copiedColumns)));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Selected columns copied to clipboard')));
  }

  /// Delete selected rows using checkboxes.
  void _deleteSelectedRows() {
    List<String> selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No rows selected')));
      return;
    }
    // Confirm deletion.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content:
        const Text('Are you sure you want to delete the selected rows?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _pushUndoState();
                setState(() {
                  rows.removeWhere((row) =>
                      selectedIds.contains(row.data['id']));
                  // Clear selection.
                  for (var id in selectedIds) {
                    _rowSelection[id] = false;
                  }
                });
                _updateGrid();
              },
              child: const Text('Delete')),
        ],
      ),
    );
  }

  /// Duplicate selected rows.
  void _duplicateSelectedRows() {
    List<String> selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No rows selected')));
      return;
    }
    _pushUndoState();
    setState(() {
      for (String id in selectedIds) {
        TableRowData? original = rows.firstWhere(
                (row) => row.data['id'] == id,
            orElse: () => TableRowData(data: {}));
        if (original.data.isNotEmpty) {
          var newData = Map<String, dynamic>.from(original.data);
          newData['id'] =
              DateTime.now().millisecondsSinceEpoch.toString();
          rows.add(TableRowData(data: newData));
        }
      }
    });
    _updateGrid();
  }

  /// Copy selected rows to clipboard as JSON.
  void _copySelectedRows() {
    List<String> selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No rows selected')));
      return;
    }
    List<Map<String, dynamic>> copiedData = [];
    for (var row in rows) {
      if (selectedIds.contains(row.data['id'])) {
        copiedData.add(row.data);
      }
    }
    Clipboard.setData(
        ClipboardData(text: jsonEncode(copiedData)));
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
            Text('Selected rows copied to clipboard')));
  }

  /// Show a dialog to add a new row.
  void _showAddRowDialog() {
    // Create a controller for each (non-hidden) column.
    Map<String, TextEditingController> controllers = {};
    for (var col in columns) {
      if (col.name == 'id') continue;
      controllers[col.name] = TextEditingController();
    }
    _pushUndoState();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Row'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: controllers.entries.map((entry) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TextField(
                    controller: entry.value,
                    decoration:
                    InputDecoration(labelText: entry.key),
                    keyboardType: TextInputType.text,
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Map<String, dynamic> newRowData = {};
                newRowData['id'] =
                    DateTime.now().millisecondsSinceEpoch.toString();
                controllers.forEach((colName, controller) {
                  String value = controller.text;
                  DataType type = DataType.text;
                  TableColumn? tableCol = columns.firstWhere(
                          (col) => col.name == colName,
                      orElse: () =>
                          TableColumn(name: colName, type: DataType.text));
                  type = tableCol.type;
                  if (type == DataType.number) {
                    newRowData[colName] = num.tryParse(value) ?? 0;
                  } else {
                    newRowData[colName] = value;
                  }
                });
                setState(() {
                  rows.add(TableRowData(data: newRowData));
                  _rowSelection[newRowData['id']] = false;
                });
                Navigator.pop(context);
                _updateGrid();
              },
              child: const Text('Add Row'),
            ),
          ],
        );
      },
    );
  }

  /// Edit a cell value.
  void _editCell(TableRowData row, String columnName, DataType type) {
    dynamic currentValue = row.data[columnName];
    TextEditingController controller =
    TextEditingController(text: currentValue?.toString() ?? '');
    _pushUndoState();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Edit $columnName'),
          content: TextField(
            controller: controller,
            keyboardType: type == DataType.number
                ? TextInputType.number
                : TextInputType.text,
            decoration:
            const InputDecoration(hintText: 'Enter new value'),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  var value = controller.text;
                  if (type == DataType.number) {
                    row.data[columnName] = num.tryParse(value) ?? 0;
                  } else {
                    row.data[columnName] = value;
                  }
                });
                Navigator.pop(context);
                int rowIndex = rows.indexWhere((r) => r.data['id'] == row.data['id']);
                if (rowIndex != -1) {
                  _updateDependentColumn(columnName, rowIndex);
                }
                _updateGrid();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _newColumnNameController.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Build PlutoGrid columns.
    // First column: for row selection checkboxes.
    PlutoColumn selectColumn = PlutoColumn(
      title: '',
      field: 'select', // not used for cell data; we use our own _rowSelection map
      type: PlutoColumnType.text(),
      enableSorting: false,
      // Removed enableEditing since it's not supported.
      renderer: (rendererContext) {
        String rowId = rendererContext.row.cells['id']?.value;
        bool selected = _rowSelection[rowId] ?? false;
        return Checkbox(
          value: selected,
          onChanged: (value) {
            setState(() {
              _rowSelection[rowId] = value ?? false;
            });
          },
        );
      },
    );

    // Other columns come from our model.
    List<PlutoColumn> modelColumns = columns.map((col) {
      return PlutoColumn(
        title: col.name,
        field: col.name,
        type: col.type == DataType.number
            ? PlutoColumnType.number()
            : PlutoColumnType.text(),
      );
    }).toList();

    // Also add a hidden 'id' column.
    PlutoColumn idColumn = PlutoColumn(
      title: 'ID',
      field: 'id',
      type: PlutoColumnType.text(),
      readOnly: true,
      hide: true,
    );

    List<PlutoColumn> plutoColumns = [selectColumn, idColumn, ...modelColumns];

    return WillPopScope(
      onWillPop: () async {
        if (!_isSaved) {
          // Ask user to save before leaving.
          bool? save = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unsaved Changes'),
              content: const Text('You have unsaved changes. Do you want to save before leaving?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Discard'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Save'),
                ),
              ],
            ),
          );
          if (save == true) {
            await _saveToFirebase();
          }
        }
        return true;
      },
      child: RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.keyZ &&
            (event.isControlPressed || event.isMetaPressed)) {
          _undo();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title:
          Text(widget.storage == null ? 'Add Storage' : 'Edit Storage'),
          actions: [
            IconButton(
              icon: const Icon(Icons.remove_red_eye),
              tooltip: 'View Updates',
              onPressed: _showUpdateLogs,
            ),
            IconButton(
              icon: const Icon(Icons.link),
              onPressed: _showRelationshipsManager,
              tooltip: 'Manage Relationships',
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Columns',
              onPressed: _showEditColumnsDialog,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Row',
              onPressed: _showAddRowDialog,
            ),
            IconButton(
              icon: const Icon(Icons.view_column),
              tooltip: 'Add Column',
              onPressed: _addColumn,
            ),
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save Table to Firebase',
              onPressed: _saveToFirebase,
            ),
            // Popup menu for row actions.
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_rows') {
                  _deleteSelectedRows();
                } else if (value == 'duplicate_rows') {
                  _duplicateSelectedRows();
                } else if (value == 'copy_rows') {
                  _copySelectedRows();
                }
              },
              icon: const Icon(Icons.more_vert),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'delete_rows',
                    child: Text('Delete Selected Rows')),
                const PopupMenuItem(
                    value: 'duplicate_rows',
                    child: Text('Duplicate Selected Rows')),
                const PopupMenuItem(
                    value: 'copy_rows',
                    child: Text('Copy Selected Rows')),
              ],
            ),
            // Popup menu for column actions via custom dialog.
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete_columns') {
                  _columnAction("delete");
                } else if (value == 'duplicate_columns') {
                  _columnAction("duplicate");
                } else if (value == 'copy_columns') {
                  _columnAction("copy");
                }
              },
              icon: const Icon(Icons.more_horiz),
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'delete_columns',
                    child: Text('Delete Selected Columns')),
                const PopupMenuItem(
                    value: 'duplicate_columns',
                    child: Text('Duplicate Selected Columns')),
                const PopupMenuItem(
                    value: 'copy_columns',
                    child: Text('Copy Selected Columns')),
              ],
            ),
          ],

        ),
        body: Column(
          children: [
            // "Select All" checkbox above the grid.
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Checkbox(
                    value: rows.isNotEmpty &&
                        rows.every(
                                (row) => _rowSelection[row.data['id']] ?? false),
                    onChanged: (value) {
                      setState(() {
                        for (var row in rows) {
                          _rowSelection[row.data['id']] = value ?? false;
                        }
                      });
                      _updateGrid();
                    },
                  ),
                  const Text("Select All"),
                ],
              ),
            ),
            // Search field.
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  labelText: 'Search',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    searchQuery = val;
                  });
                  _updateGrid();
                },
              ),
            ),
            Expanded(
              child: PlutoGrid(
                key: ValueKey(_gridRefreshKey),
                columns: plutoColumns,
                rows: filteredRows.map((row) {
                  return PlutoRow(
                    cells: {
                      'select': PlutoCell(value: false), // placeholder; not used
                      'id': PlutoCell(value: row.data['id']),
                      for (var col in columns)
                        col.name: PlutoCell(value: row.data[col.name]),
                    },
                  );
                }).toList(),
                onLoaded: (PlutoGridOnLoadedEvent event) {
                  stateManager = event.stateManager;
                },
                onChanged: _handleCellChange,
                configuration: PlutoGridConfiguration(
                  columnSize: PlutoGridColumnSizeConfig(
                    autoSizeMode: PlutoAutoSizeMode.scale,
                  ),
                  style: PlutoGridStyleConfig(
                      rowColor: Colors.red.withOpacity(0.2)
                    // (PlutoRowColorContext context) {
                    //   final isLow = context.row.cells['على وشك النفاذ']?.value ?? false;
                    //   return isLow;}
                  ),
                ),
              ),
            ),
          ],
        ),
      ),),
    );
  }
}