import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:ibn_al_attar/db_helper.dart';
import 'package:ibn_al_attar/storage_screen.dart';
import 'package:ibn_al_attar/store_data_table_screen.dart';
// Import a package to support reorderable grid view
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({Key? key}) : super(key: key);

  @override
  _AdminPanelScreenState createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  // We'll store storages locally so we can update their order.
  List<Map<String, dynamic>> storageList = [];
  bool isSorting = false;

  @override
  void initState() {
    super.initState();
    _loadStorages();
  }

  Future<void> _loadStorages() async {
    FirebaseService.getStorages().listen((snapshot) {
      setState(() {
        storageList = snapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          data['docId'] = doc.id; // Store the document ID.
          return data;
        }).toList();
      });
    });
  }

  Future<void> _confirmDeleteStore(String docId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Storage'),
            content: const Text(
                'Are you sure you want to delete this storage?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FirebaseService.deleteStorage(docId);
    }
  }

  Future<void> _editStorageName(int index) async {
    TextEditingController controller =
    TextEditingController(text: storageList[index]['name']);

    String? newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Edit Storage Name'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Storage Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Save'),
              ),
            ],
          ),
    );

    if (newName != null && newName.isNotEmpty) {
      setState(() {
        storageList[index]['name'] = newName;
      });
      await FirebaseService.updateStorage(
          storageList[index]['docId'], {'name': newName});
    }
  }

  Future<void> _addStorage() async {
    TextEditingController controller = TextEditingController();

    String? newName = await showDialog<String>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('New Storage'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                  labelText: 'Enter Storage Name'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Add'),
              ),
            ],
          ),
    );

    if (newName != null && newName.isNotEmpty) {
      await FirebaseService.addStorage({'name': newName});
    }
  }

  Future<void> _updateOrder() async {
    for (int i = 0; i < storageList.length; i++) {
      await FirebaseService.updateStorage(
          storageList[i]['docId'], {'order': i});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ابن العطار"),
        backgroundColor: Colors.deepPurple,
        centerTitle: true,
        elevation: 4,
        actions: [
          IconButton(
            icon: Icon(isSorting ? Icons.check : Icons.sort),
            onPressed: () async {
              if (isSorting) {
                await _updateOrder();
              }
              setState(() {
                isSorting = !isSorting;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurple.shade50, Colors.deepPurple.shade100],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            int crossAxisCount = constraints.maxWidth > 1200
                ? 5
                : constraints.maxWidth > 800
                ? 4
                : constraints.maxWidth > 600
                ? 3
                : 2;

            Widget gridView = isSorting
                ? ReorderableGridView.count(
              crossAxisCount: crossAxisCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              padding: const EdgeInsets.all(16),
              children: List.generate(
                storageList.length,
                    (index) =>
                    _buildStorageCard(index,
                        key: ValueKey(storageList[index]['docId'])),
              ),
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  final item = storageList.removeAt(oldIndex);
                  storageList.insert(newIndex, item);
                });
              },
            )
                : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: storageList.length,
              itemBuilder: (context, index) {
                return _buildStorageCard(index);
              },
            );

            return storageList.isEmpty
                ? const Center(
              child: Text(
                "No stores found. Tap '+' to add one.",
                style: TextStyle(fontSize: 18),
              ),
            )
                : gridView;
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        onPressed: _addStorage,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStorageCard(int index, {Key? key}) {
    var storage = storageList[index];

    // Build the card content without wrapping the entire card with ReorderableDragStartListener.
    return Card(
      key: key,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 6,
      shadowColor: Colors.black.withOpacity(0.2),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        // Disable onTap when sorting
        onTap: isSorting
            ? null
            : () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  StorageScreen(storage: storage, docId: storage['docId']),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // When in sorting mode, show a drag handle at the top
              if (isSorting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        storage['name'] ?? "No Name",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    const Icon(Icons.storage, size: 36, color: Colors.deepPurple),
                    const SizedBox(height: 8),
                    Text(
                      storage['name'] ?? "No Name",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              const Spacer(),
              // Only show edit and delete buttons when not sorting.
              if (!isSorting)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon:
                      const Icon(Icons.edit, color: Colors.blue, size: 20),
                      onPressed: () => _editStorageName(index),
                    ),
                    IconButton(
                      icon:
                      const Icon(Icons.delete, color: Colors.red, size: 20),
                      onPressed: () => _confirmDeleteStore(storage['docId']),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}