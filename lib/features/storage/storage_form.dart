import 'package:flutter/material.dart';
import 'package:ibn_al_attar/core/constants/app_colors.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/core/utils/validators.dart';
import 'package:ibn_al_attar/core/widgets/custom_dialog.dart';
import 'package:ibn_al_attar/core/widgets/custom_text_field.dart';
import 'package:ibn_al_attar/data/models/table_column.dart';
import 'package:ibn_al_attar/data/repositories/storage_repository.dart';
import 'package:provider/provider.dart';

class StorageForm extends StatefulWidget {
  final Map<String, dynamic>? storage;

  const StorageForm({super.key, this.storage});

  @override
  State<StorageForm> createState() => _StorageFormState();
}

class _StorageFormState extends State<StorageForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.storage?['name'] ?? '',
    );
  }

  Future<void> _saveStorage() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final repository = context.read<StorageRepository>();
      final data = {
        'name': _nameController.text.trim(),
        'columns': defaultColumns.map((col) => col.toMap()).toList(),
        'rows': [],
        'relationships': [],
        'thresholds': [],
      };

      if (widget.storage == null) {
        await repository.addStorage(data);
      } else {
        await repository.updateStorage(widget.storage!['id'], data);
      }

      Navigator.pop(context);
    } catch (e) {
      CustomDialog.showConfirmationDialog(
        context: context,
        title: AppStrings.error,
        content: e.toString(),
      );
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.storage == null
              ? AppStrings.newStorage
              : AppStrings.editStorage,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              CustomTextField(
                controller: _nameController,
                label: AppStrings.storageName,
                validator: Validators.validateRequired,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveStorage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    widget.storage == null
                        ? AppStrings.create
                        : AppStrings.save,
                    style: Theme.of(context)
                        .textTheme
                        .button
                        ?.copyWith(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
