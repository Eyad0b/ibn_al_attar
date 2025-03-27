import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> addStorage(Map<String, dynamic> data) async {
    await _firestore.collection('storages').add(data);
  }

  static Stream<QuerySnapshot> getStorages() {
    return _firestore.collection('storages').snapshots();
  }

  static Future<void> deleteStorage(String docId) async {
    await _firestore.collection('storages').doc(docId).delete();
  }

  static Future<void> updateStorage(String docId, Map<String, dynamic> data) async {
    await _firestore.collection('storages').doc(docId).update(data);
  }
}

