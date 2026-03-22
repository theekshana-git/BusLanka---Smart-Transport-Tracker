import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math'; // Added for slight speed variation
import 'package:http/http.dart' as http;
import 'role.dart';
import 'package:buslanka/models/bus_trip.dart';
import 'package:buslanka/models/terminal.dart';
import 'package:buslanka/screens/contact-us.dart';
import 'package:buslanka/screens/feedback.dart';

// Global variables for filtering and search
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

  double _currentZoom = 14.0;
  Position? _currentUserPos; // Cached to prevent spamming GPS in demo mode

  final Map<PolylineId, Polyline> _polylines = {};
  final Map<MarkerId, Marker> _destinationMarkers = {};
  late PolylinePoints polylinePoints;

  // Track distance trend for the dynamic status logic
  double? _lastDistanceToUser;

  // variables for the demo simulation(VIVA)
  Timer? _demoTimer;
  int _demoIndex = 0;
  LatLng? _demoBusPos;
  double _demoBusHeading = 0.0;
  bool _isDemoActive = false;
  List<LatLng> _demoPath = [];
  BusTrip? _lastTappedBus; // Keep track of the bus we are simulating

  // Live UI Notifiers for the popup overlay
  final ValueNotifier<String> _demoEtaNotifier = ValueNotifier("--");
  final ValueNotifier<String> _demoStatusNotifier = ValueNotifier("Status");
  final ValueNotifier<String> _demoSpeedNotifier = ValueNotifier("0 km/h");
  // ==========================================

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

  // dynamic status logic based on distance, bearing, and trend
  String _getDynamicStatus(LatLng busPos, double busHeading, LatLng userPos) {
    // Calculate Current Distance
    double currentDistance = Geolocator.distanceBetween(
      busPos.latitude,
      busPos.longitude,
      userPos.latitude,
      userPos.longitude,
    );

    String status = "Away";

    // Geofencing: Over 3km away
    if (currentDistance > 3000) {
      status = "Away";
    }
    // Proximity: Less than 50 meters
    else if (currentDistance < 50) {
      status = "Arrived";
    } else {
      // Calculate Bearing & Cone of Sight
      double bearingToUser = Geolocator.bearingBetween(
        busPos.latitude,
        busPos.longitude,
        userPos.latitude,
        userPos.longitude,
      );

      double angleDiff = (busHeading - bearingToUser).abs();
      if (angleDiff > 180) {
        angleDiff = 360 - angleDiff;
      }

      // 90-degree vision cone (45 degrees either side of the bus heading)
      bool isFacingUser = angleDiff <= 45;

      // Distance Trend Logic
      bool isGettingCloser = true;
      if (_lastDistanceToUser != null) {
        // 5m buffer prevents GPS jitter from falsely triggering "Passed"
        if (currentDistance > _lastDistanceToUser! + 5) {
          isGettingCloser = false;
        }
      }

      // Final Status Determination
      if (isGettingCloser && isFacingUser) {
        status = "Approaching";
      } else if (!isGettingCloser && currentDistance < 1000) {
        status = "Bus Passed";
      } else {
        status = "Away";
      }
    }

    // Update trend tracker for the next cycle
    _lastDistanceToUser = currentDistance;
    return status;
  }
  // end of dynamic status logic

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleApiKey);
    _updateBusIcon(_currentZoom);
    _initLocationSequence();
  }

  @override
  void dispose() {
    _demoTimer?.cancel();
    _demoEtaNotifier.dispose();
    _demoStatusNotifier.dispose();
    _demoSpeedNotifier.dispose();
    super.dispose();
  }

  // updated demo engine
  void _toggleDemo() {
    if (_isDemoActive) {
      _demoTimer?.cancel();
      setState(() {
        _isDemoActive = false;
        _demoBusPos = null;
      });
    } else {
      if (_polylines.isEmpty ||
          _polylines.values.first.points.isEmpty ||
          _lastTappedBus == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please tap on a real bus marker first to load its route!",
            ),
            backgroundColor: primaryBlue,
          ),
        );
        return;
      }

      setState(() {
        _isDemoActive = true;
        _demoPath = _polylines.values.first.points;
        _demoIndex = 0;
        _demoBusPos = _demoPath[_demoIndex];
        _demoBusHeading = 0.0;
      });

      // Updates every 800ms for smooth movement
      _demoTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
        if (!mounted) return;
        setState(() {
          _demoIndex += 1;

          if (_demoIndex >= _demoPath.length - 1) {
            // Bus reached destination
            _demoStatusNotifier.value = "Arrived";
            _demoEtaNotifier.value = "0 mins";
            _demoSpeedNotifier.value = "0 km/h";
            _toggleDemo();
            return;
          }

          LatLng current = _demoPath[_demoIndex];
          LatLng next = _demoPath[_demoIndex + 1];

          _demoBusHeading = Geolocator.bearingBetween(
            current.latitude,
            current.longitude,
            next.latitude,
            next.longitude,
          );
          _demoBusPos = current;

          // --shrink the polyline to create a "moving" effect(VIVA)--
          const polyId = PolylineId("route_line");
          if (_polylines.containsKey(polyId)) {
            _polylines[polyId] = _polylines[polyId]!.copyWith(
              pointsParam: _demoPath.sublist(_demoIndex),
            );
          }

          // --- VIVA: Calculate Local ETA & Speed ---
          double remainingDist = 0;
          for (int i = _demoIndex; i < _demoPath.length - 1; i++) {
            remainingDist += Geolocator.distanceBetween(
              _demoPath[i].latitude,
              _demoPath[i].longitude,
              _demoPath[i + 1].latitude,
              _demoPath[i + 1].longitude,
            );
          }

          int simSpeed = 42 + Random().nextInt(5) - 2;
          _demoSpeedNotifier.value = "$simSpeed km/h";

          int minutes = (remainingDist / (40.0 * 1000 / 60)).ceil();
          _demoEtaNotifier.value = minutes > 0 ? "$minutes mins" : "Now";

          // Calculate Dynamic Status if we have user location
          if (_currentUserPos != null && _demoBusPos != null) {
            LatLng userLatLng = LatLng(
              _currentUserPos!.latitude,
              _currentUserPos!.longitude,
            );
            _demoStatusNotifier.value = _getDynamicStatus(
              _demoBusPos!,
              _demoBusHeading,
              userLatLng,
            );
          } else {
            _demoStatusNotifier.value = minutes > 0
                ? "Approaching"
                : "Arriving";
          }
        });
      });
    }
  }
  // end of updated demo engine

  Future<void> _updateBusIcon(double zoom) async {
    double baseWidth;
    if (zoom >= 16)
      baseWidth = 45.0;
    else if (zoom >= 14)
      baseWidth = 35.0;
    else if (zoom >= 12)
      baseWidth = 25.0;
    else
      baseWidth = 15.0;

    final newIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(baseWidth, baseWidth * 2)),
      'assets/bus_marker.png',
    );

    if (mounted) setState(() => busIcon = newIcon);
  }

  Future<void> _initLocationSequence() async {
    try {
      Position position = await _determinePosition();
      _currentUserPos = position; // Cache user position
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
      if (permission == LocationPermission.denied)
        return Future.error('Denied');
    }
    return await Geolocator.getCurrentPosition();
  }

  Future<Map<String, String>> _getRouteData(
    BusTrip bus,
    LatLng userLatLng,
    LatLng targetLatLng,
  ) async {
    // utilize the same logic as the dynamic status to provide a more accurate ETA and status in the popup
    String status = _getDynamicStatus(bus.location, bus.heading, userLatLng);
    String eta = "--";

    return {"status": status, "eta": eta};
  }

  // updated bus details popup to support demo mode
  void _showBusDetails(BusTrip bus, {bool isDemoMarker = false}) async {
    // Reset the tracking metric when clicking a new bus to prevent false passing reports
    _lastDistanceToUser = null;

    if (!isDemoMarker) {
      _lastTappedBus = bus;
      setState(() {
        _polylines.clear();
        _destinationMarkers.clear();
      });
    }

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
            if (isDemoMarker) {
              return ValueListenableBuilder<String>(
                valueListenable: _demoEtaNotifier,
                builder: (context, currentEta, _) {
                  //listen to status to trigger color/icon changes
                  return ValueListenableBuilder<String>(
                    valueListenable: _demoStatusNotifier,
                    builder: (context, currentStatus, _) {
                      return _buildBottomSheetContent(
                        bus: bus,
                        isLoading: false,
                        eta: currentEta,
                        status: currentStatus,
                        speed: _demoSpeedNotifier.value,
                        lastSeen: "LIVE (Simulation)",
                      );
                    },
                  );
                },
              );
            }

            return FutureBuilder<Map<String, String>>(
              future: _fetchAndDraw(bus, targetLatLng),
              builder: (context, snapshot) {
                bool isLoading = !snapshot.hasData;
                return _buildBottomSheetContent(
                  bus: bus,
                  isLoading: isLoading,
                  eta: snapshot.data?['eta'] ?? "--",
                  status: snapshot.data?['status'] ?? "Checking...",
                  speed: "${bus.speed.toInt()} km/h",
                  lastSeen: _getTimeAgo(bus.lastUpdate),
                );
              },
            );
          },
        );
      },
    );
  }

  // bottom sheet content builder
  Widget _buildBottomSheetContent({
    required BusTrip bus,
    required bool isLoading,
    required String eta,
    required String status,
    required String speed,
    required String lastSeen,
  }) {
    Color statusColor = Colors.orange;
    IconData statusIcon = Icons.warning_amber_rounded;

    if (status == "Approaching") {
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else if (status == "Arrived") {
      statusColor = Colors.blue;
      statusIcon = Icons.location_on;
    } else if (status == "Bus Passed") {
      statusColor = Colors.red;
      statusIcon = Icons.directions_run;
    }

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
            style: const TextStyle(color: Colors.black54, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.history, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                "Last updated: $lastSeen",
                style: TextStyle(
                  color: lastSeen.contains("LIVE") ? Colors.red : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
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
                      statusIcon,
                      "Status",
                      status,
                      color: statusColor,
                    ),
                  ),
                  Expanded(child: _infoColumn(Icons.speed, "Speed", speed)),
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
  }

  // updated route data fetcher to support demo mode
  Future<Map<String, String>> _fetchAndDraw(
    BusTrip bus,
    LatLng targetPos,
  ) async {
    Position userPos = await Geolocator.getCurrentPosition();
    LatLng userLatLng = LatLng(userPos.latitude, userPos.longitude);

    var routeInfo = await _getRouteData(bus, userLatLng, targetPos);

    List<PolylineWayPoint> routeWaypoints = [];
    int currentIndex = bus.citiesOnRoute.indexWhere(
      (c) => c.toLowerCase() == bus.currentCity.toLowerCase(),
    );
    int targetIndex = bus.citiesOnRoute.indexWhere(
      (c) => c.toLowerCase() == bus.destination.toLowerCase(),
    );

    if (currentIndex == -1) currentIndex = 0;
    if (targetIndex == -1) targetIndex = bus.citiesOnRoute.length - 1;

    if (currentIndex < targetIndex) {
      List<String> remainingStops = bus.citiesOnRoute.sublist(
        currentIndex + 1,
        targetIndex,
      );
      for (String city in remainingStops) {
        String query = city.toLowerCase().contains("bus")
            ? city
            : "$city Bus Stop";
        routeWaypoints.add(PolylineWayPoint(location: "$query, Sri Lanka"));
      }
    }

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      request: PolylineRequest(
        origin: PointLatLng(bus.location.latitude, bus.location.longitude),
        destination: PointLatLng(targetPos.latitude, targetPos.longitude),
        mode: TravelMode.driving,
        wayPoints: routeWaypoints,
      ),
    );

    if (mounted) {
      setState(() {
        if (result.points.isNotEmpty) {
          const polylineId = PolylineId("route_line");
          _polylines[polylineId] = Polyline(
            polylineId: polylineId,
            points: result.points
                .map((p) => LatLng(p.latitude, p.longitude))
                .toList(),
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

  Widget _infoColumn(
    IconData icon,
    String label,
    String value, {
    Color color = primaryBlue,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black45),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          textAlign: TextAlign.center,
        ),
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
        style: TextStyle(
          color: Colors.green,
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
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

                  if (bus.lastUpdate != null) {
                    final diff = now.difference(bus.lastUpdate!.toDate());
                    if (diff.inMinutes >= 10) {
                      FirebaseFirestore.instance
                          .collection('active_trips')
                          .doc(doc.id)
                          .update({'status': 'inactive'});
                      continue;
                    }
                  }

                  if (_selectedRoute != null) {
                    if (!bus.routeName.contains(_selectedRoute!) &&
                        !bus.busNumber.contains(_selectedRoute!))
                      continue;
                  }

                  String searchDest = _destinationController.text
                      .toLowerCase()
                      .trim();
                  if (searchDest.isNotEmpty) {
                    List<String> stops = bus.citiesOnRoute;
                    String currentStop = bus.currentCity.toLowerCase();
                    int busIndex = stops.indexWhere(
                      (s) => s.toLowerCase() == currentStop,
                    );
                    int destIndex = stops.indexWhere(
                      (s) => s.toLowerCase().contains(searchDest),
                    );

                    if (destIndex == -1 || destIndex < busIndex) continue;
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

              // --- VIVA : Add the Fake Bus and override its onTap ---
              if (_isDemoActive &&
                  _demoBusPos != null &&
                  _lastTappedBus != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId("viva_demo_bus"),
                    position: _demoBusPos!,
                    rotation: _demoBusHeading,
                    anchor: const Offset(0.5, 0.5),
                    icon: busIcon ?? BitmapDescriptor.defaultMarker,
                    zIndex: 100,
                    onTap: () =>
                        _showBusDetails(_lastTappedBus!, isDemoMarker: true),
                  ),
                );
              }

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
                  if (position.zoom.round() != _currentZoom.round()) {
                    _currentZoom = position.zoom;
                    _updateBusIcon(_currentZoom);
                  }
                },
                onTap: (_) => setState(() {
                  _polylines.clear();
                  _destinationMarkers.clear();
                  if (_isDemoActive) _toggleDemo();
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
              label: const Text(
                "Filter",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          if (_isLocating) _loader(),

          Positioned(
            bottom: 170,
            right: 16,
            child: FloatingActionButton(
              heroTag: "demoPlayBtn",
              backgroundColor: _isDemoActive ? Colors.red : primaryBlue,
              onPressed: _toggleDemo,
              tooltip: "Play Demo Bus",
              child: Icon(
                _isDemoActive ? Icons.stop : Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

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
      Image.asset(
        'assets/white.png',
        height: 50,
        errorBuilder: (c, e, s) =>
            const Icon(Icons.bus_alert, color: Colors.white),
      ),
      const SizedBox(width: 12),
      const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bus Lanka',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            'Hi, Passenger',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
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
          _footerNavButton(
            "Contact Us",
            Icons.contact_support_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ContactUsPage()),
            ),
          ),
          _footerNavButton(
            "Feedback",
            Icons.feedback_outlined,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FeedbackPage()),
            ),
          ),
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
    onPressed: () => Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (c) => const SelectRolePage()),
    ),
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
                top: 25,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Search Buses",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _destinationController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (val) {
                      setState(() {
                        _polylines.clear();
                        _destinationMarkers.clear();
                      });
                      Navigator.pop(context);
                    },
                    decoration: InputDecoration(
                      hintText: "Where are you going?",
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: primaryBlue,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Select Route Number",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('active_trips')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const LinearProgressIndicator();
                      Set<String> routeNumbers = {};
                      for (var doc in snapshot.data!.docs) {
                        String fullRoute = doc['route_name'] ?? "";
                        if (fullRoute.isNotEmpty)
                          routeNumbers.add(fullRoute.split(' ')[0]);
                      }
                      return Wrap(
                        spacing: 10,
                        children: routeNumbers.map((number) {
                          bool isSelected = _selectedRoute == number;
                          return ChoiceChip(
                            label: Text(number),
                            selected: isSelected,
                            selectedColor: primaryBlue,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : Colors.black,
                            ),
                            onSelected: (selected) {
                              setModalState(
                                () => _selectedRoute = selected ? number : null,
                              );
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
                      label: const Text(
                        "Search Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _polylines.clear();
                          _destinationMarkers.clear();
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ),
                  if (_selectedRoute != null ||
                      _destinationController.text.isNotEmpty)
                    Center(
                      child: TextButton(
                        onPressed: () {
                          setModalState(() {
                            _selectedRoute = null;
                            _destinationController.clear();
                          });
                          setState(() {
                            _polylines.clear();
                            _destinationMarkers.clear();
                          });
                        },
                        child: const Text(
                          "Clear All Filters",
                          style: TextStyle(color: Colors.red),
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
  }
}
