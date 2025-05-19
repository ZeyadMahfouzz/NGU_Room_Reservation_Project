import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoomDetailScreen extends StatefulWidget {
  final String roomId;
  final DateTime initialDate;

  const RoomDetailScreen({
    super.key,
    required this.roomId,
    required this.initialDate,
  });

  @override
  State<RoomDetailScreen> createState() => _RoomDetailScreenState();
}

class _RoomDetailScreenState extends State<RoomDetailScreen> {
  late DateTime selectedDate;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? roomData;
  String? userRole; // <-- new field to store role
  bool loadingUserRole = true;

  final Map<String, String> slotTimes = {
    'slot1': '9:00 - 10:15',
    'slot2': '10:30 - 11:45',
    'slot3': '11:45 - 1:00',
    'slot4': '1:00 - 2:15',
    'slot5': '2:30 - 3:45',
    'slot6': '4:00 - 5:15',
  };

  final List<String> slots = ['slot1', 'slot2', 'slot3', 'slot4', 'slot5', 'slot6'];

  @override
  void initState() {
    super.initState();
    selectedDate = widget.initialDate;
    fetchUserRoleAndRoom();
  }

  Future<void> fetchUserRoleAndRoom() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // Fetch role
    final snapshot = await _firestore
        .collection('users')
        .where('authUid', isEqualTo: currentUser.uid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      userRole = doc['role'];
    }

    // Fetch room data
    final roomDoc = await _firestore.collection('rooms').doc(widget.roomId).get();
    if (roomDoc.exists) {
      roomData = roomDoc.data();
    }

