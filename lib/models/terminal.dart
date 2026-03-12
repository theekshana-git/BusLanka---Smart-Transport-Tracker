import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class Terminal {
  final String name;
  final LatLng location;

  Terminal({required this.name, required this.location});

  factory Terminal.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint gp = data['location'] ?? const GeoPoint(0, 0);
    
    return Terminal(
      name: data['name'] ?? '',
      location: LatLng(gp.latitude, gp.longitude),
    );
  }
}