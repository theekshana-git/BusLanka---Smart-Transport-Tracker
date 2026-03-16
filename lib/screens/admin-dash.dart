import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role.dart'; 

class AdminDashboard extends StatefulWidget {
  final String adminEmail;
  const AdminDashboard({Key? key, required this.adminEmail}) : super(key: key);

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  static const Color primaryBlue = Color(0xFF112D75);
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100], 
      appBar: _buildAppBar(),
      body: _buildBodyContent(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    String username = widget.adminEmail.split('@')[0];
    if (username.isNotEmpty) username = username[0].toUpperCase() + username.substring(1);

    return AppBar(
      backgroundColor: primaryBlue,
      elevation: 0,
      toolbarHeight: 70,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          Image.asset('assets/white.png', height: 40, errorBuilder: (c, e, s) => const Icon(Icons.directions_bus, color: Colors.white, size: 36)),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Admin Panel', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Hi, $username', style: const TextStyle(fontSize: 13, color: Colors.white70)),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout, color: Colors.white, size: 26),
          tooltip: 'Logout',
          onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const SelectRolePage())),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: Colors.grey.shade400,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'Overview'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus_rounded), label: 'Buses'),
          BottomNavigationBarItem(icon: Icon(Icons.map_rounded), label: 'Routes'),
          BottomNavigationBarItem(icon: Icon(Icons.badge_rounded), label: 'Drivers'),
          BottomNavigationBarItem(icon: Icon(Icons.forum_rounded), label: 'Feedback'),
        ],
      ),
    );
  }

  Widget _buildBodyContent() {
    switch (_selectedIndex) {
      case 0: return const OverviewView();
      case 1: return const BusesView();
      case 2: return const RoutesView();
      case 3: return const DriversView();
      case 4: return const FeedbackView();
      default: return const OverviewView();
    }
  }
}

// ==========================================
// 1. OVERVIEW VIEW
// ==========================================
class OverviewView extends StatelessWidget {
  const OverviewView({Key? key}) : super(key: key);
  static const Color primaryBlue = Color(0xFF112D75);
  static const Color activeGreen = Color(0xFF79E780);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("System Metrics", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildMetricCard('Total Buses', Icons.directions_bus, 'active_trips', null),
              _buildMetricCard('Active Now', Icons.sensors, 'active_trips', 'status', isEqualTo: 'live', highlightColor: activeGreen),
              _buildMetricCard('Total Routes', Icons.route, 'routes', null),
              _buildMetricCard('Total Drivers', Icons.people, 'users', 'role', isEqualTo: 'driver'),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Recent Bus Activity", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
          const SizedBox(height: 12),
          _buildRecentActivityStream(),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, IconData icon, String collection, String? filterField, {String? isEqualTo, Color? highlightColor}) {
    Query query = FirebaseFirestore.instance.collection(collection);
    if (filterField != null && isEqualTo != null) {
      query = query.where(filterField, isEqualTo: isEqualTo);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        String count = snapshot.hasData ? snapshot.data!.docs.length.toString() : "...";
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
            border: highlightColor != null ? Border.all(color: highlightColor.withOpacity(0.5), width: 2) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: highlightColor ?? primaryBlue.withOpacity(0.6), size: 24),
                  if (highlightColor != null) CircleAvatar(radius: 4, backgroundColor: highlightColor),
                ],
              ),
              const Spacer(),
              Text(count, style: TextStyle(color: primaryBlue, fontSize: 26, fontWeight: FontWeight.bold)),
              Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityStream() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('active_trips').orderBy('last_update', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        if (snapshot.data!.docs.isEmpty) return const Text("No recent activity.", style: TextStyle(color: Colors.grey));
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (c, i) => Divider(height: 1, color: Colors.grey.shade200),
            itemBuilder: (context, index) {
              var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              bool isLive = data['status'] == 'live';
              String timeStr = _formatTimeAgo(data['last_update'] as Timestamp?);
              
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLive ? activeGreen.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  child: Icon(isLive ? Icons.sensors : Icons.bus_alert, color: isLive ? Colors.green.shade700 : Colors.red.shade700, size: 18),
                ),
                title: Text('${data['bus_number'] ?? 'Unknown Bus'} is ${isLive ? 'Live' : 'Inactive'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('Route: ${data['route_number'] ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                trailing: Text(timeStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              );
            },
          ),
        );
      },
    );
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Just now";
    Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }
}

// ==========================================
// 2. BUSES VIEW 
// ==========================================
class BusesView extends StatelessWidget {
  const BusesView({Key? key}) : super(key: key);
  static const Color primaryBlue = Color(0xFF112D75);
  static const Color activeGreen = Color(0xFF79E780);

