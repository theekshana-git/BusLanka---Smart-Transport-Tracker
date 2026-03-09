import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'role.dart';

class PassengerPage extends StatefulWidget {
  const PassengerPage({super.key});

  @override
  State<PassengerPage> createState() => _PassengerPageState();
}

class _PassengerPageState extends State<PassengerPage> {
  static const Color primaryBlue = Color(0xFF112D75);
  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);
  
  final String googleApiKey = "AIzaSyBjeK2zWLVNjYMKe7_lJwf2P_cO4yvPCZs"; 

  GoogleMapController? mapController;
  BitmapDescriptor? busIcon;
  bool _isLocating = true;
  
  // Use Maps for better update detection
  Map<PolylineId, Polyline> _polylines = {};
  Map<MarkerId, Marker> _destinationMarkers = {}; 
  late PolylinePoints polylinePoints;

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleApiKey);
    _loadMarkerIcon();
    _initLocationSequence();
  }

  Future<void> _loadMarkerIcon() async {
    busIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(30, 60)), 
      'assets/bus_marker.png',
    );
    if (mounted) setState(() {});
  }

  Future<void> _initLocationSequence() async {
    try {
      Position position = await _determinePosition();
      if (mounted) setState(() => _isLocating = false);
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14),
      );
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return Future.error('Location services disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  // UPDATED: Logic to verify if user is on route and calculate ETA
  Future<Map<String, String>> _getRouteData(LatLng busLocation, LatLng userLatLng, LatLng targetLatLng, double heading) async {
    String status = "Away";
    String eta = "--";

    double bearingToUser = Geolocator.bearingBetween(
      busLocation.latitude, busLocation.longitude, userLatLng.latitude, userLatLng.longitude,
    );
    if (bearingToUser < 0) bearingToUser += 360;
    double diff = (heading - bearingToUser).abs();
    if (diff > 180) diff = 360 - diff;
    
    bool isHeadingToUser = diff < 90;

    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${busLocation.latitude},${busLocation.longitude}'
        '&destination=${targetLatLng.latitude},${targetLatLng.longitude}'
        '&waypoints=${userLatLng.latitude},${userLatLng.longitude}'
        '&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['routes'].isNotEmpty) {
          var legToUser = json['routes'][0]['legs'][0];
          int distMeters = legToUser['distance']['value'];

          if (isHeadingToUser && distMeters < 15000) { // 15km threshold
            status = "Approaching";
            eta = legToUser['duration']['text'];
          }
        }
      }
    } catch (e) { debugPrint("API Error: $e"); }

    return {"status": status, "eta": eta};
  }

  void _showBusDetails(Map<String, dynamic> data, LatLng busPos) async {
    // 1. CLEAR previous overlays
    setState(() {
      _polylines.clear();
      _destinationMarkers.clear();
    });

    const Map<String, LatLng> terminalCoordinates = {
      "Colombo Central Bus Stand": LatLng(6.934971, 79.855155),
      "Kottawa Bus Stand": LatLng(6.841308, 79.964048),
      "Athurugiriya Bus Stand": LatLng(6.877492, 79.989499),
      "Meegoda Bus Stand": LatLng(6.844225, 80.046221),
    };

    String direction = data['direction'] ?? "Inbound";
    String targetTerminalName = (direction == "Inbound") ? (data['destination'] ?? "") : (data['origin'] ?? "");
    LatLng targetLatLng = terminalCoordinates[targetTerminalName] ?? _defaultLocation;

    // 2. OPEN Bottom Sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true, // Crucial for layout
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FutureBuilder<Map<String, String>>(
              future: _fetchAndDraw(busPos, targetLatLng, data, targetTerminalName),
              builder: (context, snapshot) {
                bool isLoading = !snapshot.hasData;
                String eta = snapshot.data?['eta'] ?? "--";
                String status = snapshot.data?['status'] ?? "Checking...";

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(data['route_name'] ?? 'Unknown Route', 
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
                          ),
                          if (!isLoading) _liveBadge(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text("${data['bus_number']} • $direction to $targetTerminalName", 
                          style: const TextStyle(color: Colors.black54, fontSize: 14)),
                      const Divider(height: 30),
                      if (isLoading)
                        const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _infoColumn(Icons.access_time, "ETA", eta),
                            _infoColumn(
                              status == "Approaching" ? Icons.check_circle : Icons.warning_amber_rounded, 
                              "Status", status,
                              color: status == "Approaching" ? Colors.green : Colors.orange
                            ),
                            _infoColumn(Icons.speed, "Speed", "${data['speed'] ?? 0} km/h"),
                          ],
                        ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue, 
                            padding: const EdgeInsets.all(15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Close", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      )
                    ],
                  ),
                );
              }
            );
          }
        );
      },
    );
  }

  Future<Map<String, String>> _fetchAndDraw(LatLng busPos, LatLng targetPos, Map<String, dynamic> data, String terminalName) async {
    Position userPos = await Geolocator.getCurrentPosition();
    LatLng userLatLng = LatLng(userPos.latitude, userPos.longitude);
    
    var routeInfo = await _getRouteData(busPos, userLatLng, targetPos, (data['heading'] ?? 0).toDouble());

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(busPos.latitude, busPos.longitude),
        destination: PointLatLng(targetPos.latitude, targetPos.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (mounted) {
      setState(() {
        if (result.points.isNotEmpty) {
          final polylineId = PolylineId("route_line"); // Unique static ID for the current focus
          _polylines[polylineId] = Polyline(
            polylineId: polylineId,
            points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: primaryBlue.withOpacity(0.7),
            width: 5,
            jointType: JointType.round,
          );
        }
        
        final markerId = MarkerId("destination_marker");
        _destinationMarkers[markerId] = Marker(
          markerId: markerId,
          position: targetPos,
          infoWindow: InfoWindow(title: terminalName),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );
      });
    }
    return routeInfo;
  }

  Widget _infoColumn(IconData icon, String label, String value, {Color color = primaryBlue}) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _liveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
      child: const Text("LIVE", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: _appBarTitle(),
        actions: [_logoutButton(context)],
      ),
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('active_trips').where('status', isEqualTo: 'live').snapshots(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};
              
              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  GeoPoint point = data['location'];
                  LatLng busPos = LatLng(point.latitude, point.longitude);
                  
                  markers.add(
                    Marker(
                      markerId: MarkerId(doc.id),
                      position: busPos,
                      rotation: (data['heading'] ?? 0).toDouble(),
                      anchor: const Offset(0.5, 0.5),
                      icon: busIcon ?? BitmapDescriptor.defaultMarker,
                      onTap: () => _showBusDetails(data, busPos),
                    ),
                  );
                }
              }

              // Combine live bus markers with our temporary destination marker
              markers.addAll(_destinationMarkers.values);

              return GoogleMap(
                initialCameraPosition: const CameraPosition(target: _defaultLocation, zoom: 12),
                onMapCreated: (c) => mapController = c,
                markers: markers,
                polylines: Set<Polyline>.of(_polylines.values),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() { _polylines.clear(); _destinationMarkers.clear(); }),
              );
            },
          ),
          if (_isLocating) _loader(),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBlueFooter()),
        ],
      ),
    );
  }

   Widget _loader() => Container(color: Colors.white.withOpacity(0.7), child: const Center(child: CircularProgressIndicator()));

  Widget _appBarTitle() => Row(children: [
    Image.asset('assets/white.png', height: 50, errorBuilder: (c, e, s) => const Icon(Icons.bus_alert, color: Colors.white)),
    const SizedBox(width: 12),
    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Bus Lanka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      Text('Hi, Passenger', style: TextStyle(fontSize: 12, color: Colors.white70)),
    ])
  ]);

  Widget _buildBlueFooter() => Container(
    color: primaryBlue,
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: SafeArea(top: false, child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _footerNavButton("Contact Us", Icons.contact_support_outlined),
      _footerNavButton("Feedback", Icons.feedback_outlined),
    ])),
  );

  Widget _footerNavButton(String t, IconData i) => InkWell(
    onTap: () {},
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(i, color: Colors.white),
      Text(t, style: const TextStyle(color: Colors.white, fontSize: 10))
    ]),
  );

  Widget _logoutButton(BuildContext context) => IconButton(
    icon: const Icon(Icons.logout, color: Colors.white),
    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SelectRolePage())),
  );
}