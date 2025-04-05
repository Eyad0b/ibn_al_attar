// services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final _firestore = FirebaseFirestore.instance;

  // جميع عمليات Firestore مع التعامل مع الأخطاء
  static Future<void> updateStorage(String docId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('storages').doc(docId).update(data);
    } on FirebaseException catch (e) {
      throw 'Firebase updateStorage Error: ${e.message}';
    }
  }

  static Future<void> addStorage(Map<String, dynamic> data) async {
    try {
      await _firestore.collection('storages').add(data);
    } on FirebaseException catch (e) {
      throw 'Firebase addStorage Error: ${e.message}';
    }
  }

  static Stream<QuerySnapshot> getStorages() {
    try {
      return _firestore.collection('storages').snapshots();
    } on FirebaseException catch (e) {
      throw 'Firebase getStorages Error: ${e.message}';
    }
  }

  static Future<void> deleteStorage(String docId) async {
    try {
      await _firestore.collection('storages').doc(docId).delete();
    } on FirebaseException catch (e) {
      throw 'Firebase deleteStorage Error: ${e.message}';
    }
  }
}

