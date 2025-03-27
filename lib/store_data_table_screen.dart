import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ibn_al_attar/db_helper.dart';

class StoreDataTableScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreDataTableScreen({Key? key, required this.store})
      : super(key: key);

  @override
  _StoreDataTableScreenState createState() => _StoreDataTableScreenState();
}

class _StoreDataTableScreenState extends State<StoreDataTableScreen> {
  // Dynamic column keys (used both for header and keys in each row)
  List<String> columnKeys = ['name', 'quantity', 'price'];
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> columns = [];
  List<Map<String, dynamic>> filteredRows = [];
  TextEditingController searchController = TextEditingController();
  String sortColumn = 'name';
  bool sortAscending = true;


  @override
  void initState() {
    super.initState();
    _initializeColumns();
    _loadData();
  }

  void _initializeColumns() {
    columns = [
      {'key': 'name', 'label': 'Name', 'type': 'string'},
      {'key': 'quantity', 'label': 'Quantity', 'type': 'number'},
      {'key': 'price', 'label': 'Price', 'type': 'number'},
    ];
  }

  Future<void> _loadData() async {
    final doc = await FirebaseFirestore.instance
        .collection('storages')
        .doc(widget.store['docId'])
        .get();

    if (doc.exists) {
      setState(() {
        rows = [doc.data() as Map<String, dynamic>];
        filteredRows = List.from(rows);
      });
    }
  }

  void _sortData(String columnKey, String type) {
    setState(() {
      if (sortColumn == columnKey) {
        sortAscending = !sortAscending;
      } else {
        sortColumn = columnKey;
        sortAscending = true;
      }

      filteredRows.sort((a, b) {
        dynamic aValue = a[columnKey];
        dynamic bValue = b[columnKey];

        if (type == 'number') {
          aValue ??= 0;
          bValue ??= 0;
          return sortAscending
              ? aValue.compareTo(bValue)
              : bValue.compareTo(aValue);
        }

        return sortAscending
            ? aValue.toString().compareTo(bValue.toString())
            : bValue.toString().compareTo(aValue.toString());
      });
    });
  }

  void _filterData(String query) {
    setState(() {
      filteredRows = rows.where((row) {
        return columns.any((col) {
          final value = row[col['key']].toString().toLowerCase();
          return value.contains(query.toLowerCase());
        });
      }).toList();
    });
  }

  // Add these new methods for column management
  Future<void> _editColumn(int columnIndex) async {
    // ... (similar to add column but with existing data)
  }

  Future<void> _deleteColumn(int columnIndex) async {
    // ... (confirmation dialog and column removal)
  }

  Future<void> _updateRow(Map<String, dynamic> updatedRow, String docId) async {
    // Update the Firestore document if needed.
    await FirebaseService.updateStorage(docId, updatedRow);
  }

  void _addRow() {
    // Create a new row with default values for each column.
    Map<String, dynamic> newRow = {};
    for (var key in columnKeys) {
      if (key == 'name') {
        newRow[key] = 'New Item';
      } else if (key == 'quantity') {
        newRow[key] = 0;
      } else if (key == 'price') {
        newRow[key] = 0.0;
      } else {
        newRow[key] = ''; // default empty for additional columns
      }
    }
    setState(() {
      rows.add(newRow);
    });
  }

  void _addColumn(String columnKey) {
    setState(() {
      columnKeys.add(columnKey);
      // Add a default value for the new column in each existing row.
      for (var row in rows) {
        row[columnKey] = '';
      }
    });
  }

  Future<void> _deleteRow(int index) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Row'),
        content: const Text('Are you sure you want to delete this row?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        rows.removeAt(index);
      });
    }
  }

  void _showAddColumnDialog() {
    String newKey = '';
    String newLabel = '';
    String selectedType = 'string';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Column'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Column Key'),
              onChanged: (v) => newKey = v.trim(),
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Column Label'),
              onChanged: (v) => newLabel = v.trim(),
            ),
            DropdownButtonFormField<String>(
              value: selectedType,
              items: ['string', 'number', 'date']
                  .map((t) => DropdownMenuItem(
                value: t,
                child: Text(t),
              ))
                  .toList(),
              onChanged: (v) => selectedType = v!,
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
              if (newKey.isNotEmpty) {
                setState(() {
                  columns.add({
                    'key': newKey,
                    'label': newLabel.isNotEmpty ? newLabel : newKey,
                    'type': selectedType
                  });
                  // Update all rows with new column
                  for (var row in rows) {
                    row[newKey] = _getDefaultValue(selectedType);
                  }
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
  dynamic _getDefaultValue(String type) {
    switch (type) {
      case 'number':
        return 0;
      case 'date':
        return DateTime.now();
      default:
        return '';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _buildCellWidget(Map<String, dynamic> row, Map<String, dynamic> col) {
    return EditableText(
      controller: TextEditingController(
        text: row[col['key']?.toString() ?? ''],
      ),
      focusNode: FocusNode(),
      style: const TextStyle(),
      onChanged: (value) {
        setState(() {
          row[col['key'] = _parseValue(value, col['type'])];
        });
        _updateRow(row, widget.store['docId']);
      },
      keyboardType: col['type'] == 'number'
          ? TextInputType.number
          : TextInputType.text, cursorColor: Colors.deepOrangeAccent, backgroundCursorColor: Colors.lightBlueAccent,
    );
  }

  dynamic _parseValue(String value, String type) {
    switch (type) {
      case 'number':
        return num.tryParse(value) ?? 0;
      case 'date':
        return DateTime.tryParse(value);
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build dynamic DataTable columns.
    List<DataColumn> dataColumns = columnKeys
        .map((key) => DataColumn(label: Text(_capitalize(key))))
        .toList();
    // Add an extra column for the delete action.
    dataColumns.add(const DataColumn(label: Text('Actions')));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.store['name']),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            onPressed: _showAddColumnDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: _filterData,
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: columns.indexWhere((c) => c['key'] == sortColumn),
                sortAscending: sortAscending,
                columns: columns.map<DataColumn>((col) {
                  return DataColumn(
                    label: InkWell(
                      onTap: () => _sortData(col['key'], col['type']),
                      child: Text(col['label']),
                    ),
                    onSort: (columnIndex, ascending) {
                      _sortData(col['key'], col['type']);
                    },
                  );
                }).toList(),
                rows: filteredRows.map<DataRow>((row) {
                  return DataRow(
                    cells: columns.map<DataCell>((col) {
                      return DataCell(
                        _buildCellWidget(row, col),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRow,
        child: const Icon(Icons.add),
      ),
    );
  }
}
