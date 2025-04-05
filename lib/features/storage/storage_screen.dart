import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:provider/provider.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/widgets/custom_dialog.dart';
import 'package:ibn_al_attar/data/models/column_dependency.dart';
import 'package:ibn_al_attar/data/models/column_relationship.dart';
import 'package:ibn_al_attar/data/models/table_column.dart';
import 'package:ibn_al_attar/data/models/table_row.dart';
import 'package:ibn_al_attar/data/models/threshold_condition.dart';
import 'package:ibn_al_attar/data/repositories/storage_repository.dart';

class StorageScreen extends StatefulWidget {
  final Map<String, dynamic>? storage;
  final String? docId;

  const StorageScreen({Key? key, this.storage, this.docId}) : super(key: key);

  @override
  _StorageScreenState createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  // State variables
  late List<TableColumn> columns;
  late List<TableRowData> rows;
  String searchQuery = '';
  late PlutoGridStateManager stateManager;
  int _gridRefreshKey = 0;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _newColumnNameController = TextEditingController();
  DataType _newColumnType = DataType.text;
  final Map<String, bool> _rowSelection = {};
  final List<Map<String, dynamic>> _undoStack = [];
  final FocusNode _focusNode = FocusNode();
  bool _isSaved = true;
  final List<String> _updateLogs = [];
  final List<ColumnRelationship> columnRelationships = [];
  final GlobalKey<FormState> _relationshipFormKey = GlobalKey<FormState>();
  String? _editingRelationshipId;
  final Map<String, dynamic> _previousValues = {};
  bool _isFullScreen = false;


  // Constants
  final List<ColumnDependency> columnDependencies = [
    ColumnDependency(
      sourceColumn: AppStrings.outgoing,
      targetColumn: AppStrings.product,
      operation: 'subtract',
    ),
  ];

  final List<ThresholdCondition> thresholdConditions = [
    ThresholdCondition(
      monitoredColumn: AppStrings.product,
      threshold: 10,
      targetBooleanColumn: AppStrings.lowStockStatus,
    ),
    ThresholdCondition(
      monitoredColumn: AppStrings.inStore,
      threshold: 5,
      targetBooleanColumn: AppStrings.lowStockStatus,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initializeStorageData();
    _ensureRowIds();
    _initializeRowSelection();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newColumnNameController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /* Initialization Methods */
  void _initializeStorageData() {
    if (widget.storage != null) {
      columns = (widget.storage!['columns'] as List)
          .map((e) => TableColumn.fromMap(Map<String, dynamic>.from(e)))
          .toList();
      rows = (widget.storage!['rows'] as List)
          .map((e) => TableRowData.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      columns = defaultColumns;
      rows = [];
    }
  }

  List<TableColumn> get defaultColumns => [
    TableColumn(name: AppStrings.product, type: DataType.number),
    TableColumn(name: AppStrings.fullWeight, type: DataType.number),
    TableColumn(name: AppStrings.office, type: DataType.text),
    TableColumn(name: AppStrings.incoming, type: DataType.number),
    TableColumn(name: AppStrings.outgoing, type: DataType.number),
    TableColumn(name: AppStrings.lowStockStatus, type: DataType.text),
    TableColumn(name: AppStrings.inStore, type: DataType.number),
  ];

  void _ensureRowIds() {
    for (int i = 0; i < rows.length; i++) {
      if (!rows[i].data.containsKey('id')) {
        rows[i].data['id'] = '${DateTime.now().millisecondsSinceEpoch}_$i';
      }
    }
  }

  void _initializeRowSelection() {
    for (var row in rows) {
      _rowSelection[row.data['id']] = false;
    }
  }

  /* UI Building Methods */
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleWillPop,
      child: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _handleKeyboardShortcuts,
        child: Scaffold(
          appBar: _buildAppBar(),
          body: _buildBody(),
        ),
      ),
    );
  }

