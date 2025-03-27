// // widgets/relationship_manager.dart
//
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter/services.dart';
// import 'package:ibn_al_attar/storage_screen.dart';
// import 'package:pluto_grid/pluto_grid.dart';
// import 'package:ibn_al_attar/db_helper.dart';
// import 'package:ibn_al_attar/store_data_table_screen.dart';
//
//
//
// class RelationshipManager extends StatelessWidget {
//   final List<ColumnRelationship> relationships;
//   final Function(int) onDelete;
//   final Function(int) onEdit;
//
//   const RelationshipManager({
//     required this.relationships,
//     required this.onDelete,
//     required this.onEdit,
//   });
//
//   @override
//   Widget build(BuildContext context) {
//     return AlertDialog(
//       title: Text(editIndex == null ? 'Create Relationship' : 'Edit Relationship'),
//       content: Form(
//         key: _relationshipFormKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             DropdownButtonFormField<String>(
//               value: source,
//               decoration: const InputDecoration(labelText: 'Source Column'),
//               items: columns
//                   .where((c) => c.type == DataType.number)
//                   .map((c) => DropdownMenuItem(
//                 value: c.name,
//                 child: Text(c.name),
//               ))
//                   .toList(),
//               onChanged: (value) => setState(() => source = value),
//               validator: (value) =>
//               value == null ? 'Select source column' : null,
//             ),
//             const SizedBox(height: 20),
//             DropdownButtonFormField<String>(
//               value: target,
//               decoration: const InputDecoration(labelText: 'Target Column'),
//               items: columns
//                   .where((c) => c.type == DataType.number)
//                   .map((c) => DropdownMenuItem(
//                 value: c.name,
//                 child: Text(c.name),
//               ))
//                   .toList(),
//               onChanged: (value) => setState(() => target = value),
//               validator: (value) =>
//               value == null ? 'Select target column' : null,
//             ),
//           ],
//         ),
//       ),
//       actions: [
//         TextButton(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//         ElevatedButton(
//           onPressed: () {
//             if (_relationshipFormKey.currentState!.validate()) {
//               final newRelationship = ColumnRelationship(
//                 sourceColumn: source!,
//                 targetColumn: target!,
//               );
//
//               setState(() {
//                 if (editIndex != null) {
//                   columnRelationships[editIndex] = newRelationship;
//                 } else {
//                   columnRelationships.add(newRelationship);
//                 }
//               });
//               Navigator.pop(context);
//               _updateGrid();
//             }
//           },
//           child: Text(editIndex == null ? 'Create' : 'Update'),
//         ),
//       ],
//     );
//   }
// }