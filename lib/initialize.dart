import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseInitializer {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> initializeSampleData() async {
    await _createBuilding();
    await _createRooms();
    await _createCourses();
    await _createUsersWithAuth();
    print('✅ Firebase sample data initialization complete.');
  }

  Future<void> _createBuilding() async {
    await _firestore.collection('buildings').doc('D').set({
      'name': 'Building D',
      'floors': 3,
      'type': 'Engineering'
    });
  }

  Future<void> _createRooms() async {
    final rooms = {
      'G-07': {
        'id': 'G-07',
        'buildingId': 'D',
        'floor': 'Ground',
        'classType': 'Lecture Room',
        'capacity': 80
      },
      'F-18': {
        'id': 'F-18',
        'buildingId': 'D',
        'floor': 'First',
        'classType': 'Lab',
        'capacity': 40
      },
      'F-04': {
        'id': 'F-04',
        'buildingId': 'D',
        'floor': 'First',
        'classType': 'Design Studio',
        'capacity': 45
      },
      'F-02': {
        'id': 'F-02',
        'buildingId': 'D',
        'floor': 'First',
        'classType': 'Lecture Room',
        'capacity': 35
      }
    };

    for (final entry in rooms.entries) {
      await _firestore.collection('rooms').doc(entry.key).set(entry.value);
    }
  }

  Future<void> _createCourses() async {
    final courses = {
      "CSAI231": {
        "code": "CSAI231",
        "title": "Modern App Development",
        "department": "IT",
        "year": 2,
        "instructors": ["202200011"],
        "tas": ["202200035", "202200037"],
        "schedule": [
          {
            "day": "monday",
            "slot": "slot1",
            "type": "Lecture",
            "roomId": "G-07"
          },
          {
            "day": "wednesday",
            "slot": "slot2",
            "type": "Lecture",
            "roomId": "G-07"
          },
          {
            "day": "thursday",
            "slot": "slot4",
            "type": "Lab",
            "roomId": "F-18"
          }
        ]
      },
      "MATH111": {
        "code": "MATH111",
        "title": "Calculus I",
        "department": "IT",
        "year": 1,
        "instructors": ["202200015"],
        "tas": ["202200035", "202200036"],
        "schedule": [
          {
            "day": "sunday",
            "slot": "slot1",
            "type": "Lecture",
            "roomId": "G-07"
          },
          {
            "day": "tuesday",
            "slot": "slot2",
            "type": "Lecture",
            "roomId": "G-07"
          },
          {
            "day": "wednesday",
            "slot": "slot4",
            "type": "Tutorial",
            "roomId": "F-02"
          }
        ]
      }
    };

    for (final entry in courses.entries) {
      await _firestore.collection('courses').doc(entry.key).set(entry.value);
    }
  }

  Future<void> _createUsersWithAuth() async {
    final users = [
      {
        "id": "202200011",
        "email": "ahmed.elshafee@ngu.edu.eg",
        "name": "Ahmed ElShafee",
        "role": "faculty"
      },
      {
        "id": "202200012",
        "email": "fatma.mostafa@ngu.edu.eg",
        "name": "Fatma Mostafa",
        "role": "faculty"
      },
      {
        "id": "202200015",
        "email": "laila.hesham@ngu.edu.eg",
        "name": "Laila Hesham",
        "role": "faculty"
      },
      {
        "id": "202200022",
        "email": "yasmine.mazyouna@ngu.edu.eg",
        "name": "Yasmine Mazyouna",
        "role": "admin"
      },
      {
        "id": "202200023",
        "email": "ammar.mohamed@ngu.edu.eg",
        "name": "Ammar Mohamed",
        "role": "student"
      },
      {
        "id": "202200024",
        "email": "mariam.khatab@ngu.edu.eg",
        "name": "Mariam Khatab",
        "role": "student"
      },
      {
        "id": "202200035",
        "email": "habiba.gamal@ngu.edu.eg",
        "name": "Habiba Gamal",
        "role": "faculty"
      },
      {
        "id": "202200036",
        "email": "nada.selim@ngu.edu.eg",
        "name": "Nada Selim",
        "role": "faculty"
      },
      {
        "id": "202200037",
        "email": "nora.ibrahim@ngu.edu.eg",
        "name": "Nora Ibrahim",
        "role": "faculty"
      }
    ];

    for (final user in users) {
      try {
        UserCredential credential = await _auth.createUserWithEmailAndPassword(
          email: user['email']!,
          password: 'password123',
        );

        final uid = credential.user!.uid;

        await _firestore.collection('users').doc(user['id']!).set({
          "email": user['email'],
          "name": user['name'],
          "role": user['role'],
          "authUid": uid,
        });

        print('✅ Created auth + Firestore for ${user['email']}');
      } catch (e) {
        print('⚠️ Failed to create user ${user['email']}: $e');
      }
    }
  }
}
