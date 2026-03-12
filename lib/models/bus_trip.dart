import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BusTrip {
  final String id;
  final String busNumber;
  final List<String> citiesOnRoute;
  final String currentCity;
  final String destination;
  final String direction;
  final double heading;
  final LatLng location;
  final String origin;
  final String routeName;
  final double speed;
  final String status;

  BusTrip({
    required this.id,
    required this.busNumber,
    required this.citiesOnRoute,
    required this.currentCity,
    required this.destination,
    required this.direction,
    required this.heading,
    required this.location,
    required this.origin,
    required this.routeName,
    required this.speed,
    required this.status,
  });

  factory BusTrip.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    GeoPoint gp = data['location'] ?? const GeoPoint(0, 0);

    return BusTrip(
      id: doc.id,
      busNumber: data['bus_number'] ?? '',
      citiesOnRoute: List<String>.from(data['cities_on_route'] ?? []),
      currentCity: data['current_city'] ?? '',
      destination: data['destination'] ?? '',
      direction: data['direction'] ?? 'Inbound',
      heading: (data['heading'] ?? 0).toDouble(),
      location: LatLng(gp.latitude, gp.longitude),
      origin: data['origin'] ?? '',
      routeName: data['route_name'] ?? '',
      speed: (data['speed'] ?? 0).toDouble(),
      status: data['status'] ?? 'offline',
    );
  }
}