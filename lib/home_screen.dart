import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart';
import 'view_rooms.dart';
import 'reservation_service.dart';
import 'view_requests_screen.dart';
import 'view_reservations_history.dart';

const Map<String, String> slotTimes = {
  'slot1': '9:00 - 10:15',
  'slot2': '10:30 - 11:45',
  'slot3': '11:45 - 1:00',
  'slot4': '1:00 - 2:15',
  'slot5': '2:30 - 3:45',
  'slot6': '4:00 - 5:15',
};

// Main Home Screen
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
    Widget homeContent;
    String title;

    switch (widget.userRole.toLowerCase()) {
      case 'faculty':
        homeContent = FacultyHomeContent();
        title = "Welcome $userName";
        break;
      case 'admin':
        homeContent = AdminHomeContent();
        title = "Welcome $userName";
        break;
      case 'student':
        homeContent = StudentHomeContent();
        title = "Welcome $userName";
        break;
      default:
        return const Scaffold(
          body: Center(
            child: Text(
              "Unauthorized access",
              style: TextStyle(fontSize: 18, color: Colors.red),
            ),
          ),
        );
    }

    return Scaffold(
      appBar: CustomAppBar(title: title),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF8F9FA),
              Color(0xFFE9ECEF),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: _selectedIndex == 0
              ? homeContent
              : ProfileContent(
            userName: userName,
            email: email,
            userRole: widget.userRole,
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}

// Custom App Bar Component
class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
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

// Custom Bottom Navigation Bar
class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          selectedItemColor: const Color(0xFF8D0035),
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          onTap: onTap,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: "Home",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

// Schedule Card Component
class ScheduleCard extends StatelessWidget {
  final Map<String, String> scheduleItem;

  const ScheduleCard({super.key, required this.scheduleItem});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF8D0035).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.schedule_rounded,
                color: Color(0xFF8D0035),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scheduleItem['course'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheduleItem['course_name'] ?? '',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheduleItem['time'] ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.room_rounded,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "Room: ${scheduleItem['room'] ?? 'N/A'}",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Universal Action Card Component (used by all user types)
class UniversalActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onPressed;
  final Widget? trailing;

  const UniversalActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onPressed,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ] else ...[
              const SizedBox(width: 12),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ]
          ],
        ),
      ),
    );
  }
}

// Welcome Header Component
class WelcomeHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const WelcomeHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF8D0035),
            const Color(0xFF8D0035).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D0035).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Schedule Section Component
class ScheduleSection extends StatelessWidget {
  final List<Map<String, String>> schedule;

  const ScheduleSection({
    super.key,
    required this.schedule,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Today's Schedule",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: ListView.builder(
            itemCount: schedule.length,
            itemBuilder: (context, index) {
              return ScheduleCard(scheduleItem: schedule[index]);
            },
          ),
        ),
      ],
    );
  }
}

// Faculty Home Content
class FacultyHomeContent extends StatefulWidget {
  const FacultyHomeContent({super.key});

  @override
  State<FacultyHomeContent> createState() => _FacultyHomeContentState();
}

class _FacultyHomeContentState extends State<FacultyHomeContent> {
  List<Map<String, String>> userSchedule = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSchedule();
  }

  Future<void> _loadUserSchedule() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('authUid', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final scheduleMap = doc['schedule'] as Map<String, dynamic>? ?? {};
        final currentDay = _getCurrentDay();
        final rawSchedule = scheduleMap[currentDay] as List<dynamic>? ?? [];

        setState(() {
          userSchedule = rawSchedule.map((item) {
            final slot = (item as Map<String, dynamic>)['slot']?.toString() ?? '';
            return {
              'course': item['course']?.toString() ?? 'N/A',
              'course_name': item['course_name']?.toString() ?? 'N/A',
              'room': item['room']?.toString() ?? 'N/A',
              'time': slotTimes[slot] ?? 'Time not available',
            };
          }).toList();
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading schedule: $e');
      setState(() {
        userSchedule = [];
        loading = false;
      });
    }
  }

  String _getCurrentDay() {
    return switch (DateTime.now().weekday) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Monday',
    };
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: userSchedule.isEmpty
                ? const Center(
                child: Text(
                  "No classes today",
                  style: TextStyle(color: Colors.grey),
                ))
                : ListView.builder(
              itemCount: userSchedule.length,
              itemBuilder: (context, index) {
                return ScheduleCard(
                    scheduleItem: userSchedule[index]);
              },
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Actions",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          UniversalActionCard(
            icon: Icons.meeting_room_rounded,
            title: "View Rooms",
            subtitle: "Check room availability",
            color: const Color(0xFF8D0035),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ViewRoomsScreen()),
              );
            },
          ),
          UniversalActionCard(
            icon: Icons.history_rounded,
            title: "View History",
            subtitle: "Check past reservations",
            color: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ViewRequestsHistoryScreen()),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// Admin Home Content
