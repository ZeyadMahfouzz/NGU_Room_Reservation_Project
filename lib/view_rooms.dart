import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_detail.dart';

class ViewRoomsScreen extends StatefulWidget {
  const ViewRoomsScreen({super.key});

  @override
  State<ViewRoomsScreen> createState() => _ViewRoomsScreenState();
}

class _ViewRoomsScreenState extends State<ViewRoomsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? selectedBuilding;
  String? selectedClassType;
  DateTime selectedDate = DateTime.now();

  List<String> buildingOptions = [];
  List<String> classTypeOptions = [];

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    // Load distinct buildingIds and classTypes from rooms collection
    final roomsSnapshot = await _firestore.collection('rooms').get();

    final buildings = <String>{};
    final classTypes = <String>{};

    for (var doc in roomsSnapshot.docs) {
      final data = doc.data();
      buildings.add(data['buildingId'] ?? '');
      classTypes.add(data['classType'] ?? '');
    }

    setState(() {
      buildingOptions = buildings.where((b) => b.isNotEmpty).toList()..sort();
      classTypeOptions = classTypes.where((c) => c.isNotEmpty).toList()..sort();
    });
  }

  void _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _roomsStream() {
    Query<Map<String, dynamic>> query = _firestore.collection('rooms');

    if (selectedBuilding != null && selectedBuilding!.isNotEmpty) {
      query = query.where('buildingId', isEqualTo: selectedBuilding);
    }

    if (selectedClassType != null && selectedClassType!.isNotEmpty) {
      query = query.where('classType', isEqualTo: selectedClassType);
    }

    return query.snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "View Rooms"),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Date Filter
            ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: Text(
                "Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D0035),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 12),

            // Building & Class Type Filters Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedBuilding,
                    hint: const Text('Filter by Building'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Buildings')),
                      ...buildingOptions.map((b) => DropdownMenuItem(value: b, child: Text(b))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedBuilding = val == '' ? null : val;
                      });
                    },
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedClassType,
                    hint: const Text('Filter by Class Type'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('All Class Types')),
                      ...classTypeOptions.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (val) {
                      setState(() {
                        selectedClassType = val == '' ? null : val;
                      });
                    },
                    isExpanded: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rooms List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _roomsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final rooms = snapshot.data?.docs ?? [];
                  if (rooms.isEmpty) {
                    return const Center(child: Text('No rooms found.'));
                  }

                  return ListView.builder(
                    itemCount: rooms.length,
                    itemBuilder: (context, index) {
                      final room = rooms[index].data();
                      final roomId = room['id'];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.meeting_room, color: Color(0xFF8D0035), size: 30),
                          title: Text(roomId ?? 'Unknown Room', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'Floor: ${room['floor'] ?? '-'} • Capacity: ${room['capacity'] ?? '-'} • Type: ${room['classType'] ?? '-'}',
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RoomDetailScreen(
                                  roomId: roomId!,
                                  initialDate: selectedDate,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      iconTheme: const IconThemeData(color: Colors.white),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      backgroundColor: const Color(0xFF8D0035),
      elevation: 0,
      centerTitle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}