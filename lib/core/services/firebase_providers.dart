import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Cloud Functions bölgesi. functions/src/index.ts ile aynı olmalı.
const kFunctionsRegion = 'europe-west1';

final firebaseAuthProvider = Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final storageProvider = Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final realtimeDbProvider =
    Provider<FirebaseDatabase>((_) => FirebaseDatabase.instance);

final functionsProvider = Provider<FirebaseFunctions>(
  (_) => FirebaseFunctions.instanceFor(region: kFunctionsRegion),
);

final messagingProvider =
    Provider<FirebaseMessaging>((_) => FirebaseMessaging.instance);

/// Firestore yol yardımcıları.
extension VisalPaths on FirebaseFirestore {
  DocumentReference<Map<String, dynamic>> userDoc(String uid) =>
      collection('users').doc(uid);

  DocumentReference<Map<String, dynamic>> coupleDoc(String coupleId) =>
      collection('couples').doc(coupleId);

  CollectionReference<Map<String, dynamic>> coupleCol(
    String coupleId,
    String name,
  ) =>
      collection('couples').doc(coupleId).collection(name);
}