class AdminHomeContent extends StatelessWidget {
  const AdminHomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WelcomeHeader(
            title: "Admin Dashboard",
            subtitle: "Manage rooms, requests & reservations",
            icon: Icons.admin_panel_settings_rounded,
          ),
          const SizedBox(height: 70),
          UniversalActionCard(
            icon: Icons.meeting_room_rounded,
            title: "View Rooms",
            subtitle: "Manage room availability",
            color: const Color(0xFF8D0035),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewRoomsScreen()),
              );
            },
          ),
          UniversalActionCard(
            icon: Icons.assignment_rounded,
            title: "View Requests",
            subtitle: "Review pending requests",
            color: Colors.orange,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewRequestsScreen()),
              );
            },
          ),
          UniversalActionCard(
            icon: Icons.history_rounded,
            title: "View History",
            subtitle: "Check past reservations",
            color: Colors.blue,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewRequestsHistoryScreen()),
              );
            },
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

// Student Home Content
class StudentHomeContent extends StatefulWidget {
  const StudentHomeContent({super.key});

  @override
  State<StudentHomeContent> createState() => _StudentHomeContentState();
}

class _StudentHomeContentState extends State<StudentHomeContent> {
  List<Map<String, String>> userSchedule = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSchedule();
  }

  Future<void> _loadUserSchedule() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('authUid', isEqualTo: userId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final scheduleMap = doc['schedule'] as Map<String, dynamic>? ?? {};
        final currentDay = _getCurrentDay();
        final rawSchedule = scheduleMap[currentDay] as List<dynamic>? ?? [];

        setState(() {
          userSchedule = rawSchedule.map((item) {
            final slot = (item as Map<String, dynamic>)['slot']?.toString() ?? '';
            return {
              'course': item['course']?.toString() ?? 'N/A',
              'course_name': item['course_name']?.toString() ?? 'N/A',
              'room': item['room']?.toString() ?? 'N/A',
              'time': slotTimes[slot] ?? 'Time not available',
            };
          }).toList();
          loading = false;
        });
      }
    } catch (e) {
      print('Error loading schedule: $e');
      setState(() {
        userSchedule = [];
        loading = false;
      });
    }
  }

  String _getCurrentDay() {
    return switch (DateTime.now().weekday) {
      1 => 'Monday',
      2 => 'Tuesday',
      3 => 'Wednesday',
      4 => 'Thursday',
      5 => 'Friday',
      6 => 'Saturday',
      7 => 'Sunday',
      _ => 'Monday',
    };
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Today's Schedule",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 440,
            child: userSchedule.isEmpty
                ? const Center(
                child: Text(
                  "No classes today",
                  style: TextStyle(color: Colors.grey),
                ))
                : ListView.builder(
              itemCount: userSchedule.length,
              itemBuilder: (context, index) {
                return ScheduleCard(scheduleItem: userSchedule[index]);
              },
            ),
          ),
          const SizedBox(height: 15),
          UniversalActionCard(
            icon: Icons.meeting_room_rounded,
            title: "View Rooms",
            subtitle: "Check room availability",
            color: const Color(0xFF8D0035),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ViewRoomsScreen()),
              );
            },
          ),
          const SizedBox(height: 15),
        ],
      ),
    );
  }
}

// Profile Content Component
class ProfileContent extends StatefulWidget {
  final String userName;
  final String email;
  final String userRole;

  const ProfileContent({
    super.key,
    required this.userName,
    required this.email,
    required this.userRole,
  });

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  DateTime? _semesterStart;
  DateTime? _semesterEnd;

