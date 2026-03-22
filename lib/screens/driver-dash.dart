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

  bool _isTripLive = false;
  bool _isLocating = true;
  String? _assignedBusNumber;
  String? _actualDocId;
  Map<String, dynamic>? _busData;
  Map<String, dynamic>? _originalBusData;

  final Map<String, LatLng> _routeCityCoordinates = {};

  // default location set to Colombo
  LatLng _currentPos = const LatLng(6.9271, 79.8612);
  double _heading = 0.0;
  BitmapDescriptor? busIcon;

  double _currentZoom = 14.0;

  final Map<PolylineId, Polyline> _polylines = {};
  final Map<MarkerId, Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    polylinePoints = PolylinePoints(apiKey: googleApiKey);
    _updateBusIcon(_currentZoom);
    _fetchDriverData();
    _initLocationSequence();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  //change bus icon size according to zoom
  Future<void> _updateBusIcon(double zoom) async {
    double baseWidth;

    if (zoom >= 16) {
      baseWidth = 45.0;
    } else if (zoom >= 14) {
      baseWidth = 35.0;
    } else if (zoom >= 12) {
      baseWidth = 25.0;
    } else {
      baseWidth = 15.0;
    }

    final newIcon = await BitmapDescriptor.asset(
      ImageConfiguration(size: Size(baseWidth, baseWidth * 2)),
      'assets/bus_marker.png',
    );

    if (mounted) {
      setState(() {
        busIcon = newIcon;
        _updateBusMarker();
      });
    }
  }

  //get current location and move the camera there
  Future<void> _initLocationSequence() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPos = LatLng(position.latitude, position.longitude);

      if (mounted) {
        setState(() => _isLocating = false);
        mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_currentPos, _currentZoom),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  //get driver and assigned bus details
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

            // prevents unnecessary updates
            bool wasLive = _isTripLive;
            String previousCity = _busData?['current_city'] ?? "";
            String newCity = doc.data()['current_city'] ?? "";

            setState(() {
              _busData = doc.data();
              _actualDocId = doc.id;
              _isTripLive = statusIsLive;
              _originalBusData ??= Map.from(doc.data());
            });

            if (_isTripLive) {
              if (!wasLive) {
                // Trip started
                _startLocationUpdates();
                _drawRouteToDestination();
              } else if (previousCity != newCity) {
                // Moved to a new city
                _drawRouteToDestination();
              }
            } else if (!_isTripLive && wasLive) {
              _stopTripCleanup();
            }
          }
        });
  }

  //ask driver which direction
  void _showDirectionDialog() {
    if (_originalBusData == null) return;
    String terminalA = _originalBusData!['origin'] ?? "Terminal A";
    String terminalB = _originalBusData!['destination'] ?? "Terminal B";

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Select Destination",
          style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold),
        ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _processStartTrip(isInbound: true);
                  },
                  child: Text(
                    "TO: $terminalA",
                    style: const TextStyle(
                      color: primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _processStartTrip(isInbound: false);
                  },
                  child: Text(
                    "TO: $terminalB",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // start trip with selected direction
  Future<void> _processStartTrip({required bool isInbound}) async {
    final source = _originalBusData ?? _busData;
    if (source == null || _actualDocId == null) return;

    String finalDest = isInbound ? source['origin'] : source['destination'];
    String finalOrigin = isInbound ? source['destination'] : source['origin'];

    // flipped logic for direction
    String directionStr = isInbound ? "outbound" : "inbound";

    List<dynamic> stops = List.from(source['cities_on_route'] ?? []);
    if (isInbound) stops = stops.reversed.toList();

    await FirebaseFirestore.instance
        .collection('active_trips')
        .doc(_actualDocId)
        .update({
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

  // store route data locally
  Future<void> _cacheRouteCoordinates(List<dynamic> stops) async {
    try {
      _routeCityCoordinates.clear();
      var termSnap = await FirebaseFirestore.instance
          .collection('terminals')
          .get();

      for (var doc in termSnap.docs) {
        String dbName = doc.get('name');

        var exactRouteName = stops.firstWhere(
          (s) =>
              s.toString().toLowerCase().trim() == dbName.toLowerCase().trim(),
          orElse: () => "",
        );

        if (exactRouteName.toString().isNotEmpty) {
          GeoPoint gp = doc.get('location');
          _routeCityCoordinates[exactRouteName.toString()] = LatLng(
            gp.latitude,
            gp.longitude,
          );
        }
      }
    } catch (e) {
      debugPrint("Caching failed: $e");
    }
  }

  //check if bus reached the next city and update
  void _checkAndUpdateCity(Position pos) {
    if (_routeCityCoordinates.isEmpty || _busData == null) return;

    String? detectedCity;
    double minDistance = 500.0;

    _routeCityCoordinates.forEach((cityName, cityLatLng) {
      double distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        cityLatLng.latitude,
        cityLatLng.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        detectedCity = cityName;
      }
    });

    if (detectedCity != null && detectedCity != _busData?['current_city']) {
      List<dynamic> routeCities = _busData?['cities_on_route'] ?? [];

      int currentIndex = routeCities.indexWhere(
        (c) => c.toString() == _busData?['current_city'],
      );
      int detectedIndex = routeCities.indexWhere(
        (c) => c.toString() == detectedCity,
      );

      if (detectedIndex > currentIndex || currentIndex == -1) {
        FirebaseFirestore.instance
            .collection('active_trips')
            .doc(_actualDocId)
            .update({
              'current_city': detectedCity,
              'last_update': FieldValue.serverTimestamp(),
            });

        setState(() {
          _busData?['current_city'] = detectedCity;
        });
      }
    }
  }

  //start and end trip
  Future<void> _toggleTrip() async {
    if (_actualDocId == null) return;
    if (_isTripLive) {
      await FirebaseFirestore.instance
          .collection('active_trips')
          .doc(_actualDocId)
          .update({
            'status': 'inactive',
            'last_update': FieldValue.serverTimestamp(),
          });
      _stopTripCleanup();
    } else {
      _showDirectionDialog();
    }
  }

  //update marker location
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

  //gps updates to Firestore database
  void _startLocationUpdates() {
    _positionStream?.cancel();
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((pos) {
          if (_actualDocId != null && _isTripLive) {
            if (mounted) {
              setState(() {
                _currentPos = LatLng(pos.latitude, pos.longitude);
                _heading = pos.heading;
                _updateBusMarker();
              });
            }

            FirebaseFirestore.instance
                .collection('active_trips')
                .doc(_actualDocId)
                .update({
                  'location': GeoPoint(pos.latitude, pos.longitude),
                  'heading': pos.heading,
                  'speed': (pos.speed * 3.6).round(),
                  'last_update': FieldValue.serverTimestamp(),
                });

            _checkAndUpdateCity(pos);
          }
        });
  }

  //stop trip and cleanup local data
  void _stopTripCleanup() {
    _positionStream?.cancel();
    _routeCityCoordinates.clear();
    if (mounted) {
      setState(() {
        _polylines.clear();
        _markers.clear();
      });
    }
  }

  //draw route on destination change
  Future<void> _drawRouteToDestination() async {
    if (_busData == null || _busData!['destination'] == null) return;
    try {
      var termQuery = await FirebaseFirestore.instance
          .collection('terminals')
          .where('name', isEqualTo: _busData!['destination'])
          .limit(1)
          .get();

      if (termQuery.docs.isNotEmpty) {
        GeoPoint gp = termQuery.docs.first.get('location');
        LatLng dest = LatLng(gp.latitude, gp.longitude);

        // --- NEW: Slicing the waypoints dynamically ---
        List<PolylineWayPoint> routeWaypoints = [];
        List<dynamic> routeCities = _busData!['cities_on_route'] ?? [];

        int currentIndex = routeCities.indexWhere(
          (c) =>
              c.toString().toLowerCase() ==
              (_busData!['current_city'] ?? "").toString().toLowerCase(),
        );
        int targetIndex = routeCities.indexWhere(
          (c) =>
              c.toString().toLowerCase() ==
              _busData!['destination'].toString().toLowerCase(),
        );

        if (currentIndex == -1) currentIndex = 0;
        if (targetIndex == -1) targetIndex = routeCities.length - 1;

        if (currentIndex < targetIndex) {
          List<dynamic> remainingStops = routeCities.sublist(
            currentIndex + 1,
            targetIndex,
          );

          for (var city in remainingStops) {
            String cityName = city.toString();
            String query = cityName.toLowerCase().contains("bus")
                ? cityName
                : "$cityName Bus Stop";
            routeWaypoints.add(PolylineWayPoint(location: "$query, Sri Lanka"));
          }
        }
        // end of waypoint slicing logic

        PolylineResult res = await polylinePoints.getRouteBetweenCoordinates(
          request: PolylineRequest(
            origin: PointLatLng(_currentPos.latitude, _currentPos.longitude),
            destination: PointLatLng(dest.latitude, dest.longitude),
            mode: TravelMode.driving,
            wayPoints: routeWaypoints, // adding the sliced waypoints
          ),
        );

        if (res.points.isNotEmpty && mounted && _isTripLive) {
          setState(() {
            _polylines[const PolylineId("path")] = Polyline(
              polylineId: const PolylineId("path"),
              points: res.points
                  .map((p) => LatLng(p.latitude, p.longitude))
                  .toList(),
              color: primaryBlue.withOpacity(0.5),
              width: 5,
            );
            _markers[const MarkerId("dest")] = Marker(
              markerId: const MarkerId("dest"),
              position: dest,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed,
              ),
            );
          });
        }
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // app bar
  Widget _appBarTitle() {
    String username = widget.userEmail.split('@')[0];
    if (username.isNotEmpty)
      username = username[0].toUpperCase() + username.substring(1);

    return Row(
      children: [
        Image.asset(
          'assets/white.png',
          height: 50,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.bus_alert, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bus Lanka',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Hi, $username',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  // info cards
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
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (c) => const SelectRolePage()),
            ),
          ),
        ],
      ),
      body: _busData == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'BUS NUMBER',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _assignedBusNumber ?? "...",
                            style: const TextStyle(
                              color: primaryBlue,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      _statusBadge(),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _infoCard(
                          "Route",
                          _busData!['route_name'] ?? "N/A",
                          Icons.alt_route,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _infoCard(
                          "Destination",
                          _busData!['destination'] ?? "N/A",
                          Icons.location_on,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  Expanded(
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: _currentPos,
                              zoom: _currentZoom,
                            ),
                            onMapCreated: (c) => mapController = c,
                            markers: Set.of(_markers.values),
                            polylines: Set.of(_polylines.values),
                            myLocationEnabled: true,
                            myLocationButtonEnabled: false,
                            zoomControlsEnabled: false,
                            onCameraMove: (position) {
                              if (position.zoom.round() !=
                                  _currentZoom.round()) {
                                _currentZoom = position.zoom;
                                _updateBusIcon(_currentZoom);
                              }
                            },
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
                            child: const Icon(
                              Icons.my_location,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        if (_isLocating)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 15),

                  ElevatedButton(
                    onPressed: _toggleTrip,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isTripLive ? inactiveRed : activeGreen,
                      minimumSize: const Size(double.infinity, 60),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(
                      _isTripLive ? "END TRIP" : "START TRIP",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  //feedback
  Widget _statusBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: _isTripLive
          ? activeGreen.withOpacity(0.1)
          : inactiveRed.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      _isTripLive ? "● LIVE" : "○ INACTIVE",
      style: TextStyle(
        color: _isTripLive ? Colors.green.shade700 : inactiveRed,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );

  Widget _infoCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: primaryBlue),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
