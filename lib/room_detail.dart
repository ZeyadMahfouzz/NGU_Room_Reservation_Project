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

class _RoomDetailScreenState extends State<RoomDetailScreen> with TickerProviderStateMixin {
  late DateTime selectedDate;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? roomData;
  String? userRole;
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
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    fetchUserRoleAndRoom();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> fetchUserRoleAndRoom() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
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

      _animationController.forward();
    } catch (e) {
      setState(() {
        loadingUserRole = false;
      });
    }
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: const Color(0xFF8D0035),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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
      _showSnackBar('You must be logged in to reserve a slot.', isError: true);
      return;
    }

    final userId = currentUser.uid;
    final userEmail = currentUser.email ?? '';
    final dateStr = "${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

    // Check existing pending requests
    final existingQuery = await _firestore
        .collection('reservationRequests')
        .where('roomId', isEqualTo: widget.roomId)
        .where('date', isEqualTo: dateStr)
        .where('slot', isEqualTo: slot)
        .where('reservedBy', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existingQuery.docs.isNotEmpty) {
      _showSnackBar('You already have a pending reservation request for this slot.', isError: true);
      return;
    }

    // Show enhanced form dialog
    final result = await _showReservationDialog(slot, dateStr);

    if (result != null) {
      try {
        await _firestore.collection('reservationRequests').add({
          'roomId': widget.roomId,
          'date': dateStr,
          'slot': slot,
          'reservedBy': userId,
          'reservedByEmail': userEmail,
          'courseCode': result['courseCode'],
          'purpose': result['purpose'],
          'notes': result['notes'],
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'isSystemReserved': false,
        });

        _showSnackBar('Reservation request sent successfully! Awaiting admin approval.', isError: false);
        setState(() {});
      } catch (e) {
        _showSnackBar('Failed to send reservation request. Please try again.', isError: true);
      }
    }
  }

  Future<Map<String, String>?> _showReservationDialog(String slot, String dateStr) async {
    final purposeController = TextEditingController();
    final notesController = TextEditingController();
    final courseCodeController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, String>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 16,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Colors.grey.shade50],
            ),
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8D0035).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.meeting_room,
                          color: Color(0xFF8D0035),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reserve Room ${widget.roomId}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8D0035),
                              ),
                            ),
                            Text(
                              '${slotTimes[slot]} • $dateStr',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildFormField(
                    controller: courseCodeController,
                    label: 'Course Code',
                    icon: Icons.book,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please enter the course code' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: purposeController,
                    label: 'Purpose',
                    icon: Icons.assignment,
                    validator: (value) => (value == null || value.trim().isEmpty)
                        ? 'Please enter a purpose' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildFormField(
                    controller: notesController,
                    label: 'Additional notes (optional)',
                    icon: Icons.note,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (formKey.currentState!.validate()) {
                              Navigator.pop(context, {
                                'courseCode': courseCodeController.text.trim(),
                                'purpose': purposeController.text.trim(),
                                'notes': notesController.text.trim(),
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8D0035),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                          child: const Text(
                            'Submit Request',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF8D0035)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8D0035), width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: CustomAppBar(title: "Room ${widget.roomId}"),
      body: loadingUserRole
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF8D0035)))
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRoomInfoCard(),
                const SizedBox(height: 20),
                _buildDateSelector(),
                const SizedBox(height: 24),
                const Text(
                  'Available Time Slots',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8D0035),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSlotsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoomInfoCard() {
    if (roomData == null) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.grey.shade200, Colors.grey.shade100],
          ),
        ),
        child: const Center(child: CircularProgressIndicator(color: Color(0xFF8D0035))),
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF8D0035),
            const Color(0xFF8D0035).withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D0035).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.meeting_room,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Room ${roomData!['id'] ?? widget.roomId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(Icons.layers, 'Floor ${roomData!['floor'] ?? 'N/A'}'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.category, roomData!['classType'] ?? 'N/A'),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.people, '${roomData!['capacity'] ?? 'N/A'} seats'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D0035).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: Color(0xFF8D0035),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected Date',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${selectedDate.day} ${_getMonthName(selectedDate.month)} ${selectedDate.year}",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8D0035),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF8D0035),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  Widget _buildSlotsList() {
    return FutureBuilder<Map<String, ReservationStatus>>(
      future: fetchSlotAvailability(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: Color(0xFF8D0035)),
            ),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error loading slots: ${snapshot.error}'),
              ],
            ),
          );
        }

        final slotStatuses = snapshot.data ?? {};

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: slots.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final slot = slots[index];
            final status = slotStatuses[slot] ??
                ReservationStatus(
                  isAvailable: true,
                  reservationType: null,
                  courseCode: null,
                  hasPendingRequest: false,
                );
            return _buildSlotCard(slot, status);
          },
        );
      },
    );
  }

  Widget _buildSlotCard(String slot, ReservationStatus status) {
    final timeRange = slotTimes[slot] ?? slot;

    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.shade200;
    Color textColor = Colors.black87;
    IconData statusIcon = Icons.schedule;
    Color iconColor = Colors.green;
    String statusText = 'Available';

    if (!status.isAvailable) {
      if (status.reservationType == 'system') {
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade200;
        iconColor = Colors.blue.shade600;
        statusIcon = Icons.school;
        statusText = 'Reserved for ${status.courseCode ?? 'a course'}';
      } else {
        cardColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade200;
        iconColor = Colors.orange.shade600;
        statusIcon = Icons.event_busy;
        statusText = 'Reserved';
      }
    } else if (status.hasPendingRequest) {
      cardColor = Colors.amber.shade50;
      borderColor = Colors.amber.shade200;
      iconColor = Colors.amber.shade600;
      statusIcon = Icons.pending;
      statusText = 'Pending your request';
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    timeRange,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8D0035),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 14,
                      color: iconColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (_shouldShowReserveButton(status))
              ElevatedButton(
                onPressed: () => _reserveSlot(slot),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8D0035),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Reserve',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool _shouldShowReserveButton(ReservationStatus status) {
    // For students: never show reserve button
    if (userRole == 'student') {
      return false;
    }

    // For faculty/admin: show button only if available and no pending request
    return status.isAvailable && !status.hasPendingRequest;
  }
}

class ReservationStatus {
  final bool isAvailable;
  final String? reservationType;
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