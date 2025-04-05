import 'package:flutter/material.dart';
import 'package:ibn_al_attar/core/constants/app_strings.dart';
import 'package:ibn_al_attar/data/models/column_relationship.dart';

class CustomDialog {
  /// Generic confirmation dialog
  static Future<bool?> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = AppStrings.confirm,
    String cancelText = AppStrings.cancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  /// Delete confirmation dialog with storage name
  static Future<bool?> showDeleteDialog({
    required BuildContext context,
    required String storageName,
    String title = AppStrings.deleteStorage,
    String confirmText = AppStrings.delete,
    String cancelText = AppStrings.cancel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text('Are you sure you want to delete storage "$storageName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }


  /// Relationship management dialog
  static Future<ColumnRelationship?> showRelationshipDialog({
    required BuildContext context,
    required List<String> numericColumns,
    ColumnRelationship? existingRelationship,
    required List<ColumnRelationship> existingRelationships,
  }) async {
    String? source = existingRelationship?.sourceColumn;
    String? target = existingRelationship?.targetColumn;
    final formKey = GlobalKey<FormState>();

    return await showDialog<ColumnRelationship>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(existingRelationship == null
                ? 'Create Relationship'
                : 'Edit Relationship'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: source,
                    decoration: const InputDecoration(
                      labelText: 'Source Column',
                      border: OutlineInputBorder(),
                    ),
                    items: numericColumns
                        .map((col) => DropdownMenuItem<String>(
                      value: col,
                      child: Text(col),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => source = value),
                    validator: (value) =>
                    value == null ? 'Required field' : null,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: target,
                    decoration: const InputDecoration(
                      labelText: 'Target Column',
                      border: OutlineInputBorder(),
                    ),
                    items: numericColumns
                        .map((col) => DropdownMenuItem<String>(
                      value: col,
                      child: Text(col),
                    ))
                        .toList(),
                    onChanged: (value) => setState(() => target = value),
                    validator: (value) =>
                    value == null ? 'Required field' : null,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCEL'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (formKey.currentState!.validate() &&
                      source != null &&
                      target != null) {
                    try {
                      final relationship = ColumnRelationship(
                        sourceColumn: source!,
                        targetColumn: target!,
                      );
                      relationship.validate(
                        numericColumns: numericColumns,
                        existingRelationships: existingRelationships,
                      );
                      Navigator.pop(context, relationship);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.toString())),
                      );
                    }
                  }
                },
                child: const Text('SAVE'),
              ),
            ],
          );
        },
      ),
    );
  }
}
