import 'package:flutter/material.dart';
import 'package:ibn_al_attar/features/storage/storage_screen.dart';
import 'package:provider/provider.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/widgets/custom_dialog.dart';
import 'package:ibn_al_attar/data/repositories/storage_repository.dart';
import 'package:ibn_al_attar/features/admin_panel/storage_card.dart';
import 'package:ibn_al_attar/features/storage/storage_form.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final repository = Provider.of<StorageRepository>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.adminPanel),
        backgroundColor: AppColors.primary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50), // Adjusted for compactness
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search storages...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: repository.getStorages(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final storages = snapshot.data!
              .where((storage) => storage['name']
              .toString()
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()))
              .toList();

          if (storages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.storage, size: 60, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'No storages found'
                        : 'No matching storages',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_searchQuery.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      child: const Text('Clear search'),
                    ),
                ],
              ),
            );
          }

          return _buildStorageGrid(storages);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StorageForm()),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildStorageGrid(List<Map<String, dynamic>> storages) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;

        // Dynamically set number of columns based on screen width
        int crossAxisCount = 1;
        if (width >= 453) crossAxisCount = 2;
        if (width >= 750) crossAxisCount = 3;
        if (width >= 1000) crossAxisCount = 4;
        if (width >= 1200) crossAxisCount = 5;

        bool isSingleColumn = crossAxisCount == 1;

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isSingleColumn ? 2.0 : 0.95,
          ),
          itemCount: storages.length,
          itemBuilder: (context, index) {
            final storage = storages[index];
            return ResponsiveStorageCard(
              key: ValueKey(storage['id']),
              storage: storage,
              // isSorting: false,
              // isSingleColumn: isSingleColumn,
              onDelete: () => _confirmDelete(context, storage),
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StorageForm(storage: storage),
                ),
              ),
              onEnterStorage: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StorageScreen(
                    storage: storage,
                    docId: storage['id'],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Map<String, dynamic> storage) async {
    final confirmed = await CustomDialog.showDeleteDialog(
      context: context,
      storageName: storage['name'] ?? 'Unnamed Storage',
    );

    if (confirmed == true) {
      await context.read<StorageRepository>().deleteStorage(storage['id']);
    }
  }
}
