import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class BookingApi {
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]);
  Future<Map<String, dynamic>?> profile();
}

class FirebaseBookingApi implements BookingApi {
  FirebaseBookingApi(this.uid);
  final String? uid;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call(data);
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>?> profile() async {
    if (uid == null) return null;
    final data = (await FirebaseFirestore.instance.doc('users/$uid').get())
        .data();
    return data == null ? null : {'contacts': data['booking_contacts']};
  }
}
