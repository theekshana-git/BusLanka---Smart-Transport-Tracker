import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role.dart';

class PassengerPage extends StatefulWidget {
  const PassengerPage({super.key});

  @override
  State<PassengerPage> createState() => _PassengerPageState();
}

class _PassengerPageState extends State<PassengerPage> {
  static const Color primaryBlue = Color(0xFF112D75);
  static const LatLng _initialPosition = LatLng(6.9271, 79.8612); // Colombo
  
  late GoogleMapController mapController;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
  }

  // This is the missing piece: Requesting permission at startup
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // If we reach here, permissions are granted and the blue dot will appear
    setState(() {}); 
  }

  void _goToUserLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      mapController.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude), 15));
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Image.asset(
              'assets/white.png', 
              height: 60, 
              width: 60,
              errorBuilder: (context, error, stackTrace) => 
                  const Icon(Icons.directions_bus, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bus Lanka', 
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                Text('Hi, Passenger', 
                  style: TextStyle(fontSize: 14, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [_logoutButton(context)],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('active_trips')
            .where('status', isEqualTo: 'live')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("Error loading markers"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          Set<Marker> markers = snapshot.data!.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            GeoPoint point = data['location'];

            return Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(point.latitude, point.longitude),
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: InfoWindow(title: data['route_name'] ?? 'Bus'),
            );
          }).toSet();

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(target: _initialPosition, zoom: 14),
                onMapCreated: (controller) => mapController = controller,
                markers: markers,
                zoomControlsEnabled: false,
                myLocationEnabled: true, // Shows the blue dot
                myLocationButtonEnabled: false, // We use our own custom button
              ),

              // FILTER BUTTON
              Positioned(
                top: 20,
                right: 15,
                child: FloatingActionButton.small(
                  heroTag: "filterBtn",
                  backgroundColor: primaryBlue,
                  onPressed: () { /* TODO: Filter logic */ },
                  child: const Icon(Icons.filter_list, color: Colors.white),
                ),
              ),

              // LOCATE ME BUTTON
              Positioned(
                bottom: 110, 
                right: 15,
                child: FloatingActionButton(
                  heroTag: "locationBtn",
                  backgroundColor: primaryBlue,
                  onPressed: _goToUserLocation,
                  child: const Icon(Icons.my_location, color: Colors.white),
                ),
              ),

              // BLUE FOOTER SECTION
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBlueFooter(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBlueFooter() {
    return Container(
      decoration: const BoxDecoration(
        color: primaryBlue,
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2))
        ],
      ),
      child: SafeArea( 
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _footerNavButton("Contact Us", Icons.contact_support_outlined),
              Container(width: 1, height: 40, color: Colors.white24),
              _footerNavButton("Any Feedback?", Icons.feedback_outlined),
            ],
          ),
        ),
      ),
    );
  }

  Widget _footerNavButton(String title, IconData icon) {
    return Expanded(
      child: InkWell(
        onTap: () {
          debugPrint("$title tapped");
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 5),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: IconButton(
        icon: const Icon(Icons.logout, color: Colors.white),
        onPressed: () => Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (context) => const SelectRolePage())),
      ),
    );
  }
}