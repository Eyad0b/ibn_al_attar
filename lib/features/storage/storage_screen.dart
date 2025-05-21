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
  // ======== STATE VARIABLES ========
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
  final List<Map<String, dynamic>> _redoStack = [];
  final FocusNode _focusNode = FocusNode();
  bool _isSaved = true;
  final List<String> _updateLogs = [];
  List<ColumnRelationship> columnRelationships = [];
  final GlobalKey<FormState> _relationshipFormKey = GlobalKey<FormState>();
  String? _editingRelationshipId;
  final Map<String, dynamic> _previousValues = {};
  bool _isFullScreen = false;
  bool _isSorting = false;
  String? _sortColumn;
  bool _sortAscending = true;
  
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
  
  // Maximum number of undo states to keep in memory
  static const int _maxUndoStates = 20;

  // ======== LIFECYCLE METHODS ========
  @override
  void initState() {
    super.initState();
    _initializeStorageData();
    _ensureRowIds();
    _initializeRowSelection();
    
    // Register for keyboard events
    SystemChannels.keyEvent.setMessageHandler((message) async {
      final keyMessage = KeyEventMessage.fromJson(message as Map<String, dynamic>);
      if (keyMessage.type == 'keydown') {
        if (keyMessage.isCtrlPressed && keyMessage.keyCode == 90) { // Ctrl+Z (Undo)
          _undo();
          return '';
        } else if (keyMessage.isCtrlPressed && keyMessage.keyCode == 89) { // Ctrl+Y (Redo)
          _redo();
          return '';
        }
      }
      return message as String;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _newColumnNameController.dispose();
    _focusNode.dispose();
    SystemChannels.keyEvent.setMessageHandler(null);
    super.dispose();
  }

  // ======== INITIALIZATION METHODS ========
  void _initializeStorageData() {
    if (widget.storage != null) {
      try {
        columns = (widget.storage!['columns'] as List)
            .map((e) => TableColumn.fromMap(Map<String, dynamic>.from(e)))
            .toList();
            
        rows = (widget.storage!['rows'] as List)
            .map((e) => TableRowData.fromMap(Map<String, dynamic>.from(e)))
            .toList();
            
        // Load relationships if they exist
        if (widget.storage!.containsKey('relationships')) {
          columnRelationships = (widget.storage!['relationships'] as List)
              .map((e) => ColumnRelationship.fromMap(Map<String, dynamic>.from(e)))
              .toList();
        }
      } catch (e) {
        debugPrint('Error initializing storage data: $e');
        // Fallback to defaults
        columns = defaultColumns;
        rows = [];
        columnRelationships = [];
      }
    } else {
      columns = defaultColumns;
      rows = [];
      columnRelationships = [];
    }
    
    // Initialize update logs 
    if (widget.storage != null && widget.storage!.containsKey('updateLogs')) {
      _updateLogs.addAll(List<String>.from(widget.storage!['updateLogs']));
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
  
  // ======== UI BUILDING METHODS ========
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
      if (shouldSave == true && mounted) {
        await _saveToFirebase();
      }
    }
    return true;
  }

  void _handleKeyboardShortcuts(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.keyZ && 
         (event.isControlPressed || event.isMetaPressed)) {
        _undo();
      } else if (event.logicalKey == LogicalKeyboardKey.keyY && 
                (event.isControlPressed || event.isMetaPressed)) {
        _redo();
      } else if (event.logicalKey == LogicalKeyboardKey.keyS && 
                (event.isControlPressed || event.isMetaPressed)) {
        _saveToFirebase();
      } else if (event.logicalKey == LogicalKeyboardKey.keyF && 
                (event.isControlPressed || event.isMetaPressed)) {
        FocusScope.of(context).requestFocus(
          _searchController.focusNode ?? FocusNode()
        );
      }
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
        _buildActionButton(Icons.undo, 'Undo (Ctrl+Z)', _undo),
        _buildActionButton(Icons.redo, 'Redo (Ctrl+Y)', _redo),
        _buildActionButton(
          _isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, 
          _isFullScreen ? 'Exit Fullscreen' : 'Fullscreen', 
          _toggleFullScreen),
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

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
    
    if (_isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  Widget _buildRowActionsMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      onSelected: (value) {
        switch (value) {
          case 'delete_rows': _deleteSelectedRows(); break;
          case 'duplicate_rows': _duplicateSelectedRows(); break;
          case 'copy_rows': _copySelectedRows(); break;
          case 'export_csv': _exportToCsv(); break;
          case 'import_csv': _importFromCsv(); break;
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
        const PopupMenuItem(
          value: 'export_csv',
          child: Text('Export to CSV'),
        ),
        const PopupMenuItem(
          value: 'import_csv',
          child: Text('Import from CSV'),
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
          case 'sort_columns': _showSortDialog(); break;
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
        const PopupMenuItem(
          value: 'sort_columns',
          child: Text('Sort Columns'),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildSelectAllCheckbox(),
        _buildSearchField(),
        if (_isSorting) _buildSortIndicator(),
        Expanded(child: _buildPlutoGrid()),
      ],
    );
  }

  Widget _buildSortIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppColors.backgroundLight,
      child: Row(
        children: [
          Text('Sorting by: $_sortColumn'),
          Icon(_sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          const Spacer(),
          TextButton(
            onPressed: _clearSorting,
            child: const Text('Clear Sorting'),
          ),
        ],
      ),
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
        decoration: InputDecoration(
          labelText: AppStrings.search,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => searchQuery = '');
                  },
                )
              : null,
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
    if (mounted) {
      setState(() => _rowSelection[rowId!] = value ?? false);
      _updateGrid();
    }
  }

  void _updateGrid() {
    if (mounted) {
      setState(() {
        _gridRefreshKey++;
        _isSaved = false;
      });
    }
  }
  
  // ======== FIRESTORE OPERATIONS ========
  Map<String, dynamic> _prepareTableData() => {
    'columns': columns.map((col) => col.toMap()).toList(),
    'rows': rows.map((row) => row.toMap()).toList(),
    'relationships': columnRelationships.map((r) => r.toMap()).toList(),
    'updateLogs': _updateLogs,
    'timestamp': FieldValue.serverTimestamp(),
  };

  void _handleSaveSuccess(Map<String, dynamic> tableData) {
    if (mounted) {
      setState(() {
        _isSaved = true;
        _logUpdate('Saved data', 'success');
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.saveSuccess)),
      );
    }
  }

  Future<void> _saveToFirebase() async {
    if (!mounted) return;
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saving data...'), duration: Duration(milliseconds: 500)),
    );
    
    try {
      final repository = context.read<StorageRepository>();
      final tableData = _prepareTableData();

      if (widget.docId == null) {
        await repository.addStorage(tableData);
      } else {
        await repository.updateStorage(widget.docId!, tableData);
      }

      _handleSaveSuccess(tableData);
    } catch (e) {
      _handleSaveError(e);
    }
  }
  
  void _handleSaveError(dynamic error) {
    if (mounted) {
      _logUpdate('Save error: $error', 'error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.saveError(error.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
    type: col.type == DataType.number 
        ? PlutoColumnType.number() 
        : PlutoColumnType.text(),
    readOnly: isColumnReadOnly(col),
    enableSorting: true,
    enableColumnDrag: true,
    enableRowDrag: true,
    enableContextMenu: true,
    renderer: (context) {
      final cell = context.cell;
      final row = context.row;
      final rowIndex = rows.indexWhere((r) => r.data['id'] == row.cells['id']?.value);
      
      // Apply special formatting for low stock status
      if (col.name == AppStrings.lowStockStatus && cell.value == 'True') {
        return Container(
          color: AppColors.error.withOpacity(0.3),
          alignment: Alignment.center,
          child: Text(
            cell.value.toString(),
            style: const TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      
      return PlutoDefaultCellRenderer(cell: cell, text: cell.value.toString());
    },
  );

  bool isColumnReadOnly(TableColumn col) {
    // Make calculated columns read-only
    for (var dependency in columnDependencies) {
      if (col.name == dependency.targetColumn) return true;
    }
    
    // Make status columns read-only
    for (var condition in thresholdConditions) {
      if (col.name == condition.targetBooleanColumn) return true;
    }
    
    return false;
  }

  List<PlutoRow> _buildPlutoRows() {
    final displayRows = _getSortedAndFilteredRows();
    
    return displayRows.map((row) => PlutoRow(
      cells: {
        'select': PlutoCell(value: false),
        'id': PlutoCell(value: row.data['id']),
        for (var col in columns)
          col.name: PlutoCell(value: row.data[col.name]),
      },
    )).toList();
  }

  List<TableRowData> _getSortedAndFilteredRows() {
    List<TableRowData> filteredData = searchQuery.isEmpty 
        ? rows 
        : rows.where((row) => row.data.values.any((value) =>
            value != null && value.toString().toLowerCase().contains(searchQuery.toLowerCase()),
          )).toList();
    
    // Apply sorting if set
    if (_sortColumn != null) {
      filteredData.sort((a, b) {
        var aValue = a.data[_sortColumn];
        var bValue = b.data[_sortColumn];
        
        // Handle null values
        if (aValue == null && bValue == null) return 0;
        if (aValue == null) return _sortAscending ? -1 : 1;
        if (bValue == null) return _sortAscending ? 1 : -1;
        
        // Compare based on type
        int comparison;
        if (aValue is num && bValue is num) {
          comparison = aValue.compareTo(bValue);
        } else {
          comparison = aValue.toString().compareTo(bValue.toString());
        }
        
        return _sortAscending ? comparison : -comparison;
      });
    }
    
    return filteredData;
  }

  void _clearSorting() {
    setState(() {
      _isSorting = false;
      _sortColumn = null;
      _updateGrid();
    });
  }

  PlutoGridConfiguration _gridConfig() {
    return PlutoGridConfiguration(
      columnSize: PlutoGridColumnSizeConfig(autoSizeMode: PlutoAutoSizeMode.scale),
      style: PlutoGridStyleConfig(
        rowColor: (_) => AppColors.background,
        oddRowColor: (_) => AppColors.background.withOpacity(0.9),
        activatedColor: AppColors.primaryLight.withOpacity(0.2),
        gridBorderColor: AppColors.divider,
        borderColor: AppColors.divider,
        activatedBorderColor: AppColors.primary,
        inactivatedBorderColor: AppColors.divider,
        gridBackgroundColor: AppColors.background,
      ),
      enableColumnBorder: true,
      enableRowColorAnimation: true,
    );
  }

  // ======== DATA MANIPULATION METHODS ========
  void _handleCellChange(PlutoGridOnChangedEvent event) {
    final columnName = event.column.field;
    final newValue = event.value;
    final rowId = event.row.cells['id']?.value;
    final rowIndex = rows.indexWhere((row) => row.data['id'] == rowId);

    if (rowIndex == -1) return;

    // Store previous state for undo
    _pushUndoState();
    
    // Store the previous value before updating
    _previousValues['${rowId}_$columnName'] = rows[rowIndex].data[columnName];
    
    // Update the cell value
    _updateRowData(rowIndex, columnName, newValue);
    
    // Process column dependencies
    _processDependencies(rowIndex, columnName, newValue);
    
    // Check for low stock
    _checkLowStock(rowIndex);
    
    // Process column relationships
    _processRelationships(rowIndex, columnName, newValue);
    
    // Log the update
    _logUpdate('Changed $columnName for row ${rowIndex + 1} from ${_previousValues['${rowId}_$columnName']} to $newValue', 'data');
    
    // Refresh the grid
    _updateGrid();
  }

  void _updateRowData(int rowIndex, String columnName, dynamic newValue) {
    if (mounted) {
      setState(() => rows[rowIndex].data[columnName] = newValue);
    }
  }

  void _processDependencies(int rowIndex, String columnName, dynamic newValue) {
    for (var dependency in columnDependencies) {
      if (dependency.sourceColumn == columnName) {
        final sourceValue = (newValue ?? 0).toDouble();
        final targetValue = (rows[rowIndex].data[dependency.targetColumn] ?? 0).toDouble();

        if (mounted) {
          setState(() {
            rows[rowIndex].data[dependency.targetColumn] =
                dependency.operation == 'subtract'
                    ? targetValue - sourceValue
                    : targetValue + sourceValue;
          });
        }
      }
    }
  }

  void _checkLowStock(int rowIndex) {
    final row = rows[rowIndex];
    for (var condition in thresholdConditions) {
      if (row.data.containsKey(condition.monitoredColumn)) {
        final value = (row.data[condition.monitoredColumn] ?? 0).toDouble();
        if (mounted) {
          setState(() {
            row.data[condition.targetBooleanColumn] =
                value < condition.threshold ? 'True' : 'False';
          });
        }
      }
    }
  }
  
  void _processRelationships(int rowIndex, String columnName, dynamic newValue) {
    for (var relationship in columnRelationships) {
      // If this column is a source in a relationship
      if (relationship.sourceColumn == columnName) {
        // Find all rows with the same values
        final sourceValue = newValue;
        
        for (int i = 0; i < rows.length; i++) {
          if (i != rowIndex) {
            // Check if this other row should be updated based on the relationship
            if (rows[i].data[columnName] == sourceValue) {
              // Get target value from changed row
              final targetValue = rows[rowIndex].data[relationship.targetColumn];
              
              // Update the target column in this related row
              if (mounted) {
                setState(() {
                  rows[i].data[relationship.targetColumn] = targetValue;
                });
              }
            }
          }
        }
      }
    }
  }

  void _logUpdate(String message, String type) {
    final timestamp = DateTime.now().toLocal().toString();
    final logEntry = '[$timestamp] [$type] $message';
    
    if (mounted) {
      setState(() {
        _updateLogs.add(logEntry);
        // Limit log size
        if (_updateLogs.length > 100) {
          _updateLogs.removeAt(0);
        }
      });
    }
  }

  // ======== COLUMN MANAGEMENT ========
  void _showEditColumnsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.editColumns),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: columns.length,
            itemBuilder: (context, index) => ListTile(
              leading: Icon(
                columns[index].type == DataType.number 
                    ? Icons.numbers 
                    : Icons.text_fields,
                color: AppColors.primary,
              ),
              title: Text(columns[index].name),
              subtitle: Text('Type: ${columns[index].type.toString().split('.').last}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit),
                    tooltip: 'Edit Column',
                    onPressed: () {
                      Navigator.pop(context);
                      _editColumn(index);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: 'Delete Column',
                    onPressed: () {
                      Navigator.pop(context);
                      _confirmDeleteColumn(index);
                    },
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
        ],
      ),
    );
  }

  void _confirmDeleteColumn(int index) {
    final columnName = columns[index].name;
    
    // Check if this column is used in relationships or dependencies
    bool isUsedInRelationships = columnRelationships.any(
      (rel) => rel.sourceColumn == columnName || rel.targetColumn == columnName
    );
    
    bool isUsedInDependencies = columnDependencies.any(
      (dep) => dep.sourceColumn == columnName || dep.targetColumn == columnName
    );
    
    bool isUsedInThresholds = thresholdConditions.any(
      (threshold) => threshold.monitoredColumn == columnName || 
                     threshold.targetBooleanColumn == columnName
    );
    
    if (isUsedInRelationships || isUsedInDependencies || isUsedInThresholds) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Column'),
          content: Text(
            'The column "$columnName" cannot be deleted because it is used in '
            '${isUsedInRelationships ? 'relationships' : ''}'
            '${isUsedInDependencies ? (isUsedInRelationships ? ', ' : '') + 'dependencies' : ''}'
            '${isUsedInThresholds ? ((isUsedInRelationships || isUsedInDependencies) ? ', ' : '') + 'thresholds' : ''}'
            '. Please remove these dependencies first.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text('Are you sure you want to delete the column "$columnName"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteColumn(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text(AppStrings.delete),
          ),
        ],
      ),
    );
  }

  void _deleteColumn(int index) {
    _pushUndoState();
    
    final columnName = columns[index].name;
    
    setState(() {
      columns.removeAt(index);
      
      // Remove column data from all rows
      for (var row in rows) {
        row.data.remove(columnName);
      }
      
      _logUpdate('Deleted column: $columnName', 'structure');
    });
    
    _updateGrid();
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
              autofocus: true,
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
    final oldType = columns[index].type;
    
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Column name cannot be empty')),
      );
      return;
    }
    
    // Check if column name already exists
    if (newName != oldName && columns.any((col) => col.name == newName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A column with this name already exists')),
      );
      return;
    }

    setState(() {
      columns[index] = columns[index].copyWith(name: newName, type: newType);

      if (oldName != newName) {
        // Update column name in all rows
        for (var row in rows) {
          final value = row.data[oldName];
          row.data.remove(oldName);
          row.data[newName] = value;
        }
        
        // Update column references in relationships
        for (int i = 0; i < columnRelationships.length; i++) {
          if (columnRelationships[i].sourceColumn == oldName) {
            columnRelationships[i] = ColumnRelationship(
              sourceColumn: newName,
              targetColumn: columnRelationships[i].targetColumn,
            );
          }
          
          if (columnRelationships[i].targetColumn == oldName) {
            columnRelationships[i] = ColumnRelationship(
              sourceColumn: columnRelationships[i].sourceColumn,
              targetColumn: newName,
            );
          }
        }
      }
      
      // If type changed, convert values
      if (oldType != newType) {
        for (var row in rows) {
          if (row.data.containsKey(newName)) {
            if (newType == DataType.number && row.data[newName] is String) {
              // Convert to number
              row.data[newName] = num.tryParse(row.data[newName] ?? '') ?? 0;
            } else if (newType == DataType.text && row.data[newName] is num) {
              // Convert to text
              row.data[newName] = row.data[newName].toString();
            }
          }
        }
      }
      
      _logUpdate(
        'Edited column: ${oldName != newName ? "$oldName → $newName" : newName}, ' 
        'Type: ${oldType != newType ? "${oldType.toString().split('.').last} → ${newType.toString().split('.').last}" : newType.toString().split('.').last}', 
        'structure'
      );
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
              autofocus: true,
            ),
            const SizedBox(height: 10),
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
    if (newColName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Column name cannot be empty')),
      );
      return;
    }
    
    // Check if column name already exists
    if (columns.any((col) => col.name == newColName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A column with this name already exists')),
      );
      return;
    }

    setState(() {
      columns.add(TableColumn(name: newColName, type: _newColumnType));
      
      // Initialize column in all rows
      for (var row in rows) {
        row.data[newColName] = _newColumnType == DataType.number ? 0 : '';
      }
      
      _logUpdate('Added new column: $newColName (${_newColumnType.toString().split('.').last})', 'structure');
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
          builder: (context, setState) => SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView(
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
              if (selected.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No columns selected')),
                );
                return;
              }
              
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
    // Check if any selected columns are used in relationships, dependencies, or thresholds
    final usedColumns = <String>[];
    
    for (var colName in selectedColumns) {
      bool isUsed = false;
      
      // Check relationships
      if (columnRelationships.any(
        (rel) => rel.sourceColumn == colName || rel.targetColumn == colName
      )) {
        isUsed = true;
      }
      
      // Check dependencies
      if (columnDependencies.any(
        (dep) => dep.sourceColumn == colName || dep.targetColumn == colName
      )) {
        isUsed = true;
      }
      
      // Check thresholds
      if (thresholdConditions.any(
        (threshold) => threshold.monitoredColumn == colName || 
                      threshold.targetBooleanColumn == colName
      )) {
        isUsed = true;
      }
      
      if (isUsed) {
        usedColumns.add(colName);
      }
    }
    
    if (usedColumns.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Delete Columns'),
          content: Text(
            'The following columns cannot be deleted because they are used in relationships, '
            'dependencies, or thresholds: ${usedColumns.join(', ')}. '
            'Please remove these dependencies first.'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    
    _pushUndoState();
    setState(() {
      columns.removeWhere((col) => selectedColumns.contains(col.name));
      for (var row in rows) {
        for (var colName in selectedColumns) {
          row.data.remove(colName);
        }
      }
      
      _logUpdate('Deleted columns: ${selectedColumns.join(', ')}', 'structure');
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
      
      _logUpdate('Duplicated columns: ${selectedColumns.join(', ')}', 'structure');
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
    
    _logUpdate('Copied columns to clipboard: ${selectedColumns.join(', ')}', 'action');
  }
  
  void _showSortDialog() {
    String? selectedColumn = _sortColumn;
    bool ascending = _sortAscending;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sort Data'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedColumn,
                decoration: const InputDecoration(
                  labelText: 'Sort by Column',
                  border: OutlineInputBorder(),
                ),
                items: columns
                    .map((col) => col.name)
                    .map((name) => DropdownMenuItem<String>(
                      value: name,
                      child: Text(name),
                    ))
                    .toList(),
                onChanged: (value) => setState(() => selectedColumn = value),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Ascending'),
                      value: true,
                      groupValue: ascending,
                      onChanged: (value) => setState(() => ascending = value ?? true),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<bool>(
                      title: const Text('Descending'),
                      value: false,
                      groupValue: ascending,
                      onChanged: (value) => setState(() => ascending = value ?? false),
                    ),
                  ),
                ],
              ),
            ],
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
              
              if (selectedColumn == null) {
                return;
              }
              
              setState(() {
                _sortColumn = selectedColumn;
                _sortAscending = ascending;
                _isSorting = true;
              });
              
              _updateGrid();
            },
            child: const Text('Apply Sort'),
          ),
        ],
      ),
    );
  }

  // ======== ROW MANAGEMENT ========
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
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView(
            children: controllers.entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: TextField(
                controller: entry.value,
                decoration: InputDecoration(
                  labelText: entry.key,
                  border: const OutlineInputBorder(),
                ),
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
      
      // Process thresholds for the new row
      final newRowIndex = rows.length - 1;
      _checkLowStock(newRowIndex);
      
      _logUpdate('Added new row with ID: ${newRowData['id']}', 'data');
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
        content: Text('Are you sure you want to delete ${selectedIds.length} selected rows?'),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
      
      _logUpdate('Deleted ${selectedIds.length} rows', 'data');
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
      final newRows = <TableRowData>[];
      
      for (var id in selectedIds) {
        final original = rows.firstWhere(
              (row) => row.data['id'] == id,
          orElse: () => TableRowData(data: {}),
        );

        if (original.data.isNotEmpty) {
          final newData = Map<String, dynamic>.from(original.data);
          newData['id'] = '${DateTime.now().millisecondsSinceEpoch}_${rows.length + newRows.length}';
          newRows.add(TableRowData(data: newData));
        }
      }
      
      rows.addAll(newRows);
      
      for (var row in newRows) {
        _rowSelection[row.data['id']] = false;
      }
      
      _logUpdate('Duplicated ${selectedIds.length} rows', 'data');
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
    
    _logUpdate('Copied ${selectedIds.length} rows to clipboard', 'action');
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
      final oldValue = row.data[columnName];
      
      row.data[columnName] = type == DataType.number
          ? num.tryParse(value) ?? 0
          : value;
          
      _logUpdate('Edited cell: $columnName, from $oldValue to ${row.data[columnName]}', 'data');
    });

    final rowIndex = rows.indexWhere((r) => r.data['id'] == row.data['id']);
    if (rowIndex != -1) {
      _updateDependentColumn(columnName, rowIndex);
      _processRelationships(rowIndex, columnName, row.data[columnName]);
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
  
  // ======== EXPORT/IMPORT FUNCTIONALITY ========
  void _exportToCsv() {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export')),
      );
      return;
    }
    
    // Create CSV header row
    final header = columns.map((col) => col.name).join(',');
    
    // Create CSV data rows
    final csvRows = rows.map((row) {
      return columns.map((col) {
        final value = row.data[col.name];
        
        // Handle null values
        if (value == null) return '';
        
        // Handle values with commas
        if (value.toString().contains(',')) {
          return '"${value.toString()}"';
        }
        
        return value.toString();
      }).join(',');
    }).join('\
');
    
    // Combine header and data
    final csv = '$header\
$csvRows';
    
    Clipboard.setData(ClipboardData(text: csv));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV data copied to clipboard')),
    );
    
    _logUpdate('Exported data to CSV', 'action');
  }
  
  void _importFromCsv() {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import from CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste your CSV data below. The first line should contain column headers that match your existing columns.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 10,
              decoration: const InputDecoration(
                hintText: 'Paste CSV data here...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processCsvImport(controller.text);
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
  
  void _processCsvImport(String csvData) {
    if (csvData.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No CSV data provided')),
      );
      return;
    }
    
    try {
      final lines = csvData.split('\
');
      if (lines.isEmpty) {
        throw 'Invalid CSV format';
      }
      
      // Parse header
      final headerLine = lines[0].trim();
      final headers = _parseCsvLine(headerLine);
      
      // Validate headers against existing columns
      final unknownColumns = headers.where(
        (header) => !columns.any((col) => col.name == header)
      ).toList();
      
      if (unknownColumns.isNotEmpty) {
        throw 'Unknown columns: ${unknownColumns.join(', ')}';
      }
      
      _pushUndoState();
      
      // Process data rows
      final newRows = <TableRowData>[];
      
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        
        final values = _parseCsvLine(line);
        
        if (values.length != headers.length) {
          throw 'Line ${i + 1} has ${values.length} values but expected ${headers.length}';
        }
        
        final rowData = <String, dynamic>{
          'id': '${DateTime.now().millisecondsSinceEpoch}_$i',
        };
        
        for (int j = 0; j < headers.length; j++) {
          final colName = headers[j];
          final value = values[j];
          
          // Get column type
          final columnType = columns
              .firstWhere((col) => col.name == colName)
              .type;
          
          // Convert value based on column type
          if (columnType == DataType.number) {
            rowData[colName] = num.tryParse(value) ?? 0;
          } else {
            rowData[colName] = value;
          }
        }
        
        // Add missing columns with default values
        for (var col in columns) {
          if (!rowData.containsKey(col.name)) {
            rowData[col.name] = col.type == DataType.number ? 0 : '';
          }
        }
        
        newRows.add(TableRowData(data: rowData));
      }
      
      setState(() {
        rows.addAll(newRows);
        
        // Initialize row selection for new rows
        for (var row in newRows) {
          _rowSelection[row.data['id']] = false;
        }
        
        // Process dependencies and thresholds for new rows
        for (int i = rows.length - newRows.length; i < rows.length; i++) {
          _checkLowStock(i);
        }
        
        _logUpdate('Imported ${newRows.length} rows from CSV', 'data');
      });
      
      _updateGrid();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported ${newRows.length} rows')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error importing CSV: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
  
  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    bool inQuotes = false;
    String currentValue = '';
    
    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        values.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }
    
    values.add(currentValue);
    return values;
  }
  
  // ======== RELATIONSHIP MANAGEMENT ========
  void _showRelationshipsManager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.manageRelationships),
        content: SizedBox(
          width: double.maxFinite,
          height: columnRelationships.isEmpty ? 100 : 300,
          child: columnRelationships.isEmpty
              ? const Center(
                  child: Text(
                    'No relationships defined yet. Click "Add New" to create one.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: columnRelationships.length,
                  itemBuilder: (context, index) => Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      title: Text(
                        '${columnRelationships[index].sourceColumn} → ${columnRelationships[index].targetColumn}',
                      ),
                      subtitle: const Text('When source values match, target values will sync'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            tooltip: 'Edit Relationship',
                            onPressed: () => _showEditRelationshipDialog(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            tooltip: 'Delete Relationship',
                            onPressed: () => _deleteRelationship(index),
                          ),
                        ],
                      ),
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
    _pushUndoState();
    
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
            _logUpdate('Updated relationship: ${relationship.sourceColumn} → ${relationship.targetColumn}', 'structure');
          } else {
            columnRelationships.add(relationship);
            _logUpdate('Added new relationship: ${relationship.sourceColumn} → ${relationship.targetColumn}', 'structure');
          }
        });
        
        // Apply relationship immediately to existing data
        _applyRelationshipToExistingData(relationship);
        
        _updateGrid();
      }
    });
  }
  
  void _applyRelationshipToExistingData(ColumnRelationship relationship) {
    // Group rows by source column value
    final groupedRows = <dynamic, List<int>>{};
    
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final sourceValue = row.data[relationship.sourceColumn];
      
      if (sourceValue != null) {
        if (!groupedRows.containsKey(sourceValue)) {
          groupedRows[sourceValue] = [];
        }
        groupedRows[sourceValue]!.add(i);
      }
    }
    
    // Update target column values for each group
    for (final entry in groupedRows.entries) {
      if (entry.value.length > 1) {
        final rowIndices = entry.value;
        final firstRowIndex = rowIndices.first;
        final targetValue = rows[firstRowIndex].data[relationship.targetColumn];
        
        // Update all rows in the group
        for (int i = 1; i < rowIndices.length; i++) {
          final rowIndex = rowIndices[i];
          setState(() {
            rows[rowIndex].data[relationship.targetColumn] = targetValue;
          });
        }
      }
    }
  }

  void _deleteRelationship(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.confirmDelete),
        content: Text(
          'Are you sure you want to delete the relationship between '
          '${columnRelationships[index].sourceColumn} and '
          '${columnRelationships[index].targetColumn}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              _pushUndoState();
              
              setState(() {
                final rel = columnRelationships[index];
                _logUpdate('Deleted relationship: ${rel.sourceColumn} → ${rel.targetColumn}', 'structure');
                columnRelationships.removeAt(index);
              });
              Navigator.pop(context);
              _updateGrid();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
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
  
  // ======== UNDO/REDO FUNCTIONALITY ========
  void _pushUndoState() {
    if (!mounted) return;
    
    final currentState = {
      "columns": jsonEncode(columns.map((c) => c.toMap()).toList()),
      "rows": jsonEncode(rows.map((r) => r.toMap()).toList()),
      "relationships": jsonEncode(columnRelationships.map((r) => r.toMap()).toList()),
    };
    
    _undoStack.add(currentState);
    
    // Clear redo stack when new action is performed
    _redoStack.clear();
    
    // Limit undo stack size
    if (_undoStack.length > _maxUndoStates) {
      _undoStack.removeAt(0);
    }
  }

  void _undo() {
    if (_undoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to undo')),
      );
      return;
    }

    // Store current state for redo
    final currentState = {
      "columns": jsonEncode(columns.map((c) => c.toMap()).toList()),
      "rows": jsonEncode(rows.map((r) => r.toMap()).toList()),
      "relationships": jsonEncode(columnRelationships.map((r) => r.toMap()).toList()),
    };
    
    _redoStack.add(currentState);
    
    // Restore previous state
    final state = _undoStack.removeLast();
    _restoreState(state);
    
    _logUpdate('Undo operation performed', 'action');
  }
  
  void _redo() {
    if (_redoStack.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to redo')),
      );
      return;
    }
    
    // Store current state for undo
    final currentState = {
      "columns": jsonEncode(columns.map((c) => c.toMap()).toList()),
      "rows": jsonEncode(rows.map((r) => r.toMap()).toList()),
      "relationships": jsonEncode(columnRelationships.map((r) => r.toMap()).toList()),
    };
    
    _undoStack.add(currentState);
    
    // Restore next state
    final state = _redoStack.removeLast();
    _restoreState(state);
    
    _logUpdate('Redo operation performed', 'action');
  }
  
  void _restoreState(Map<String, dynamic> state) {
    if (!mounted) return;
    
    try {
      final colsJson = jsonDecode(state["columns"]) as List;
      final rowsJson = jsonDecode(state["rows"]) as List;
      final relationshipsJson = jsonDecode(state["relationships"]) as List;

      setState(() {
        columns = colsJson.map((e) => TableColumn.fromMap(e as Map<String, dynamic>)).toList();
        rows = rowsJson.map((e) => TableRowData.fromMap(e as Map<String, dynamic>)).toList();
        columnRelationships = relationshipsJson.map((e) => ColumnRelationship.fromMap(e as Map<String, dynamic>)).toList();
        
        // Reset row selection
        _rowSelection.clear();
        for (var row in rows) {
          _rowSelection[row.data['id']] = false;
        }
      });
      
      _updateGrid();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error restoring state: $e')),
      );
    }
  }
  
  // ======== UPDATE LOGS ========
  void _showUpdateLogs() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.updateLogs),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: _updateLogs.isEmpty
              ? const Center(child: Text('No update logs available'))
              : ListView.builder(
                  itemCount: _updateLogs.length,
                  itemBuilder: (context, index) {
                    final log = _updateLogs[_updateLogs.length - 1 - index];
                    
                    // Parse log type from prefix
                    Color logColor = AppColors.textPrimary;
                    IconData logIcon = Icons.info_outline;
                    
                    if (log.contains('[success]')) {
                      logColor = AppColors.success;
                      logIcon = Icons.check_circle;
                    } else if (log.contains('[error]')) {
                      logColor = AppColors.error;
                      logIcon = Icons.error;
                    } else if (log.contains('[structure]')) {
                      logColor = AppColors.primary;
                      logIcon = Icons.view_column;
                    } else if (log.contains('[data]')) {
                      logColor = AppColors.info;
                      logIcon = Icons.edit;
                    } else if (log.contains('[action]')) {
                      logColor = AppColors.secondary;
                      logIcon = Icons.touch_app;
                    }
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: Icon(logIcon, color: logColor),
                        title: Text(log),
                        textColor: logColor,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.close),
          ),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _updateLogs.join('\
')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs copied to clipboard')),
              );
            },
            child: const Text('Copy All'),
          ),
        ],
      ),
    );
  }
}

class KeyEventMessage {
  final String type;
  final bool isCtrlPressed;
  final bool isAltPressed;
  final bool isShiftPressed;
  final bool isMetaPressed;
  final int keyCode;

  KeyEventMessage({
    required this.type,
    this.isCtrlPressed = false,
    this.isAltPressed = false,
    this.isShiftPressed = false,
    this.isMetaPressed = false,
    this.keyCode = 0,
  });

  factory KeyEventMessage.fromJson(Map<String, dynamic> json) {
    final keyboardEvent = json['keyboardEvent'] as Map<String, dynamic>;
    
    return KeyEventMessage(
      type: json['type'] as String,
      isCtrlPressed: keyboardEvent['ctrlKey'] == true,
      isAltPressed: keyboardEvent['altKey'] == true,
      isShiftPressed: keyboardEvent['shiftKey'] == true,
      isMetaPressed: keyboardEvent['metaKey'] == true,
      keyCode: (keyboardEvent['keyCode'] as num?)?.toInt() ?? 0,
    );
  }
}