  Future<bool> _handleWillPop() async {
    if (!_isSaved) {
      final shouldSave = await CustomDialog.showConfirmationDialog(
        context: context,
        title: AppStrings.unsavedChanges,
        content: AppStrings.saveBeforeLeaving,
      );
      if (shouldSave == true) await _saveToFirebase();
    }
    return true;
  }

  void _handleKeyboardShortcuts(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyZ &&
        (event.isControlPressed || event.isMetaPressed)) {
      _undo();
    }
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text(widget.storage == null
          ? AppStrings.addStorage
          : AppStrings.editStorage),
      actions: [
        _buildActionButton(Icons.remove_red_eye, AppStrings.viewUpdates, _showUpdateLogs),
        _buildActionButton(Icons.link, AppStrings.manageRelationships, _showRelationshipsManager),
        _buildActionButton(Icons.edit, AppStrings.editColumns, _showEditColumnsDialog),
        _buildActionButton(Icons.add, AppStrings.addRow, _showAddRowDialog),
        _buildActionButton(Icons.view_column, AppStrings.addColumn, _addColumn),
        _buildActionButton(Icons.save, AppStrings.save, _saveToFirebase),
        _buildRowActionsMenu(),
        _buildColumnActionsMenu(),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, String tooltip, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }

  Widget _buildRowActionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'delete_rows': _deleteSelectedRows(); break;
          case 'duplicate_rows': _duplicateSelectedRows(); break;
          case 'copy_rows': _copySelectedRows(); break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'delete_rows',
          child: Text(AppStrings.deleteSelectedRows),
        ),
        const PopupMenuItem(
          value: 'duplicate_rows',
          child: Text(AppStrings.duplicateSelectedRows),
        ),
        const PopupMenuItem(
          value: 'copy_rows',
          child: Text(AppStrings.copySelectedRows),
        ),
      ],
    );
  }

  Widget _buildColumnActionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz),
      onSelected: (value) {
        switch (value) {
          case 'delete_columns': _columnAction("delete"); break;
          case 'duplicate_columns': _columnAction("duplicate"); break;
          case 'copy_columns': _columnAction("copy"); break;
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'delete_columns',
          child: Text(AppStrings.deleteSelectedColumns),
        ),
        const PopupMenuItem(
          value: 'duplicate_columns',
          child: Text(AppStrings.duplicateSelectedColumns),
        ),
        const PopupMenuItem(
          value: 'copy_columns',
          child: Text(AppStrings.copySelectedColumns),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSelectAllCheckbox(),
        _buildSearchField(),
        Expanded(child: _buildPlutoGrid()),
      ],
    );
  }

  Widget _buildSelectAllCheckbox() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Checkbox(
            value: rows.isNotEmpty &&
                rows.every((row) => _rowSelection[row.data['id']] ?? false),
            onChanged: (value) => _toggleSelectAll(value ?? false),
          ),
          const Text(AppStrings.selectAll),
        ],
      ),
    );
  }

  void _toggleSelectAll(bool value) {
    setState(() {
      for (var row in rows) {
        _rowSelection[row.data['id']] = value;
      }
    });
    _updateGrid();
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: _searchController,
        decoration: const InputDecoration(
          labelText: AppStrings.search,
          prefixIcon: Icon(Icons.search),
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => setState(() => searchQuery = value),
      ),
    );
  }

  Widget _buildPlutoGrid() {
    return PlutoGrid(
      key: ValueKey(_gridRefreshKey),
      columns: _buildPlutoColumns(),
      rows: _buildPlutoRows(),
      onLoaded: (PlutoGridOnLoadedEvent event) => stateManager = event.stateManager,
      onChanged: _handleCellChange,
      configuration: _gridConfig(),
    );
  }

  List<PlutoColumn> _buildPlutoColumns() {
    return [
      _buildSelectColumn(),
      _buildIdColumn(),
      ...columns.map(_buildDataColumn).toList(),
    ];
  }

  PlutoColumn _buildSelectColumn() => PlutoColumn(
    title: '',
    field: 'select',
    type: PlutoColumnType.text(),
    enableSorting: false,
    renderer: (context) => _buildRowCheckbox(context.row.cells['id']?.value),
  );

  Widget _buildRowCheckbox(String? rowId) {
    return Checkbox(
      value: _rowSelection[rowId] ?? false,
      onChanged: (value) => _updateRowSelection(rowId, value),
    );
  }

  void _updateRowSelection(String? rowId, bool? value) {
    setState(() => _rowSelection[rowId!] = value ?? false);
    _updateGrid();
  }

  void _updateGrid() {
    setState(() {
      _gridRefreshKey++;
      _isSaved = false;
    });
  }
  Map<String, dynamic> _prepareTableData() => {
    'columns': columns.map((col) => col.toMap()).toList(),
    'rows': rows.map((row) => row.toMap()).toList(),
    'relationships': columnRelationships.map((r) => r.toMap()).toList(),
    'timestamp': FieldValue.serverTimestamp(),
  };

  void _handleSaveSuccess(Map<String, dynamic> tableData) {
    setState(() {
      _isSaved = true;
      _updateLogs.add('Saved at ${DateTime.now().toLocal()}\nDetails: ${jsonEncode(tableData)}');
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.saveSuccess)),
    );
  }

  // Firestore operations
  Future<void> _saveToFirebase() async {
    try {
      final repository = context.read<StorageRepository>();
      final tableData = _prepareTableData();

      widget.docId == null
          ? await repository.addStorage(tableData)
          : await repository.updateStorage(widget.docId!, tableData);

      _handleSaveSuccess(tableData);
    } catch (e) {
      _handleSaveError(e);
    }
  }
  void _handleSaveError(dynamic error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.saveError(error.toString()))),
    );
  }

  PlutoColumn _buildIdColumn() => PlutoColumn(
    title: 'ID',
    field: 'id',
    type: PlutoColumnType.text(),
    readOnly: true,
    hide: true,
  );

  PlutoColumn _buildDataColumn(TableColumn col) => PlutoColumn(
    title: col.name,
    field: col.name,
    type: col.type == DataType.number ? PlutoColumnType.number() : PlutoColumnType.text(),
  );

  List<PlutoRow> _buildPlutoRows() {
    return filteredRows.map((row) => PlutoRow(
      cells: {
        'select': PlutoCell(value: false),
        'id': PlutoCell(value: row.data['id']),
        for (var col in columns)
          col.name: PlutoCell(value: row.data[col.name]),
      },
    )).toList();
  }

  List<TableRowData> get filteredRows {
    if (searchQuery.isEmpty) return rows;
    return rows.where((row) => row.data.values.any((value) =>
    value != null && value.toString().toLowerCase().contains(searchQuery.toLowerCase()),
    )).toList();
  }

  PlutoGridConfiguration _gridConfig() {
    return PlutoGridConfiguration(
      columnSize: PlutoGridColumnSizeConfig(autoSizeMode: PlutoAutoSizeMode.scale),
      style: PlutoGridStyleConfig(
        rowColor: Colors.red.withOpacity(0.2),
      ),
    );
  }

  /* Data Manipulation Methods */
  void _handleCellChange(PlutoGridOnChangedEvent event) {
    final columnName = event.column.field;
    final newValue = event.value;
    final rowId = event.row.cells['id']?.value;
    final rowIndex = rows.indexWhere((row) => row.data['id'] == rowId);

    if (rowIndex == -1) return;

    _pushUndoState();
    _updateRowData(rowIndex, columnName, newValue);
    _processDependencies(rowIndex, columnName, newValue);
    _checkLowStock(rowIndex);
    _updateGrid();
  }

  void _updateRowData(int rowIndex, String columnName, dynamic newValue) {
    setState(() => rows[rowIndex].data[columnName] = newValue);
  }

  void _processDependencies(int rowIndex, String columnName, dynamic newValue) {
    for (var dependency in columnDependencies) {
      if (dependency.sourceColumn == columnName) {
        final sourceValue = (newValue ?? 0).toDouble();
        final targetValue = (rows[rowIndex].data[dependency.targetColumn] ?? 0).toDouble();

        setState(() {
          rows[rowIndex].data[dependency.targetColumn] =
          dependency.operation == 'subtract'
              ? targetValue - sourceValue
              : targetValue + sourceValue;
        });
      }
    }
  }

  void _checkLowStock(int rowIndex) {
    final row = rows[rowIndex];
    for (var condition in thresholdConditions) {
      if (row.data.containsKey(condition.monitoredColumn)) {
        final value = (row.data[condition.monitoredColumn] ?? 0).toDouble();
        setState(() {
          row.data[condition.targetBooleanColumn] =
          value < condition.threshold ? 'True' : 'False';
        });
      }
    }
  }

  /* Column Management */
  void _showEditColumnsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editColumns),
        content: SingleChildScrollView(
          child: Column(
            children: columns.asMap().entries.map((entry) =>
                ListTile(
                  title: Text(entry.value.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      Navigator.pop(context);
                      _editColumn(entry.key);
                    },
                  ),
                ),
            ).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
  }

  void _editColumn(int index) {
    final controller = TextEditingController(text: columns[index].name);
    var newType = columns[index].type;

    _pushUndoState();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editColumn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: AppStrings.columnName),
            ),
            const SizedBox(height: 10),
            DropdownButton<DataType>(
              value: newType,
              onChanged: (value) => setState(() => newType = value ?? newType),
              items: DataType.values.map((dt) => DropdownMenuItem(
                value: dt,
                child: Text(dt.toString().split('.').last),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => _saveColumnEdit(index, controller.text.trim(), newType),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  void _saveColumnEdit(int index, String newName, DataType newType) {
    final oldName = columns[index].name;

    setState(() {
      columns[index] = columns[index].copyWith(name: newName, type: newType);

      if (oldName != newName) {
        for (var row in rows) {
          final value = row.data[oldName];
          row.data.remove(oldName);
          row.data[newName] = value;
        }
      }
    });

    Navigator.pop(context);
    _updateGrid();
  }

  void _addColumn() {
    _pushUndoState();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addColumn),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newColumnNameController,
              decoration: const InputDecoration(labelText: AppStrings.columnName),
            ),
            DropdownButton<DataType>(
              value: _newColumnType,
              onChanged: (value) => setState(() => _newColumnType = value ?? _newColumnType),
              items: DataType.values.map((dt) => DropdownMenuItem(
                value: dt,
                child: Text(dt.toString().split('.').last),
              )).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newColumnNameController.clear();
              Navigator.pop(context);
            },
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: _saveNewColumn,
            child: const Text(AppStrings.add),
          ),
        ],
      ),
    );
  }

  void _saveNewColumn() {
    final newColName = _newColumnNameController.text.trim();
    if (newColName.isEmpty) return;

    setState(() {
      columns.add(TableColumn(name: newColName, type: _newColumnType));
      for (var row in rows) {
        row.data[newColName] = null;
      }
    });

    _newColumnNameController.clear();
    Navigator.pop(context);
    _updateGrid();
  }

  void _columnAction(String action) {
    final availableColumns = columns
        .map((col) => col.name)
        .where((name) => name != 'id')
        .toList();
    final selected = <String>[];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppStrings.selectColumnsFor} $action'),
        content: StatefulBuilder(
          builder: (context, setState) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: availableColumns.map((colName) => CheckboxListTile(
                title: Text(colName),
                value: selected.contains(colName),
                onChanged: (value) => setState(() {
                  if (value == true) {
                    selected.add(colName);
                  } else {
                    selected.remove(colName);
                  }
                }),
              )).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              switch (action) {
                case "delete": _deleteColumns(selected); break;
                case "duplicate": _duplicateColumns(selected); break;
                case "copy": _copyColumns(selected); break;
              }
            },
            child: Text(AppStrings.ok),
          ),
        ],
      ),
    );
  }

  void _deleteColumns(List<String> selectedColumns) {
    _pushUndoState();
    setState(() {
      columns.removeWhere((col) => selectedColumns.contains(col.name));
      for (var row in rows) {
        for (var colName in selectedColumns) {
          row.data.remove(colName);
        }
      }
    });
    _updateGrid();
  }

  void _duplicateColumns(List<String> selectedColumns) {
    _pushUndoState();
    setState(() {
      for (var colName in selectedColumns) {
        final newColName = '$colName (copy)';
        final orig = columns.firstWhere(
              (col) => col.name == colName,
          orElse: () => TableColumn(name: colName, type: DataType.text),
        );

        columns.add(TableColumn(name: newColName, type: orig.type));
        for (var row in rows) {
          row.data[newColName] = row.data[colName];
        }
      }
    });
    _updateGrid();
  }

  void _copyColumns(List<String> selectedColumns) {
    final copiedColumns = selectedColumns.map((colName) {
      final col = columns.firstWhere(
            (c) => c.name == colName,
        orElse: () => TableColumn(name: colName, type: DataType.text),
      );
      return col.toMap();
    }).toList();

    Clipboard.setData(ClipboardData(text: jsonEncode(copiedColumns)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.columnsCopied)),
    );
  }

  /* Row Management */
  void _showAddRowDialog() {
    final controllers = <String, TextEditingController>{};
    for (var col in columns) {
      if (col.name == 'id') continue;
      controllers[col.name] = TextEditingController();
    }

    _pushUndoState();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.addNewRow),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: controllers.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: entry.value,
                decoration: InputDecoration(labelText: entry.key),
                keyboardType: _getKeyboardTypeForColumn(entry.key),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => _saveNewRow(controllers),
            child: const Text(AppStrings.addRow),
          ),
        ],
      ),
    );
  }

  TextInputType _getKeyboardTypeForColumn(String columnName) {
    final column = columns.firstWhere(
          (c) => c.name == columnName,
      orElse: () => TableColumn(name: columnName, type: DataType.text),
    );
    return column.type == DataType.number
        ? TextInputType.number
        : TextInputType.text;
  }

  void _saveNewRow(Map<String, TextEditingController> controllers) {
    final newRowData = <String, dynamic>{
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    controllers.forEach((colName, controller) {
      final column = columns.firstWhere(
            (c) => c.name == colName,
        orElse: () => TableColumn(name: colName, type: DataType.text),
      );

      newRowData[colName] = column.type == DataType.number
          ? num.tryParse(controller.text) ?? 0
          : controller.text;
    });

    setState(() {
      rows.add(TableRowData(data: newRowData));
      _rowSelection[newRowData['id']] = false;
    });

    Navigator.pop(context);
    _updateGrid();
  }

  void _deleteSelectedRows() {
    final selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noRowsSelected)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDeleteRows),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performRowDeletion(selectedIds);
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _performRowDeletion(List<String> selectedIds) {
    _pushUndoState();
    setState(() {
      rows.removeWhere((row) => selectedIds.contains(row.data['id']));
      for (var id in selectedIds) {
        _rowSelection.remove(id);
      }
    });
    _updateGrid();
  }

  void _duplicateSelectedRows() {
    final selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noRowsSelected)),
      );
      return;
    }

    _pushUndoState();
    setState(() {
      for (var id in selectedIds) {
        final original = rows.firstWhere(
              (row) => row.data['id'] == id,
          orElse: () => TableRowData(data: {}),
        );

        if (original.data.isNotEmpty) {
          final newData = Map<String, dynamic>.from(original.data);
          newData['id'] = DateTime.now().millisecondsSinceEpoch.toString();
          rows.add(TableRowData(data: newData));
        }
      }
    });
    _updateGrid();
  }

  void _copySelectedRows() {
    final selectedIds = _rowSelection.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selectedIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.noRowsSelected)),
      );
      return;
    }

    final copiedData = rows
        .where((row) => selectedIds.contains(row.data['id']))
        .map((row) => row.data)
        .toList();

    Clipboard.setData(ClipboardData(text: jsonEncode(copiedData)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.rowsCopied)),
    );
  }

  void _editCell(TableRowData row, String columnName, DataType type) {
    final controller = TextEditingController(
      text: row.data[columnName]?.toString() ?? '',
    );

    _pushUndoState();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${AppStrings.edit} $columnName'),
        content: TextField(
          controller: controller,
          keyboardType: type == DataType.number
              ? TextInputType.number
              : TextInputType.text,
          decoration: const InputDecoration(hintText: AppStrings.enterNewValue),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () => _saveCellEdit(row, columnName, type, controller.text),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
  }

  void _saveCellEdit(TableRowData row, String columnName, DataType type, String value) {
    setState(() {
      row.data[columnName] = type == DataType.number
          ? num.tryParse(value) ?? 0
          : value;
    });

    final rowIndex = rows.indexWhere((r) => r.data['id'] == row.data['id']);
    if (rowIndex != -1) {
      _updateDependentColumn(columnName, rowIndex);
    }

    Navigator.pop(context);
    _updateGrid();
  }

  void _updateDependentColumn(String changedColumn, int rowIndex) {
    final row = rows[rowIndex];

    for (var dependency in columnDependencies) {
      if (dependency.sourceColumn == changedColumn) {
        final sourceValue = (row.data[dependency.sourceColumn] ?? 0).toDouble();
        final targetValue = (row.data[dependency.targetColumn] ?? 0).toDouble();

        setState(() {
          row.data[dependency.targetColumn] = dependency.operation == 'subtract'
              ? targetValue - sourceValue
              : targetValue + sourceValue;
        });
      }
    }

    _checkLowStock(rowIndex);
    _updateGrid();
  }

  /* Relationship Management */
  void _showRelationshipsManager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.manageRelationships),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: columnRelationships.length,
            itemBuilder: (context, index) => ListTile(
              title: Text(
                '${columnRelationships[index].sourceColumn} → '
                    '${columnRelationships[index].targetColumn}',
              ),
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
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.close),
          ),
          ElevatedButton(
            onPressed: _showCreateRelationshipDialog,
            child: const Text(AppStrings.addNew),
          ),
        ],
      ),
    );
  }

  void _showCreateRelationshipDialog([int? editIndex]) {
    CustomDialog.showRelationshipDialog(
      context: context,
      numericColumns: columns
          .where((c) => c.type == DataType.number)
          .map((c) => c.name)
          .toList(),
      existingRelationship: editIndex != null ? columnRelationships[editIndex] : null,
      existingRelationships: columnRelationships,
    ).then((relationship) {
      if (relationship != null) {
        setState(() {
          if (editIndex != null) {
            columnRelationships[editIndex] = relationship;
          } else {
            columnRelationships.add(relationship);
          }
        });
        _updateGrid();
      }
    });
  }

  void _deleteRelationship(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: const Text(AppStrings.confirmDeleteRelationship),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => columnRelationships.removeAt(index));
              Navigator.pop(context);
              _updateGrid();
            },
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _showEditRelationshipDialog(int index) {
    _editingRelationshipId = columnRelationships[index].sourceColumn;
    _showCreateRelationshipDialog(index);
  }

  /* Undo/Redo Functionality */
  void _pushUndoState() {
    _undoStack.add({
      "columns": jsonEncode(columns.map((c) => c.toMap()).toList()),
      "rows": jsonEncode(rows.map((r) => r.toMap()).toList()),
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;

    final state = _undoStack.removeLast();
    final colsJson = jsonDecode(state["columns"]) as List;
    final rowsJson = jsonDecode(state["rows"]) as List;

    setState(() {
      columns = colsJson.map((e) => TableColumn.fromMap(e)).toList();
      rows = rowsJson.map((e) => TableRowData.fromMap(e)).toList();
      _rowSelection.clear();
      for (var row in rows) {
        _rowSelection[row.data['id']] = false;
      }
    });
    _updateGrid();
  }

  /* Logging and Miscellaneous */
  void _showUpdateLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.updateLogs),
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
            child: const Text(AppStrings.close),
          ),
        ],
      ),
    );
  }
}