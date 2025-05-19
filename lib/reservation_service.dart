import 'package:cloud_firestore/cloud_firestore.dart';
import 'date_utility.dart'; // You must define dayToWeekday and getDatesForWeekday here

class ReservationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Map slot IDs to readable time ranges
  final Map<String, String> slotTimeRanges = {
    'slot1': '9:00 - 10:15',
    'slot2': '10:30 - 11:45',
    'slot3': '11:45 - 1:00',
    'slot4': '1:00 - 2:15',
    'slot5': '2:30 - 3:45',
    'slot6': '4:00 - 5:15',
  };

  Future<void> reserveSemesterSlots(DateTime semesterStart, DateTime semesterEnd) async {
    final coursesSnapshot = await _firestore.collection('courses').get();
    int reservationsCreated = 0;

    for (final courseDoc in coursesSnapshot.docs) {
      final course = courseDoc.data();
      final courseCode = course['code'] as String;
      final schedule = course['schedule'] as List<dynamic>? ?? [];

      for (final schedItem in schedule) {
        final dayStr = (schedItem['day'] as String).toLowerCase();
        final slot = schedItem['slot'] as String;
        final roomId = schedItem['roomId'] as String;
        final classType = schedItem['type'] as String? ?? 'Class';

        final weekday = dayToWeekday[dayStr];
        if (weekday == null) {
          print('⚠️ Invalid day in schedule: $dayStr');
          continue;
        }

        final dates = getDatesForWeekday(semesterStart, semesterEnd, weekday);

        for (final date in dates) {
          final dateString = "${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}";
          final reservationId = "$roomId-$dateString-$slot";

          final existingDoc = await _firestore.collection('reservations').doc(reservationId).get();
          if (existingDoc.exists) {
            continue; // Already reserved (manual or system) — skip
          }

          try {
            await _firestore.collection('reservations').doc(reservationId).set({
              'roomId': roomId,
              'date': dateString,
              'slot': slot,
              'courseCode': courseCode,
              'reservedBy': 'system',
              'purpose': '$classType for $courseCode',
              'status': 'confirmed',
              'createdAt': FieldValue.serverTimestamp(),
              'isSystemReserved': true,
              'timeRange': slotTimeRanges[slot] ?? 'Unknown',
            });

            reservationsCreated++;
          } catch (e) {
            print('⚠️ Error creating reservation $reservationId: $e');
          }
        }
      }
    }

    print('✅ Created $reservationsCreated new system reservations (skipped existing ones).');
  }
}
