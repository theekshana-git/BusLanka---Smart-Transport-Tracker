import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'role.dart';
import 'package:buslanka/models/bus_trip.dart';
import 'package:buslanka/models/terminal.dart';
import 'package:buslanka/screens/contact-us.dart';
import 'package:buslanka/screens/feedback.dart';

// --- Filter State Variables ---
String? _selectedRoute;
final TextEditingController _destinationController = TextEditingController();

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
  
  // Track zoom to handle dynamic resizing
  double _currentZoom = 14.0; 

  final Map<PolylineId, Polyline> _polylines = {};
  final Map<MarkerId, Marker> _destinationMarkers = {};
  late PolylinePoints polylinePoints;

  String _getTimeAgo(Timestamp? timestamp) {
  if (timestamp == null) return "Unknown";
  
  DateTime lastUpdate = timestamp.toDate();
  Duration diff = DateTime.now().difference(lastUpdate);

  if (diff.inSeconds < 60) {
    return "Just now";
  } else if (diff.inMinutes < 60) {
    return "${diff.inMinutes} mins ago";
  } else if (diff.inHours < 24) {
    return "${diff.inHours} hours ago";
  } else {
    return "${diff.inDays} days ago";
  }
}

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleApiKey);
    // Initial icon load
    _updateBusIcon(_currentZoom);
    _initLocationSequence();
  }

  /// Dynamically updates the bus icon size based on zoom level
  Future<void> _updateBusIcon(double zoom) async {
    double baseWidth;
    
    if (zoom >= 16) {
      baseWidth = 45.0; // Large for street level
    } else if (zoom >= 14) {
      baseWidth = 35.0; // Standard
    } else if (zoom >= 12) {
      baseWidth = 25.0; // Small for city view
    } else {
      baseWidth = 15.0; // Tiny dots for far zoom
    }

    final newIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(baseWidth, baseWidth * 2)),
      'assets/bus_marker.png',
    );

    if (mounted) {
      setState(() {
        busIcon = newIcon;
      });
    }
  }

  Future<void> _initLocationSequence() async {
    try {
      Position position = await _determinePosition();
      if (mounted) setState(() => _isLocating = false);
      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          _currentZoom,
        ),
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
      if (permission == LocationPermission.denied) {
        return Future.error('Denied');
      }
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, String>> _getRouteData(
    BusTrip bus,
    LatLng userLatLng,
    LatLng targetLatLng,
  ) async {
    String status = "Away";
    String eta = "--";

    double bearingToUser = Geolocator.bearingBetween(
      bus.location.latitude,
      bus.location.longitude,
      userLatLng.latitude,
      userLatLng.longitude,
    );
    if (bearingToUser < 0) bearingToUser += 360;
    double diff = (bus.heading - bearingToUser).abs();
    if (diff > 180) diff = 360 - diff;
    bool isHeadingToUser = diff < 90;

    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${bus.location.latitude},${bus.location.longitude}'
        '&destination=${targetLatLng.latitude},${targetLatLng.longitude}'
        '&waypoints=${userLatLng.latitude},${userLatLng.longitude}'
        '&key=$googleApiKey';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['routes'].isNotEmpty) {
          var route = json['routes'][0];
          var legToUser = route['legs'][0];
          int distanceToUser = legToUser['distance']['value'];

          if (isHeadingToUser && distanceToUser < 10000) {
            status = "Approaching";
            eta = legToUser['duration']['text'];
          } else if (distanceToUser < 500) {
            status = "Arriving";
            eta = "Now";
          }
        }
      }
    } catch (e) {
      debugPrint("API Error: $e");
    }
    return {"status": status, "eta": eta};
  }

  void _showBusDetails(BusTrip bus) async {
    setState(() {
      _polylines.clear();
      _destinationMarkers.clear();
    });

    LatLng targetLatLng = _defaultLocation;
    try {
      var terminalQuery = await FirebaseFirestore.instance
          .collection('terminals')
          .where('name', isEqualTo: bus.destination)
          .limit(1)
          .get();

      if (terminalQuery.docs.isNotEmpty) {
        Terminal term = Terminal.fromFirestore(terminalQuery.docs.first);
        targetLatLng = term.location;
      }
    } catch (e) {
      debugPrint("Terminal fetch error: $e");
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return FutureBuilder<Map<String, String>>(
              future: _fetchAndDraw(bus, targetLatLng),
              builder: (context, snapshot) {
                bool isLoading = !snapshot.hasData;
                String eta = snapshot.data?['eta'] ?? "--";
                String status = snapshot.data?['status'] ?? "Checking...";
               
                
                // Formatting the timestamp
                // Note: Replace 'bus.lastUpdated' with your actual model field name
              String lastSeen = _getTimeAgo(bus.lastUpdate);

                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(25),
                      topRight: Radius.circular(25),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              bus.routeName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ),
                          if (!isLoading) _liveBadge(),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${bus.busNumber} • Towards ${bus.destination}",
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 14,
                        ),
                      ),
                      // --- NEW TIMESTAMP SECTION ---
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.history, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "Last updated: $lastSeen",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      // ----------------------------
                      const Divider(height: 30),
                      if (isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Expanded(child: _infoColumn(Icons.access_time, "ETA", eta)),
                              Expanded(
                                child: _infoColumn(
                                  status == "Approaching"
                                      ? Icons.check_circle
                                      : Icons.warning_amber_rounded,
                                  "Status",
                                  status,
                                  color: status == "Approaching" ? Colors.green : Colors.orange,
                                ),
                              ),
                              Expanded(child: _infoColumn(Icons.speed, "Speed", "${bus.speed.toInt()} km/h")),
                            ],
                          ),
                        ),
                      const SizedBox(height: 25),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            padding: const EdgeInsets.all(15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Close",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<Map<String, String>> _fetchAndDraw(BusTrip bus, LatLng targetPos) async {
    Position userPos = await Geolocator.getCurrentPosition();
    LatLng userLatLng = LatLng(userPos.latitude, userPos.longitude);

    var routeInfo = await _getRouteData(bus, userLatLng, targetPos);

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(bus.location.latitude, bus.location.longitude),
        destination: PointLatLng(targetPos.latitude, targetPos.longitude),
        mode: TravelMode.driving,
      ),
    );

    if (mounted) {
      setState(() {
        if (result.points.isNotEmpty) {
          const polylineId = PolylineId("route_line");
          _polylines[polylineId] = Polyline(
            polylineId: polylineId,
            points: result.points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
            color: primaryBlue.withOpacity(0.7),
            width: 5,
            jointType: JointType.round,
          );
        }

        const markerId = MarkerId("destination_marker");
        _destinationMarkers[markerId] = Marker(
          markerId: markerId,
          position: targetPos,
          infoWindow: InfoWindow(title: bus.destination),
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
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: const Text(
        "LIVE",
        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10),
      ),
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
            stream: FirebaseFirestore.instance
                .collection('active_trips')
                .where('status', isEqualTo: 'live')
                .snapshots(),
            builder: (context, snapshot) {
              Set<Marker> markers = {};

              if (snapshot.hasData) {
                final now = DateTime.now();
                
                for (var doc in snapshot.data!.docs) {
                  BusTrip bus = BusTrip.fromFirestore(doc);
                  // --- NEW: Strategy B Inactivity Check ---
    if (bus.lastUpdate != null) {
      final diff = now.difference(bus.lastUpdate!.toDate());
      
      // If the bus hasn't updated in 10 minutes or more
      if (diff.inMinutes >= 10) {
        // 1. Silently update the database so other passengers don't see it either
        FirebaseFirestore.instance
            .collection('active_trips')
            .doc(doc.id)
            .update({'status': 'inactive'});
            
        // 2. Skip adding this marker to the map
        continue; 
      }
    }

                  if (_selectedRoute != null) {
                    if (!bus.routeName.contains(_selectedRoute!) &&
                        !bus.busNumber.contains(_selectedRoute!)) {
                      continue;
                    }
                  }

                  String searchDest = _destinationController.text.toLowerCase().trim();
                  if (searchDest.isNotEmpty) {
                    List<String> stops = bus.citiesOnRoute;
                    String currentStop = bus.currentCity.toLowerCase();

                    int busIndex = stops.indexWhere((s) => s.toLowerCase() == currentStop);
                    int destIndex = stops.indexWhere((s) => s.toLowerCase().contains(searchDest));

                    if (destIndex == -1 || destIndex <= busIndex) {
                      continue;
                    }
                  }

                  markers.add(
                    Marker(
                      markerId: MarkerId(bus.id),
                      position: bus.location,
                      rotation: bus.heading,
                      anchor: const Offset(0.5, 0.5),
                      icon: busIcon ?? BitmapDescriptor.defaultMarker,
                      onTap: () => _showBusDetails(bus),
                    ),
                  );
                }
              }

              markers.addAll(_destinationMarkers.values);

              return GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _defaultLocation,
                  zoom: _currentZoom,
                ),
                onMapCreated: (c) => mapController = c,
                markers: markers,
                polylines: Set<Polyline>.of(_polylines.values),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onCameraMove: (position) {
                  // Only reload icons if zoom integer changes significantly
                  if (position.zoom.round() != _currentZoom.round()) {
                    _currentZoom = position.zoom;
                    _updateBusIcon(_currentZoom);
                  }
                },
                onTap: (_) => setState(() {
                  _polylines.clear();
                  _destinationMarkers.clear();
                }),
              );
            },
          ),
          Positioned(
            top: 16,
            right: 16,
            child: FloatingActionButton.extended(
              heroTag: "filterBtn",
              onPressed: _showFilterSheet,
              backgroundColor: primaryBlue,
              icon: const Icon(Icons.filter_list, color: Colors.white),
              label: const Text("Filter", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
          if (_isLocating) _loader(),
          Positioned(
            bottom: 110,
            right: 16,
            child: FloatingActionButton(
              heroTag: "locateBtn",
              backgroundColor: primaryBlue,
              onPressed: _initLocationSequence,
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: _buildBlueFooter()),
        ],
      ),
    );
  }

  Widget _loader() => Container(
    color: Colors.white.withOpacity(0.7),
    child: const Center(child: CircularProgressIndicator()),
  );

  Widget _appBarTitle() => Row(
    children: [
      Image.asset('assets/white.png', height: 50, errorBuilder: (c,e,s) => const Icon(Icons.bus_alert, color: Colors.white)),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bus Lanka', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          Text('Hi, Passenger', style: TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    ],
  );

  Widget _buildBlueFooter() => Container(
    color: primaryBlue,
    padding: const EdgeInsets.symmetric(vertical: 15),
    child: SafeArea(
      top: false,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          /// CONTACT PAGE
          _footerNavButton("Contact Us", Icons.contact_support_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactUsPage()),
            );
          }),

          /// FEEDBACK PAGE
          _footerNavButton("Feedback", Icons.feedback_outlined, () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FeedbackPage()),
            );
          }),
        ],
      ),
    ),
  );


  Widget _footerNavButton(String t, IconData i, VoidCallback onTap) => InkWell(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(i, color: Colors.white),
        Text(t, style: const TextStyle(color: Colors.white, fontSize: 10)),
      ],
    ),
  );

  Widget _logoutButton(BuildContext context) => IconButton(
    icon: const Icon(Icons.logout, color: Colors.white),
    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SelectRolePage())),
  );

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                top: 25, left: 20, right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Search Buses", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryBlue)),
                      IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) {
                      setState(() { _polylines.clear(); _destinationMarkers.clear(); });
                      Navigator.pop(context);
                    },
                    decoration: InputDecoration(
                      hintText: "Where are you going?",
                      prefixIcon: const Icon(Icons.location_on, color: primaryBlue),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text("Select Route Number", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('active_trips').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const LinearProgressIndicator();
                      Set<String> routeNumbers = {};
                      for (var doc in snapshot.data!.docs) {
                        String fullRoute = doc['route_name'] ?? "";
                        if (fullRoute.isNotEmpty) routeNumbers.add(fullRoute.split(' ')[0]);
                      }
                      return Wrap(
                        spacing: 10,
                        children: routeNumbers.map((number) {
                          bool isSelected = _selectedRoute == number;
                          return ChoiceChip(
                            label: Text(number),
                            selected: isSelected,
                            selectedColor: primaryBlue,
                            labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
                            onSelected: (selected) {
                              setModalState(() => _selectedRoute = selected ? number : null);
                            },
                          );
                        }).toList(),
                      );
                    },
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.search, color: Colors.white),
                      label: const Text("Search Now", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        setState(() { _polylines.clear(); _destinationMarkers.clear(); });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  if (_selectedRoute != null || _destinationController.text.isNotEmpty)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setModalState(() { _selectedRoute = null; _destinationController.clear(); });
                          setState(() { _polylines.clear(); _destinationMarkers.clear(); });
                        },
                        child: const Text("Clear All Filters", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}