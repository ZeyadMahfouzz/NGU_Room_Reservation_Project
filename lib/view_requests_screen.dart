import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;


class ViewRequestsScreen extends StatefulWidget {
  const ViewRequestsScreen({super.key});

  @override
  State<ViewRequestsScreen> createState() => _ViewRequestsScreenState();
}

class _ViewRequestsScreenState extends State<ViewRequestsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, String> _userNameCache = {};

  Map<String, dynamic>? roomData;

  final Map<String, String> slotTimes = {
    'slot1': '9:00 - 10:15',
    'slot2': '10:30 - 11:45',
    'slot3': '11:45 - 1:00',
    'slot4': '1:00 - 2:15',
    'slot5': '2:30 - 3:45',
    'slot6': '4:00 - 5:15',
  };

  final List<String> slots = ['slot1', 'slot2', 'slot3', 'slot4', 'slot5', 'slot6'];


  Future<void> _updateRequestStatus(String docId, String newStatus) async {
    try {
      await _firestore.collection('reservationRequests').doc(docId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (newStatus == 'approved') {
        // On approval, create a confirmed reservation document
        final doc = await _firestore.collection('reservationRequests').doc(docId).get();
        final data = doc.data();
        if (data != null) {
          final reservationId = "${data['roomId']}-${data['date']}-${data['slot']}";
          await _firestore.collection('reservations').doc(reservationId).set({
            'roomId': data['roomId'],
            'date': data['date'],
            'slot': data['slot'],
            'reservedBy': data['reservedBy'],
            'courseCode': data['courseCode'],
            'purpose': data['purpose'],
            'notes': data['notes'],
            'status': 'confirmed',
            'createdAt': FieldValue.serverTimestamp(),
            'isSystemReserved': false,
            'approvedFromRequestId': docId,
          });
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $newStatus successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(title: "Pending Requests"),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('reservationRequests')
            .where('status', isEqualTo: 'pending')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data()! as Map<String, dynamic>;
              final roomId = data['roomId'] ?? 'N/A';
              final date = data['date'] ?? 'N/A';
              final slot = slotTimes[data['slot']] ?? 'N/A';
              final reservedBy = data['reservedBy'] ?? 'N/A';
              final purpose = data['purpose'] ?? 'N/A';
              final createdAtTimestamp = data['createdAt'] as Timestamp?;
              final createdAt = createdAtTimestamp != null
                  ? createdAtTimestamp.toDate()
                  : null;

              return FutureBuilder<String>(
                future: _getUserName(reservedBy),
                builder: (context, nameSnapshot) {
                  final userName = nameSnapshot.data ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: ListTile(
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Room: $roomId'), Text('Date: $date'), Text('Slot: $slot'),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Requested by: $userName'),
                          Text('Purpose: $purpose'),
                          if (createdAt != null) ...[
                            Text('Requested on: ${DateFormat('y-M-d • h:mm a').format(createdAt)}'),
                            Text('${timeago.format(createdAt)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _updateRequestStatus(doc.id, 'approved'),
                            tooltip: 'Approve',
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _updateRequestStatus(doc.id, 'rejected'),
                            tooltip: 'Reject',
                          ),
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