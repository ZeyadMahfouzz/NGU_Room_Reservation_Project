import 'package:flutter/material.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  final String userRole; // You can pass the user role from LoginScreen in the future

  const HomeScreen({super.key, this.userRole = "Admin"});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "NGU Campus",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Color(0xFF8D0035),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, $userRole!",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8D0035),
              ),
            ),
            SizedBox(height: 20),
            if (userRole != "Student")
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to Room Reservation Page
                },
                icon: Icon(Icons.add_business),
                label: Text("Reserve a Room"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF8D0035),
                  foregroundColor: Colors.white,
                  minimumSize: Size(double.infinity, 50),
                ),
              ),
            if (userRole != "Student") SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to View Rooms / Class Schedule
              },
              icon: Icon(Icons.meeting_room),
              label: Text("View Available Rooms"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8D0035),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                // Navigate to My Reservations or My Classes
              },
              icon: Icon(Icons.calendar_today),
              label: Text("My Schedule"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8D0035),
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
            SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                // Log out and navigate back to login
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                );
              },
              icon: Icon(Icons.logout),
              label: Text("Logout"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