    setState(() {
      loadingUserRole = false;
    });
  }

  Future<Map<String, ReservationStatus>> fetchSlotAvailability() async {
    final dateStr = "${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // Fetch confirmed reservations
    final reservationsSnapshot = await _firestore
        .collection('reservations')
        .where('roomId', isEqualTo: widget.roomId)
        .where('date', isEqualTo: dateStr)
        .get();

    // Fetch pending requests by current user
    final currentUser = FirebaseAuth.instance.currentUser;
    String? currentUserId = currentUser?.uid;

    final requestsSnapshot = currentUserId != null
        ? await _firestore
        .collection('reservationRequests')
        .where('roomId', isEqualTo: widget.roomId)
        .where('date', isEqualTo: dateStr)
        .where('reservedBy', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'pending')
        .get()
        : null;

    final Map<String, ReservationStatus> slotStatuses = {
      for (var slot in slots)
        slot: ReservationStatus(isAvailable: true, reservationType: null, courseCode: null, hasPendingRequest: false)
    };

    // Mark reserved slots from confirmed reservations
    for (final doc in reservationsSnapshot.docs) {
      final data = doc.data();
      final slot = data['slot'] as String;
      final isSystemReserved = data['isSystemReserved'] as bool? ?? false;
      final courseCode = data['courseCode'] as String?;

      slotStatuses[slot] = ReservationStatus(
        isAvailable: false,
        reservationType: isSystemReserved ? 'system' : 'manual',
        courseCode: courseCode,
        hasPendingRequest: false,
      );
    }

    // Mark slots that current user has pending requests for
    if (requestsSnapshot != null) {
      for (final doc in requestsSnapshot.docs) {
        final slot = doc.data()['slot'] as String;
        if (slotStatuses[slot]?.isAvailable ?? true) {
          // Only mark pending if slot is still available (not reserved)
          slotStatuses[slot] = slotStatuses[slot]!.copyWith(hasPendingRequest: true);
        }
      }
    }

    return slotStatuses;
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

  void _reserveSlot(String slot) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to reserve a slot.')),
      );
      return;
    }

    final userId = currentUser.uid;
    final userEmail = currentUser.email ?? '';
    final dateStr = "${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // Check existing pending requests (same as before)
    final existingQuery = await _firestore
        .collection('reservationRequests')
        .where('roomId', isEqualTo: widget.roomId)
        .where('date', isEqualTo: dateStr)
        .where('slot', isEqualTo: slot)
        .where('reservedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You already have a pending reservation request for this slot.')),
      );
      return;
    }

    // Show form dialog
    final purposeController = TextEditingController();
    final notesController = TextEditingController();
    final courseCodeController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reserve ${slotTimes[slot]} on $dateStr'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Show known info read-only
                Text('Room: ${roomData?['id'] ?? widget.roomId}'),
                Text('Date: $dateStr'),
                Text('Slot: ${slotTimes[slot]}'),
                const SizedBox(height: 12),
                // Course Code input (required)
                TextFormField(
                  controller: courseCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Course Code',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter the course code' : null,
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                // Purpose input (required)
                TextFormField(
                  controller: purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Please enter a purpose' : null,
                ),
                const SizedBox(height: 12),
                // Optional notes
                TextFormField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Additional notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (result == true) {
      // User submitted the form
      try {
        await _firestore.collection('reservationRequests').add({
          'roomId': widget.roomId,
          'date': dateStr,
          'slot': slot,
          'reservedBy': userId,
          'reservedByEmail': userEmail,
          'courseCode': courseCodeController.text.trim(),    // add this line (get courseCode from your UI or context)
          'purpose': purposeController.text.trim(),
          'notes': notesController.text.trim(),
          'status': 'pending',  // Admin will approve/reject
          'createdAt': FieldValue.serverTimestamp(),
          'isSystemReserved': false,
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reservation request sent. Awaiting admin approval.')),
        );

        setState(() {}); // Refresh UI
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send reservation request: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${widget.roomId} - Available Slots',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),),
        backgroundColor: const Color(0xFF8D0035),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (roomData != null)
              Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text(
                    'Room ${roomData!['id'] ?? widget.roomId}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Floor: ${roomData!['floor'] ?? 'N/A'}'),
                      Text('Type: ${roomData!['classType'] ?? 'N/A'}'),
                      Text('Capacity: ${roomData!['capacity'] ?? 'N/A'}'),
                    ],
                  ),
                ),
              )
            else
              const Center(child: CircularProgressIndicator()),
            ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                "Date: ${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8D0035),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
              ),
            ),
            const SizedBox(height: 20),
            FutureBuilder<Map<String, ReservationStatus>>(
              future: fetchSlotAvailability(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final slotStatuses = snapshot.data ?? {};

                return Expanded(
                  child: ListView.builder(
                    itemCount: slots.length,
                    itemBuilder: (context, index) {
                      final slot = slots[index];
                      final status = slotStatuses[slot] ??
                          ReservationStatus(isAvailable: true, reservationType: null, courseCode: null, hasPendingRequest: false);
                      final timeRange = slotTimes[slot] ?? slot;

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            timeRange,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: status.isAvailable
                              ? status.hasPendingRequest
                              ? const Text(
                            'Pending your request',
                            style: TextStyle(color: Colors.orange),
                          )
                              : const Text('Available')
                              : Text(
                            status.reservationType == 'system'
                                ? 'Reserved for ${status.courseCode ?? 'a course'}'
                                : 'Reserved',
                            style: TextStyle(
                              color: status.reservationType == 'system'
                                  ? Colors.blue.shade800
                                  : Colors.orange.shade800,
                            ),
                          ),
                          trailing: Builder(
                            builder: (context) {
                              // For students: show icon only if reserved
                              if (userRole == 'student') {
                                if (!status.isAvailable) {
                                  return Icon(
                                    status.reservationType == 'system' ? Icons.school : Icons.event_busy,
                                    color: status.reservationType == 'system'
                                        ? Colors.blue.shade800
                                        : Colors.orange.shade800,
                                  );
                                } else {
                                  return const SizedBox(); // Do not show button or icon if it's not reserved
                                }
                              }

                              // For faculty/admin: show button if available
                              if (status.isAvailable && !status.hasPendingRequest) {
                                return ElevatedButton(
                                  onPressed: () => _reserveSlot(slot),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8D0035),
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Reserve'),
                                );
                              } else {
                                return Icon(
                                  status.reservationType == 'system' ? Icons.school : Icons.event_busy,
                                  color: status.reservationType == 'system'
                                      ? Colors.blue.shade800
                                      : Colors.orange.shade800,
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationStatus {
  final bool isAvailable;
  final String? reservationType; // 'system' or 'manual' or null
  final String? courseCode;
  final bool hasPendingRequest;

  ReservationStatus({
    required this.isAvailable,
    this.reservationType,
    this.courseCode,
    required this.hasPendingRequest,
  });

  ReservationStatus copyWith({
    bool? isAvailable,
    String? reservationType,
    String? courseCode,
    bool? hasPendingRequest,
  }) {
    return ReservationStatus(
      isAvailable: isAvailable ?? this.isAvailable,
      reservationType: reservationType ?? this.reservationType,
      courseCode: courseCode ?? this.courseCode,
      hasPendingRequest: hasPendingRequest ?? this.hasPendingRequest,
    );
  }
}
