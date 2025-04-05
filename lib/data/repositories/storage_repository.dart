import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ibn_al_attar/data/models/column_relationship.dart';
import 'package:ibn_al_attar/data/models/table_column.dart';
import 'package:ibn_al_attar/data/models/threshold_condition.dart';

class StorageRepository {
  final FirebaseFirestore _firestore;

  StorageRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get real-time stream of storages
  Stream<List<Map<String, dynamic>>> getStorages() {
    return _firestore.collection('storages').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    });
  }

  Future<void> batchUpdateRows(String storageId, List<Map<String, dynamic>> rows) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('storages').doc(storageId).collection('rows');

    for (final row in rows) {
      batch.set(collection.doc(row['id']), row);
    }

    await batch.commit();
  }

  Future<void> enableOfflinePersistence() async {
    await FirebaseFirestore.instance.enablePersistence(const PersistenceSettings(
      synchronizeTabs: true,
    ));
  }

  // Add new storage with validation
  Future<void> addStorage(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('storages').add({
        ...data,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to add storage: ${e.message}';
    }
  }

  // Update existing storage
  Future<void> updateStorage(String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('storages').doc(docId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw 'Failed to update storage: ${e.message}';
    }
  }

  // Delete storage
  Future<void> deleteStorage(String docId) async {
    try {
      await _firestore.collection('storages').doc(docId).delete();
    } on FirebaseException catch (e) {
      throw 'Failed to delete storage: ${e.message}';
    }
  }

  // Convert Firestore document to domain model
  static Map<String, dynamic> parseDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return {
      'id': doc.id,
      'columns': (data['columns'] as List)
          .map((e) => TableColumn.fromMap(e))
          .toList(),
      'rows': data['rows'] as List<Map<String, dynamic>>,
      'relationships': (data['relationships'] as List)
          .map((e) => ColumnRelationship.fromMap(e))
          .toList(),
      'thresholds': (data['thresholds'] as List)
          .map((e) => ThresholdCondition.fromMap(e))
          .toList(),
      'createdAt': data['createdAt']?.toDate(),
      'updatedAt': data['updatedAt']?.toDate(),
    };
  }
}