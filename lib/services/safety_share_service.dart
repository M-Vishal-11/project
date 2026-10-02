import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_service.dart';

/// Publishes a small, recipient-scoped document for live safety sharing.
class SafetyShareService {
  SafetyShareService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<Set<String>> _recipientUids(
    String senderUid, {
    Set<String>? contactIds,
  }) async {
    final contacts = await _db.collection('users').doc(senderUid).collection('contacts').get();
    final recipientUids = <String>{};
    for (final contact in contacts.docs) {
      if (contactIds != null && !contactIds.contains(contact.id)) continue;
      var contactUid = (contact.data()['uid'] ?? '').toString();
      if (contactUid.isEmpty) {
        try {
          final verified = await OTPService.resolveRegisteredContact(
            (contact.data()['phone'] ?? '').toString(),
          );
          contactUid = verified['uid']!;
          await contact.reference.update({'uid': contactUid});
        } catch (_) {
          // Skip unregistered or unverifiable contacts; never expose location to them.
          continue;
        }
      }
      if (contactUid != senderUid) recipientUids.add(contactUid);
    }
    return recipientUids;
  }

  static Future<void> startSos({
    required double latitude,
    required double longitude,
  }) async {
    await _startShare(
      latitude: latitude,
      longitude: longitude,
      sosActive: true,
    );
  }

  static Future<void> startLiveLocation({
    required double latitude,
    required double longitude,
    required Set<String> contactIds,
  }) async {
    await _startShare(
      latitude: latitude,
      longitude: longitude,
      sosActive: false,
      contactIds: contactIds,
    );
  }

  static Future<void> _startShare({
    required double latitude,
    required double longitude,
    required bool sosActive,
    Set<String>? contactIds,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Sign in before sharing location.');

    final profile = await _db.collection('users').doc(user.uid).get();
    if (!profile.exists) throw StateError('Your SafeStep profile was not found.');
    final data = profile.data()!;
    final recipientUids = await _recipientUids(user.uid, contactIds: contactIds);
    if (recipientUids.isEmpty) {
      throw StateError('Add a registered SafeStep close contact before sharing location.');
    }

    await _db.collection('active_safety').doc(user.uid).set({
      'senderUid': user.uid,
      'senderName': (data['name'] ?? 'SafeStep user').toString(),
      'recipientUids': recipientUids.toList(),
      'active': true,
      'sosActive': sosActive,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': null,
      'locationTracking': false,
      'updatedAt': FieldValue.serverTimestamp(),
      'startedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> updateLocation({
    required double latitude,
    required double longitude,
    double? accuracy,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('active_safety').doc(uid).set({
      'senderUid': uid,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setTrackingEnabled(bool enabled) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('active_safety').doc(uid).set({
      'locationTracking': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> stopSos() async {
    await _stopShare();
  }

  static Future<void> stopLiveLocation() async {
    await _stopShare();
  }

  static Future<void> _stopShare() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ref = _db.collection('active_safety').doc(uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) return;
    await ref.update({
      'sosActive': false,
      'active': false,
      'stoppedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
