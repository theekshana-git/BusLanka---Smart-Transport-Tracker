import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:async';
import 'role.dart';

class DriverDashboard extends StatefulWidget {
  final String userEmail;
  const DriverDashboard({super.key, required this.userEmail});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  static const Color primaryBlue = Color(0xFF112D75);
  static const Color inactiveRed = Color(0xFFFF4040);
  static const Color activeGreen = Color(0xFF79E780);
  final String googleApiKey = "AIzaSyBjeK2zWLVNjYMKe7_lJwf2P_cO4yvPCZs";

  GoogleMapController? mapController;
  StreamSubscription<Position>? _positionStream;
  late PolylinePoints polylinePoints;
  
  // --- Inactivity Feature Addition ---
  Timer? _inactivityTimer;
  // ------------------------------------

  bool _isTripLive = false;
  bool _isLocating = true;
  String? _assignedBusNumber;
  String? _actualDocId;      
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _originalBusData;
  
  final Map<String, LatLng> _routeCityCoordinates = {};
  
  LatLng _currentPos = const LatLng(6.9271, 79.8612); 
  double _heading = 0.0;
  BitmapDescriptor? busIcon;

  final Map<PolylineId, Polyline> _polylines = {};
  final Map<MarkerId, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleApiKey);
    _loadBusIcon();
    _fetchDriverData();
    _initLocationSequence(); 
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _inactivityTimer?.cancel(); // Clean up timer
    super.dispose();
  }

  // --- Inactivity Logic ---
  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    // Set to 10 minutes as per requirements
    _inactivityTimer = Timer(const Duration(minutes: 10), () {
      if (_isTripLive && mounted) {
        _toggleTrip(); // Automatically end the trip
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Trip ended automatically due to 10 minutes of inactivity."),
            backgroundColor: inactiveRed,
          ),
        );
      }
    });
  }
  // -------------------------

  Future<void> _loadBusIcon() async {
    busIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(35, 70)), 
      'assets/bus_marker.png'
    );
  }

  Future<void> _initLocationSequence() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      _currentPos = LatLng(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() => _isLocating = false);
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPos, 15),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _fetchDriverData() async {
    var userSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('email', isEqualTo: widget.userEmail)
        .limit(1)
        .get();

    if (userSnap.docs.isNotEmpty) {
      String? busNum = userSnap.docs.first.data()['assigned_bus'];
      if (busNum != null) {
        setState(() => _assignedBusNumber = busNum);
        _listenToBusUpdates();
      }
    }
  }

  void _listenToBusUpdates() {
    FirebaseFirestore.instance
        .collection('active_trips')
        .where('bus_number', isEqualTo: _assignedBusNumber)
        .snapshots()
        .listen((querySnap) {
      if (querySnap.docs.isNotEmpty && mounted) {
        var doc = querySnap.docs.first;
        bool statusIsLive = doc.data()['status'] == 'live';
        
        setState(() {
          _busData = doc.data();
          _actualDocId = doc.id; 
          _isTripLive = statusIsLive;
          _originalBusData ??= Map.from(doc.data());
        });

        if (_isTripLive) {
          _startLocationUpdates();
          _drawRouteToDestination();
        } else {
          _stopTripCleanup();
        }
      }
    });
  }

  void _showDirectionDialog() {
    if (_originalBusData == null) return;
    String terminalA = _originalBusData!['origin'] ?? "Terminal A";
    String terminalB = _originalBusData!['destination'] ?? "Terminal B";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Destination", style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: const Text("Where is this trip heading?"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Column(
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: primaryBlue),
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () { 
                    Navigator.pop(context); 
                    _processStartTrip(isInbound: true); 
                  },
                  child: Text("TO: $terminalA", style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () { 
                    Navigator.pop(context); 
                    _processStartTrip(isInbound: false); 
                  },
                  child: Text("TO: $terminalB", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _processStartTrip({required bool isInbound}) async {
    final source = _originalBusData ?? _busData;
    if (source == null || _actualDocId == null) return;

    String finalDest = isInbound ? source['origin'] : source['destination'];
    String finalOrigin = isInbound ? source['destination'] : source['origin'];
    String directionStr = isInbound ? "inbound" : "outbound";
    
    List<dynamic> stops = List.from(source['cities_on_route'] ?? []);
    if (isInbound) stops = stops.reversed.toList();

    await FirebaseFirestore.instance.collection('active_trips').doc(_actualDocId).update({
      'status': 'live',
      'direction': directionStr, 
      'destination': finalDest,
      'origin': finalOrigin,
      'cities_on_route': stops,
      'current_city': finalOrigin, 
      'last_update': FieldValue.serverTimestamp(),
    });
    
    _cacheRouteCoordinates(stops);
    _updateBusMarker();
  }

  Future<void> _cacheRouteCoordinates(List<dynamic> stops) async {
    try {
      _routeCityCoordinates.clear();
      var termSnap = await FirebaseFirestore.instance.collection('terminals').get();
      for (var doc in termSnap.docs) {
        String name = doc.get('name');
        if (stops.contains(name)) {
          GeoPoint gp = doc.get('location');
          _routeCityCoordinates[name] = LatLng(gp.latitude, gp.longitude);
        }
      }
    } catch (e) {
      debugPrint("Caching failed: $e");
    }
  }

  void _checkAndUpdateCity(Position pos) {
    if (_routeCityCoordinates.isEmpty) return;
    String? detectedCity;
    double minDistance = 500.0; 

    _routeCityCoordinates.forEach((cityName, cityLatLng) {
      double distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, cityLatLng.latitude, cityLatLng.longitude
      );
      if (distance < minDistance) {
        detectedCity = cityName;
      }
    });

    if (detectedCity != null && detectedCity != _busData?['current_city']) {
      FirebaseFirestore.instance.collection('active_trips').doc(_actualDocId).update({
        'current_city': detectedCity,
        'last_update': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _toggleTrip() async {
    if (_actualDocId == null) return;
    if (_isTripLive) {
      await FirebaseFirestore.instance.collection('active_trips').doc(_actualDocId).update({
        'status': 'inactive',
        'last_update': FieldValue.serverTimestamp(),
      });
      _stopTripCleanup(); 
    } else {
      _showDirectionDialog();
    }
  }

  void _updateBusMarker() {
    if (!_isTripLive) return; 
    setState(() {
      _markers[const MarkerId("bus")] = Marker(
        markerId: const MarkerId("bus"),
        position: _currentPos,
        rotation: _heading,
        anchor: const Offset(0.5, 0.5),
        icon: busIcon ?? BitmapDescriptor.defaultMarker,
        zIndex: 10,
      );
    });
  }

  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen((pos) {
      if (_actualDocId != null && _isTripLive) {
        // --- Reset Timeout Timer on every new location ---
        _resetInactivityTimer();
        // -------------------------------------------------

        if (mounted) {
          setState(() {
            _currentPos = LatLng(pos.latitude, pos.longitude);
            _heading = pos.heading;
            _updateBusMarker();
          });
        }
        
        FirebaseFirestore.instance.collection('active_trips').doc(_actualDocId).update({
          'location': GeoPoint(pos.latitude, pos.longitude),
          'heading': pos.heading,
          'speed': (pos.speed * 3.6).round(),
          'last_update': FieldValue.serverTimestamp(),
        });
        _checkAndUpdateCity(pos);
      }
    });
  }

  void _stopTripCleanup() {
    _positionStream?.cancel();
    _inactivityTimer?.cancel(); // Stop monitoring inactivity when trip ends
    _routeCityCoordinates.clear();
    if (mounted) {
      setState(() {
        _polylines.clear(); 
        _markers.clear();   
      });
    }
  }

  Future<void> _drawRouteToDestination() async {
    if (_busData == null || _busData!['destination'] == null) return;
    try {
      var termQuery = await FirebaseFirestore.instance
          .collection('terminals')
          .where('name', isEqualTo: _busData!['destination'])
          .limit(1).get();

      if (termQuery.docs.isNotEmpty) {
        GeoPoint gp = termQuery.docs.first.get('location');
        LatLng dest = LatLng(gp.latitude, gp.longitude);

        PolylineResult res = await polylinePoints.getRouteBetweenCoordinates(
          request: PolylineRequest(
            origin: PointLatLng(_currentPos.latitude, _currentPos.longitude),
            destination: PointLatLng(dest.latitude, dest.longitude),
            mode: TravelMode.driving,
          ),
        );

        if (res.points.isNotEmpty && mounted && _isTripLive) {
          setState(() {
            _polylines[const PolylineId("path")] = Polyline(
              polylineId: const PolylineId("path"),
              points: res.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
              color: primaryBlue.withOpacity(0.5),
              width: 5,
            );
            _markers[const MarkerId("dest")] = Marker(
              markerId: const MarkerId("dest"),
              position: dest,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            );
          });
        }
      }
    } catch (e) { debugPrint(e.toString()); }
  }

  Widget _appBarTitle() {
    String username = widget.userEmail.split('@')[0];
    if (username.isNotEmpty) username = username[0].toUpperCase() + username.substring(1);

    return Row(
      children: [
        Image.asset('assets/white.png', height: 50, errorBuilder: (c,e,s) => const Icon(Icons.bus_alert, color: Colors.white)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bus Lanka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            Text('Hi, $username', style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
      ],
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white), 
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SelectRolePage()))
          )
        ],
      ),
      body: _busData == null ? const Center(child: CircularProgressIndicator()) : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('BUS NUMBER', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              Text(_assignedBusNumber ?? "...", style: const TextStyle(color: primaryBlue, fontSize: 24, fontWeight: FontWeight.bold)),
            ]),
            _statusBadge(),
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: _infoCard("Route", _busData!['route_name'] ?? "N/A", Icons.alt_route)),
            const SizedBox(width: 10),
            Expanded(child: _infoCard("Destination", _busData!['destination'] ?? "N/A", Icons.location_on)),
          ]),
          const SizedBox(height: 15),

          Expanded(child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _currentPos, zoom: 14),
                  onMapCreated: (c) => mapController = c,
                  markers: Set.of(_markers.values),
                  polylines: Set.of(_polylines.values),
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton(
                  mini: true,
                  heroTag: "driverLocateBtn",
                  backgroundColor: primaryBlue,
                  onPressed: _initLocationSequence,
                  child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                ),
              ),
              if (_isLocating) Container(
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.7), borderRadius: BorderRadius.circular(24)),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ],
          )),
          const SizedBox(height: 15),

          ElevatedButton(
            onPressed: _toggleTrip,
            style: ElevatedButton.styleFrom(
              backgroundColor: _isTripLive ? inactiveRed : activeGreen,
              minimumSize: const Size(double.infinity, 60),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(_isTripLive ? "END TRIP" : "START TRIP", style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ]),
      ),
    );
  }

  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _isTripLive ? activeGreen.withOpacity(0.1) : inactiveRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(_isTripLive ? "● LIVE" : "○ INACTIVE", style: TextStyle(color: _isTripLive ? Colors.green.shade700 : inactiveRed, fontWeight: FontWeight.bold, fontSize: 12)),
  );

  Widget _infoCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Icon(icon, size: 14, color: primaryBlue),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
    ]),
  );
}