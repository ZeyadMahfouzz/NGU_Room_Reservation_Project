import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'view_rooms.dart';
import 'reservation_service.dart';
import 'view_requests_screen.dart';
import 'view_reservations_history.dart';

class HomeScreen extends StatefulWidget {
  final String userRole;

  const HomeScreen({super.key, required this.userRole});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  String userName = '';
  String email = '';


  final List<Map<String, String>> mockSchedule = [
    {
      'time': '8:00 AM - 10:00 AM',
      'course': 'CSAI101 - Data Structures',
      'room': 'F 02',
    },
    {
      'time': '11:00 AM - 1:00 PM',
      'course': 'CSAI205 - Operating Systems',
      'room': 'G 07',
    },
    {
      'time': '2:00 PM - 3:30 PM',
      'course': 'CSAI310 - Software Engineering',
      'room': 'S 06',
    },
  ];

  @override
  void initState() {
    super.initState();
    getUserName();
  }

  Future<void> getUserName() async {
    final authUid = FirebaseAuth.instance.currentUser?.uid;
    if (authUid != null) {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('authUid', isEqualTo: authUid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userDoc = querySnapshot.docs.first;
        setState(() {
          userName = userDoc['name'] ?? 'No Name Available';
          email = userDoc['email'] ?? 'No Email Available';
        });
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    // Check if the userRole is 'faculty', 'student', or 'admin'
    if (widget.userRole.toLowerCase() == 'faculty') {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Faculty Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          backgroundColor: const Color(0xFF8D0035),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _selectedIndex == 0 ? _buildFacultyHomeContent() : _buildProfileContent(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF8D0035),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      );
    } else if (widget.userRole.toLowerCase() == 'admin') {
      // Admin UI
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Admin Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF8D0035),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _selectedIndex == 0 ? _buildAdminHomeContent() : _buildProfileContent(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF8D0035),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      );
    } else if (widget.userRole.toLowerCase() == 'student') {
      // Student UI
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Student Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: const Color(0xFF8D0035),
        ),
        body: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _selectedIndex == 0 ? _buildStudentHomeContent() : _buildProfileContent(),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFF8D0035),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: "Profile",
            ),
          ],
        ),
      );
    } else {
      // Default fallback for unauthorized role
      return const Scaffold(
        body: Center(child: Text("Unauthorized access")),
      );
    }
  }

  Widget _buildFacultyHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Schedule",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: mockSchedule.length,
            itemBuilder: (context, index) {
              final item = mockSchedule[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: Color(0xFF8D0035)),
                  title: Text(item['course'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['time'] ?? ''),
                      Text(
                        "Room: ${item['room'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRoomsScreen()),
            );
          },
          icon: const Icon(Icons.meeting_room),
          label: const Text("View Rooms"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRequestsHistoryScreen()),
            );
          },
          icon: const Icon(Icons.history),
          label: const Text("View History"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildAdminHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No Schedule for Admin
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRoomsScreen()),
            );
          },
          icon: const Icon(Icons.meeting_room),
          label: const Text("View Rooms"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRequestsScreen()),
            );
          },
          icon: const Icon(Icons.assignment),
          label: const Text("View Requests"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRequestsHistoryScreen()),
            );
          },
          icon: const Icon(Icons.assignment),
          label: const Text("View History"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentHomeContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Schedule",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: mockSchedule.length,
            itemBuilder: (context, index) {
              final item = mockSchedule[index];
              return Card(
                elevation: 3,
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.schedule, color: Color(0xFF8D0035)),
                  title: Text(item['course'] ?? ''),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['time'] ?? ''),
                      Text(
                        "Room: ${item['room'] ?? 'N/A'}",
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewRoomsScreen()),
            );
          },
          icon: const Icon(Icons.meeting_room),
          label: const Text("View Rooms"),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8D0035),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  DateTime? _semesterStart;
  DateTime? _semesterEnd;

  Widget _buildProfileContent() {
    final reservationService = ReservationService();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const CircleAvatar(
          radius: 50,
          backgroundImage: NetworkImage(
            'https://flutter.aelshafee.net/Basouny.jpg',
          ),
        ),
        const SizedBox(height: 20),
        Text(
          userName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 5),
        Text(
          email,
          style: const TextStyle(fontSize: 16),
        ),
        const SizedBox(height: 50),

        if (widget.userRole.toLowerCase() == 'admin') ...[
          Text(
            "Semester Date",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          ElevatedButton(
            onPressed: () async {
              // First pick start date
              final startDate = await showDatePicker(
                context: context,
                initialDate: _semesterStart ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (startDate != null) {
                setState(() {
                  _semesterStart = startDate;
                });

                // Then pick end date
                final endDate = await showDatePicker(
                  context: context,
                  initialDate: _semesterEnd ?? _semesterStart!.add(const Duration(days: 90)),
                  firstDate: _semesterStart!,
                  lastDate: DateTime(2100),
                );
                if (endDate != null) {
                  setState(() {
                    _semesterEnd = endDate;
                  });
                }
              }
            },
            child: Text(_semesterStart == null || _semesterEnd == null
                ? 'Select Semester Dates'
                : 'Dates: ${_formatDate(_semesterStart!)} - ${_formatDate(_semesterEnd!)}'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8D0035),
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height:5),
          ElevatedButton(
            onPressed: (_semesterStart != null && _semesterEnd != null)
                ? () async {
              try {
                await reservationService.reserveSemesterSlots(_semesterStart!, _semesterEnd!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Semester reservations generated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            }
                : null,
            child: const Text('Generate Semester Reservations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: (_semesterStart != null && _semesterEnd != null) ? const Color(0xFF8D0035) : Colors.grey,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Confirm Deletion'),
                  content: const Text('Are you sure you want to delete ALL reservations? This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  final reservationsSnapshot = await FirebaseFirestore.instance.collection('reservations').get();

                  for (final doc in reservationsSnapshot.docs) {
                    batch.delete(doc.reference);
                  }

                  await batch.commit();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All reservations deleted successfully.')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete reservations: $e')),
                  );
                }
              }
            },
            child: const Text('Delete All Reservations'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFD50000),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
          const SizedBox(height: 120),
        ],

        ElevatedButton.icon(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          icon: const Icon(Icons.logout),
          label: const Text("Logout"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

}
