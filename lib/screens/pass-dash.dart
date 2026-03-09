import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
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
  
  Set<Polyline> _polylines = {};
  Set<Marker> _destinationMarkers = {}; // NEW: To show where the bus is going
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
        CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15),
      );
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
      debugPrint("Location Error: $e");
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return Future.error('Denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<void> _drawRoute(LatLng busLocation, Map<String, dynamic> data) async {
    const Map<String, LatLng> terminalCoordinates = {
      "Colombo Central Bus Stand": LatLng(6.934971, 79.855155),
      "Kottawa Bus Stand": LatLng(6.841308, 79.964048),
      "Athurugiriya Bus Stand": LatLng(6.877492, 79.989499),
      "Meegoda Bus Stand": LatLng(6.844225, 80.046221),
    };

    String direction = data['direction'] ?? "Inbound";
    String originName = data['origin'] ?? "";
    String destinationName = data['destination'] ?? "";

    // LOGIC FIX: 
    // If Inbound -> target is Destination (e.g., Colombo)
    // If Outbound -> target is the Origin (the suburban start point)
    String targetTerminalName = (direction == "Inbound") ? destinationName : originName;
    
    LatLng targetLatLng = terminalCoordinates[targetTerminalName] ?? _defaultLocation;

    try {
      PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
        request: PolylineRequest(
          origin: PointLatLng(busLocation.latitude, busLocation.longitude),
          destination: PointLatLng(targetLatLng.latitude, targetLatLng.longitude),
          mode: TravelMode.driving,
        ),
      );

      if (result.points.isNotEmpty) {
        List<LatLng> polylineCoordinates = result.points
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        if (mounted) {
          setState(() {
            // Add the route line
            _polylines = {
              Polyline(
                polylineId: const PolylineId("bus_route_line"),
                points: polylineCoordinates,
                color: primaryBlue.withOpacity(0.8),
                width: 6,
                jointType: JointType.round,
              )
            };

            // NEW: Add a marker at the destination terminal
            _destinationMarkers = {
              Marker(
                markerId: const MarkerId("target_terminal"),
                position: targetLatLng,
                infoWindow: InfoWindow(title: targetTerminalName),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              )
            };
          });
          _fitRoute(busLocation, targetLatLng);
        }
      }
    } catch (e) {
      debugPrint("Route Fetch Error: $e");
    }
  }

  void _fitRoute(LatLng start, LatLng end) {
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(
        start.latitude < end.latitude ? start.latitude : end.latitude,
        start.longitude < end.longitude ? start.longitude : end.longitude,
      ),
      northeast: LatLng(
        start.latitude > end.latitude ? start.latitude : end.latitude,
        start.longitude > end.longitude ? start.longitude : end.longitude,
      ),
    );
    mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _showBusDetails(Map<String, dynamic> data, LatLng busPos) {
    _drawRoute(busPos, data);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
                Text(data['bus_number'] ?? 'Bus', 
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue)),
                _liveBadge(),
              ],
            ),
            const SizedBox(height: 5),
            Text(data['route_name'] ?? 'Route', style: const TextStyle(color: Colors.black54)),
            const Divider(height: 30),
            Row(
              children: [
                const Icon(Icons.multiple_stop, color: primaryBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text("${data['origin']} → ${data['destination']}", 
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, padding: const EdgeInsets.all(15)),
                onPressed: () => Navigator.pop(context),
                child: const Text("Close", style: TextStyle(color: Colors.white)),
              ),
            )
          ],
        ),
      ),
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
                markers = snapshot.data!.docs.map((doc) {
                  Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                  GeoPoint point = data['location'];
                  LatLng busPos = LatLng(point.latitude, point.longitude);
                  
                  return Marker(
                    markerId: MarkerId(doc.id),
                    position: busPos,
                    rotation: (data['heading'] ?? 0).toDouble(),
                    anchor: const Offset(0.5, 0.5),
                    icon: busIcon ?? BitmapDescriptor.defaultMarker,
                    onTap: () => _showBusDetails(data, busPos),
                  );
                }).toSet();
                
                // Add the destination marker to the set of markers being displayed
                markers.addAll(_destinationMarkers);
              }
              return GoogleMap(
                initialCameraPosition: const CameraPosition(target: _defaultLocation, zoom: 14),
                onMapCreated: (c) => mapController = c,
                markers: markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onTap: (_) => setState(() {
                  _polylines.clear();
                  _destinationMarkers.clear();
                }),
              );
            },
          ),
          if (_isLocating) _loader(),
          
          Positioned(
            top: 15,
            right: 15,
            child: FloatingActionButton.small(
              heroTag: 'filterBtn', 
              backgroundColor: primaryBlue, 
              onPressed: () {}, 
              child: const Icon(Icons.filter_list, color: Colors.white)
            ),
          ),

          Positioned(
            bottom: 110, 
            right: 15,
            child: FloatingActionButton(
              heroTag: 'locationBtn', 
              backgroundColor: primaryBlue, 
              onPressed: _initLocationSequence, 
              child: const Icon(Icons.my_location, color: Colors.white)
            ),
          ),
          
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