  void _showAddBusDialog(BuildContext context) {
    final busNoController = TextEditingController();
    String? selectedRouteId;
    Map<String, dynamic>? selectedRouteData;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Add New Bus', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: busNoController,
                    decoration: InputDecoration(
                      labelText: 'Bus Number (e.g. NB-1122)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true, fillColor: Colors.grey.shade50
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('routes').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const CircularProgressIndicator();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(12), color: Colors.grey.shade50),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: const Text("Select Route"),
                            value: selectedRouteId,
                            items: snapshot.data!.docs.map((doc) {
                              var data = doc.data() as Map<String, dynamic>;
                              return DropdownMenuItem<String>(
                                value: doc.id,
                                child: Text(data['route_name'] ?? 'Unknown'),
                                onTap: () => selectedRouteData = data,
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => selectedRouteId = val),
                          ),
                        ),
                      );
                    },
                  )
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: () {
                    if (busNoController.text.isNotEmpty && selectedRouteData != null) {
                      FirebaseFirestore.instance.collection('active_trips').add({
                        'bus_number': busNoController.text.trim(),
                        'route_name': selectedRouteData!['route_name'],
                        'route_number': selectedRouteData!['route_number'],
                        'origin': selectedRouteData!['origin'],
                        'destination': selectedRouteData!['destination'],
                        'cities_on_route': selectedRouteData!['cities_on_route'],
                        'stops_data': selectedRouteData!['stops_data'] ?? [], // Copies location data too
                        'current_city': selectedRouteData!['origin'],
                        'direction': 'inbound',
                        'status': 'inactive',
                        'speed': 0,
                        'heading': 0,
                        'location': const GeoPoint(6.9271, 79.8612),
                        'last_update': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Add Bus', style: TextStyle(color: Colors.white)),
                )
              ],
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Fleet Management", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text("Add Bus", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => _showAddBusDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('active_trips').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No buses found."));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  bool isLive = data['status'] == 'live';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.directions_bus, color: primaryBlue, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(data['bus_number'] ?? 'Unknown', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => FirebaseFirestore.instance.collection('active_trips').doc(doc.id).update({
                                  'status': isLive ? 'inactive' : 'live', 'speed': 0, 'last_update': FieldValue.serverTimestamp()
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(color: isLive ? activeGreen : Colors.red, borderRadius: BorderRadius.circular(20)),
                                  child: Row(
                                    children: [
                                      Icon(isLive ? Icons.wifi_tethering : Icons.wifi_off, color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(isLive ? 'LIVE' : 'INACTIVE', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                          Row(
                            children: [
                              const Icon(Icons.route, color: Colors.grey, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(data['route_name'] ?? 'No Route', style: const TextStyle(color: Colors.black87, fontSize: 14))),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () => FirebaseFirestore.instance.collection('active_trips').doc(doc.id).delete(),
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 3. ROUTES VIEW (WITH TERMINAL GEOCODING)
// ==========================================
class RoutesView extends StatelessWidget {
  const RoutesView({Key? key}) : super(key: key);
  static const Color primaryBlue = Color(0xFF112D75);

  void _showAddRouteDialog(BuildContext context) {
    final noCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final originCtrl = TextEditingController();
    final destCtrl = TextEditingController();
    final citiesCtrl = TextEditingController(); 

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Add Master Route', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTextField(noCtrl, 'Route Number (e.g. 170)'),
                  const SizedBox(height: 12),
                  _buildTextField(nameCtrl, 'Full Name (e.g. 170 - Athurugiriya)'),
                  const SizedBox(height: 12),
                  _buildTextField(originCtrl, 'Origin City'),
                  const SizedBox(height: 12),
                  _buildTextField(destCtrl, 'Destination City'),
                  const SizedBox(height: 12),
                  _buildTextField(citiesCtrl, 'Stops (comma separated)'),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context), 
                child: const Text('Cancel', style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                onPressed: isSaving ? null : () async {
                  setState(() => isSaving = true);
                  
                  List<String> cities = citiesCtrl.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
                  
                  if (noCtrl.text.isNotEmpty && nameCtrl.text.isNotEmpty) {
                    List<Map<String, dynamic>> stopsData = [];
                    
                    // Fetch locations automatically from the terminals collection!
                    for(String city in cities) {
                      var termQuery = await FirebaseFirestore.instance.collection('terminals').where('name', isEqualTo: city).limit(1).get();
                      
                      if(termQuery.docs.isNotEmpty) {
                        stopsData.add({
                          'name': city,
                          'location': termQuery.docs.first.get('location') // Gets the GeoPoint
                        });
                      } else {
                        // If admin typed a city not in terminals, just add the name without a location
                        stopsData.add({
                          'name': city,
                        });
                      }
                    }

                    await FirebaseFirestore.instance.collection('routes').add({
                      'route_number': noCtrl.text.trim(),
                      'route_name': nameCtrl.text.trim(),
                      'origin': originCtrl.text.trim(),
                      'destination': destCtrl.text.trim(),
                      'cities_on_route': cities, // Keeps the regular string array for compatibility
                      'stops_data': stopsData, // Saves the newly fetched terminal locations
                    });
                    Navigator.pop(context);
                  } else {
                    setState(() => isSaving = false);
                  }
                },
                child: isSaving 
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Route', style: TextStyle(color: Colors.white)),
              )
            ],
          );
        }
      )
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Route Master List", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18, color: Colors.white),
                label: const Text("New Route", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => _showAddRouteDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('routes').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No routes configured."));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var doc = snapshot.data!.docs[index];
                  var data = doc.data() as Map<String, dynamic>;
                  List<dynamic> cities = data['cities_on_route'] ?? [];
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 50, width: 50,
                          decoration: BoxDecoration(color: primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(data['route_number'] ?? '-', style: const TextStyle(color: primaryBlue, fontWeight: FontWeight.bold, fontSize: 16))),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['route_name'] ?? 'Unknown Route', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text('${data['origin']}  ➔  ${data['destination']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Text('${cities.length}', style: const TextStyle(color: primaryBlue, fontSize: 18, fontWeight: FontWeight.bold)),
                            const Text('Stops', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. DRIVERS VIEW 
// ==========================================
class DriversView extends StatelessWidget {
  const DriversView({Key? key}) : super(key: key);
  static const Color primaryBlue = Color(0xFF112D75);

  void _showAddDriverDialog(BuildContext context) {
    final emailCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    final busCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Driver', style: TextStyle(color: primaryBlue, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                color: Colors.orange.shade50,
                child: const Text("Note: Firebase Auth account must be created manually.", style: TextStyle(fontSize: 11, color: Colors.deepOrange)),
              ),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: InputDecoration(labelText: 'Email Address', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: contactCtrl, decoration: InputDecoration(labelText: 'Contact Number', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 12),
              TextField(controller: busCtrl, decoration: InputDecoration(labelText: 'Assigned Bus (e.g. NB-9988)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (emailCtrl.text.isNotEmpty) {
                FirebaseFirestore.instance.collection('users').add({
                  'email': emailCtrl.text.trim(),
                  'username': nameCtrl.text.trim(),
                  'contact': contactCtrl.text.trim(),
                  'assigned_bus': busCtrl.text.trim(),
                  'role': 'driver',
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Save Driver', style: TextStyle(color: Colors.white)),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Personnel", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryBlue)),
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
                label: const Text("Add Driver", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(backgroundColor: primaryBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                onPressed: () => _showAddDriverDialog(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'driver').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No drivers found."));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(radius: 24, backgroundColor: primaryBlue.withOpacity(0.1), child: const Icon(Icons.person, color: primaryBlue, size: 28)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['username'] ?? 'Unknown Driver', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(data['email'] ?? 'No email', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.directions_bus, size: 14, color: primaryBlue),
                                  const SizedBox(width: 4),
                                  Text(data['assigned_bus'] ?? 'Unassigned', style: const TextStyle(fontWeight: FontWeight.w600, color: primaryBlue)),
                                ],
                              )
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.phone, color: Colors.green),
                          onPressed: () { /* Logic to call driver */ },
                        )
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 5. FEEDBACK VIEW (Fixed duplicate border bug)
// ==========================================
class FeedbackView extends StatelessWidget {
  const FeedbackView({Key? key}) : super(key: key);
  static const Color primaryBlue = Color(0xFF112D75);

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown Date";
    Duration diff = DateTime.now().difference(timestamp.toDate());
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inHours < 1) return "${diff.inMinutes}m ago";
    if (diff.inDays < 1) return "${diff.inHours}h ago";
    return "${diff.inDays}d ago";
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
          child: Text("Passenger Feedback", style: TextStyle(color: primaryBlue, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('feedbacks').orderBy('timestamp', descending: true).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No feedback received yet.", style: TextStyle(color: Colors.grey)));

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  var data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
                      // Fixed the duplicate border argument here!
                      border: const Border(
                        left: BorderSide(color: primaryBlue, width: 4),
                        top: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                        right: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                        bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.format_quote_rounded, color: primaryBlue, size: 20),
                                const SizedBox(width: 8),
                                Text(data['name'] ?? 'Anonymous', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryBlue)),
                              ],
                            ),
                            Text(_formatTimeAgo(data['timestamp'] as Timestamp?), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(data['message'] ?? 'No message provided.', style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}