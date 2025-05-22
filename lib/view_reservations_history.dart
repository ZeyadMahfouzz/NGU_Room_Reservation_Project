import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

class ViewRequestsHistoryScreen extends StatefulWidget {
  const ViewRequestsHistoryScreen({super.key});

  @override
  State<ViewRequestsHistoryScreen> createState() => _ViewRequestsHistoryScreenState();
}


class _ViewRequestsHistoryScreenState extends State<ViewRequestsHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Map<String, String> _userNameCache = {};

  String role = '';
  String statusFilter = 'all'; // for filtering

  final Map<String, String> slotTimes = {
    'slot1': '9:00 - 10:15',
    'slot2': '10:30 - 11:45',
    'slot3': '11:45 - 1:00',
    'slot4': '1:00 - 2:15',
    'slot5': '2:30 - 3:45',
    'slot6': '4:00 - 5:15',
  };

  @override
  void initState() {
    super.initState();
    fetchCurrentUser();
  }

  Future<void> fetchCurrentUser() async {
    final authUid = _auth.currentUser?.uid;
    if (authUid == null) return;

    final snapshot = await _firestore
        .collection('users')
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final doc = snapshot.docs.first;
      setState(() {
        role = doc['role'] ?? '';
      });
    }
  }

  Future<String> _getUserName(String authId) async {
    if (_userNameCache.containsKey(authId)) {
      return _userNameCache[authId]!;
    }

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('authUid', isEqualTo: authId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final name = userData['name'] ?? 'Unnamed User';
        _userNameCache[authId] = name;
        return name;
      }
    } catch (e) {
      print('Error fetching user: $e');
    }
    return 'Unknown User';
  }

  Future<void> _cancelReservation(String docId, String roomId, String date, String slot) async {
    final reservationId = "$roomId-$date-$slot";

    try {
      await _firestore.collection('reservations').doc(reservationId).delete();
      await _firestore.collection('reservationRequests').doc(docId).update({
        'status': 'cancelled',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reservation cancelled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Not authenticated")));
    }

    Query requestsQuery = _firestore.collection('reservationRequests');
    if (role != 'admin') {
      requestsQuery = requestsQuery.where('reservedBy', isEqualTo: currentUser.uid);
    }
    if (statusFilter != 'all') {
      requestsQuery = requestsQuery.where('status', isEqualTo: statusFilter);
    }
    requestsQuery = requestsQuery.orderBy('updatedAt', descending: true);

    return Scaffold(
      appBar: CustomAppBar(title: "Request History"),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: DropdownButtonFormField<String>(
              value: statusFilter,
              decoration: const InputDecoration(labelText: 'Filter by status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (value) => setState(() => statusFilter = value ?? 'all'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: requestsQuery.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) return const Center(child: Text("No request history found."));

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final docId = doc.id;

                    final roomId = data['roomId'] ?? 'N/A';
                    final date = data['date'] ?? 'N/A';
                    final slotKey = data['slot'] ?? 'N/A';
                    final slot = slotTimes[slotKey] ?? slotKey;
                    final reservedBy = data['reservedBy'] ?? 'N/A';
                    final purpose = data['purpose'] ?? 'N/A';
                    final status = data['status'] ?? 'unknown';

                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
                    final updatedAt = (data['updatedAt'] as Timestamp?)?.toDate();

                    bool isFuture = false;
                    try {
                      final reservationDate = DateFormat('yyyy-MM-dd').parse(date);
                      final today = DateTime.now();
                      final nowDateOnly = DateTime(today.year, today.month, today.day);
                      isFuture = !reservationDate.isBefore(nowDateOnly);
                    } catch (_) {
                      isFuture = false;
                    }

                    return FutureBuilder<String>(
                      future: _getUserName(reservedBy),
                      builder: (context, snapshot) {
                        final userName = snapshot.data ?? 'Loading...';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Room: $roomId'),
                                          Text('Date: $date'),
                                          Text('Slot: $slot'),
                                        ],
                                      ),
                                    ),
                                    if (status != 'cancelled' && status != 'rejected' && isFuture)
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text('Confirm Cancellation'),
                                              content: const Text('Are you sure you want to cancel this reservation?'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () => Navigator.pop(context),
                                                  child: const Text('No'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    Navigator.pop(context);
                                                    await _cancelReservation(docId, roomId, date, slotKey);
                                                  },
                                                  child: const Text('Yes'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.cancel, size: 16),
                                        label: const Text('Cancel'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFFD50000),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Requested by: $userName'),
                                Text('Purpose: $purpose'),
                                Text('Status: $status'),
                                if (createdAt != null)
                                  Text('Requested on: ${DateFormat('MMM d, y • h:mm a').format(createdAt)}'),
                                if (updatedAt != null)
                                  Text('Updated ${timeago.format(updatedAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
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