  @override
  Widget build(BuildContext context) {
    final reservationService = ReservationService();

    return SingleChildScrollView(
      child: Column(
        children: [
          if (widget.userRole.toLowerCase() != 'admin') ...[
            const SizedBox(height: 60),
          ],
          const SizedBox(height: 14),
          UserProfileCard(
            userName: widget.userName,
            email: widget.email,
            userRole: widget.userRole,
          ),
          if (widget.userRole.toLowerCase() == 'admin') ...[
            const SizedBox(height: 20),
            AdminControls(
              semesterStart: _semesterStart,
              semesterEnd: _semesterEnd,
              onDatesSelected: (start, end) {
                setState(() {
                  _semesterStart = start;
                  _semesterEnd = end;
                });
              },
              reservationService: reservationService,
            ),
          ],
          const SizedBox(height: 26),
          UniversalActionCard(
            icon: Icons.logout_rounded,
            title: "Logout",
            subtitle: "Sign out of your account",
            color: Colors.grey,
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
          if (widget.userRole.toLowerCase() != 'admin') ...[
            const SizedBox(height: 140),
          ],
        ],
      ),
    );
  }
}

// User Profile Card Component
class UserProfileCard extends StatelessWidget {
  final String userName;
  final String email;
  final String userRole;

  const UserProfileCard({
    super.key,
    required this.userName,
    required this.email,
    required this.userRole,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF8D0035),
                width: 3,
              ),
            ),
            child: const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                'https://flutter.aelshafee.net/Basouny.jpg',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            userName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF8D0035).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              userRole.toUpperCase(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8D0035),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Admin Controls Component
class AdminControls extends StatelessWidget {
  final DateTime? semesterStart;
  final DateTime? semesterEnd;
  final Function(DateTime?, DateTime?) onDatesSelected;
  final ReservationService reservationService;

  const AdminControls({
    super.key,
    required this.semesterStart,
    required this.semesterEnd,
    required this.onDatesSelected,
    required this.reservationService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Semester Management",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          UniversalActionCard(
            icon: Icons.calendar_today_rounded,
            title: semesterStart == null || semesterEnd == null
                ? 'Select Semester Dates'
                : 'Update Semester Dates',
            subtitle: semesterStart == null || semesterEnd == null
                ? 'Choose start and end dates'
                : 'Dates: ${_formatDate(semesterStart!)} - ${_formatDate(semesterEnd!)}',
            color: const Color(0xFF8D0035),
            onPressed: () async {
              final startDate = await showDatePicker(
                context: context,
                initialDate: semesterStart ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (startDate != null) {
                final endDate = await showDatePicker(
                  context: context,
                  initialDate: semesterEnd ?? startDate.add(const Duration(days: 90)),
                  firstDate: startDate,
                  lastDate: DateTime(2100),
                );
                if (endDate != null) {
                  onDatesSelected(startDate, endDate);
                }
              }
            },
          ),
          UniversalActionCard(
            icon: Icons.event_available_rounded,
            title: 'Generate Semester Reservations',
            subtitle: 'Create reservations for semester',
            color: (semesterStart != null && semesterEnd != null)
                ? const Color(0xFF8D0035)
                : Colors.grey,
            onPressed: (semesterStart != null && semesterEnd != null)
                ? () async {
              try {
                await reservationService.reserveSemesterSlots(semesterStart!, semesterEnd!);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Semester reservations generated successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
                : () {},
          ),
          UniversalActionCard(
            icon: Icons.delete_forever_rounded,
            title: 'Delete All Reservations',
            subtitle: 'Remove all existing reservations',
            color: const Color(0xFFD50000),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Text('Confirm Deletion'),
                  content: const Text(
                    'Are you sure you want to delete ALL reservations? This action cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD50000),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                try {
                  final batch = FirebaseFirestore.instance.batch();
                  final reservationsSnapshot = await FirebaseFirestore.instance
                      .collection('reservations')
                      .get();

                  for (final doc in reservationsSnapshot.docs) {
                    batch.delete(doc.reference);
                  }

                  await batch.commit();

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All reservations deleted successfully.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete reservations: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }
}