import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
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
  GoogleMapController? mapController;
  StreamSubscription<Position>? _positionStream;
  
  bool _isTripLive = false;
  String? _assignedBusNumber;
  String? _actualDocId;      
  Map<String, dynamic>? _busData;
  LatLng _currentPos = const LatLng(6.9271, 79.8612);

  @override
  void initState() {
    super.initState();
    _fetchDriverData();
    _determineInitialPosition();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  /// Gets the phone's actual current location for the initial map view
  Future<void> _determineInitialPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPos = LatLng(position.latitude, position.longitude);
      });
      mapController?.animateCamera(CameraUpdate.newLatLng(_currentPos));
    }
  }

  Future<void> _fetchDriverData() async {
    try {
      var userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: widget.userEmail)
          .limit(1)
          .get();

      if (userSnap.docs.isNotEmpty) {
        var userData = userSnap.docs.first.data();
        String? busNum = userData['assigned_bus'];
        
        if (busNum != null && busNum.isNotEmpty) {
          setState(() => _assignedBusNumber = busNum);
          _listenToBusUpdates();
        }
      }
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  void _listenToBusUpdates() {
    if (_assignedBusNumber == null) return;
    
    FirebaseFirestore.instance
        .collection('active_trips')
        .where('bus_number', isEqualTo: _assignedBusNumber)
        .snapshots()
        .listen((querySnap) {
      if (querySnap.docs.isNotEmpty && mounted) {
        setState(() {
          var doc = querySnap.docs.first;
          _busData = doc.data();
          _actualDocId = doc.id; 
          _isTripLive = _busData?['status'] == 'live';
        });

        // Start or Stop GPS streaming based on status
        if (_isTripLive) {
          _startLocationUpdates();
        } else {
          _positionStream?.cancel();
        }
      }
    });
  }

  /// THE FIX: This sends your REAL phone location to Firestore
  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Updates every 10 meters
      ),
    ).listen((Position position) {
      if (_actualDocId != null && _isTripLive) {
        setState(() {
          _currentPos = LatLng(position.latitude, position.longitude);
        });

        FirebaseFirestore.instance
            .collection('active_trips')
            .doc(_actualDocId)
            .update({
          'location': GeoPoint(position.latitude, position.longitude),
          'heading': position.heading,
          'speed': position.speed * 3.6, // Convert m/s to km/h
          'last_update': FieldValue.serverTimestamp(),
        });
        
        mapController?.animateCamera(CameraUpdate.newLatLng(_currentPos));
      }
    });
  }

  Future<void> _toggleTrip() async {
    if (_actualDocId == null) return;
    String newStatus = _isTripLive ? 'inactive' : 'live';
    
    await FirebaseFirestore.instance
        .collection('active_trips')
        .doc(_actualDocId)
        .update({
      'status': newStatus,
      'last_update': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: _buildAppBarTitle(),
        actions: [_buildLogoutButton()],
      ),
      body: _busData == null 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBusInfoRow(),
                  const SizedBox(height: 20),
                  _buildRouteDropdown(),
                  const SizedBox(height: 20),
                  _buildMapContainer(),
                  const SizedBox(height: 40),
                  _buildActionButton(),
                ],
              ),
            ),
      bottomNavigationBar: _buildBlueFooter(),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildBusInfoRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Bus Number", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue)),
            Text(_busData!['bus_number'] ?? "N/A", style: const TextStyle(fontSize: 18, color: primaryBlue)),
          ],
        ),
        Row(
          children: [
            CircleAvatar(radius: 6, backgroundColor: _isTripLive ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(_isTripLive ? "Active" : "Inactive", style: const TextStyle(fontSize: 18, color: primaryBlue)),
          ],
        )
      ],
    );
  }

  Widget _buildRouteDropdown() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: primaryBlue, borderRadius: BorderRadius.circular(15)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Current Route", style: TextStyle(color: Colors.white70, fontSize: 10)),
              Text(_busData!['route_name'] ?? "Route", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const Icon(Icons.keyboard_arrow_down, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildMapContainer() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryBlue.withOpacity(0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(target: _currentPos, zoom: 15),
        onMapCreated: (c) => mapController = c,
        myLocationEnabled: true, // This shows the blue dot for the driver
        zoomControlsEnabled: false,
      ),
    );
  }

  Widget _buildActionButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _toggleTrip,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTripLive ? Colors.orange : const Color(0xFF72D37A),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text(
          _isTripLive ? "End Trip" : "Start Trip", 
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
        ),
      ),
    );
  }

  Widget _buildAppBarTitle() => Row(
    children: [
      Image.asset('assets/white.png', height: 50, errorBuilder: (c, e, s) => const Icon(Icons.bus_alert, color: Colors.white)),
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bus Lanka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Hi, Driver (${widget.userEmail.split('@')[0]})', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    ],
  );

  Widget _buildLogoutButton() => IconButton(
    icon: const Icon(Icons.logout, color: Colors.white),
    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SelectRolePage())),
  );

  Widget _buildBlueFooter() => Container(
    color: primaryBlue,
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _footerNavButton("Contact Us", Icons.contact_support_outlined),
          _footerNavButton("Feedback", Icons.feedback_outlined),
        ],
      ),
    ),
  );

  Widget _footerNavButton(String t, IconData i) => InkWell(
    onTap: () {},
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: Colors.white),
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );
}