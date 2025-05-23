import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'room_detail.dart';

class ViewRoomsScreen extends StatefulWidget {
  const ViewRoomsScreen({super.key});

  @override
  State<ViewRoomsScreen> createState() => _ViewRoomsScreenState();
}

class _ViewRoomsScreenState extends State<ViewRoomsScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late AnimationController _filterAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _filterSlideAnimation;

  String? selectedBuilding;
  String? selectedClassType;
  String? selectedFloor;
  String searchQuery = '';
  DateTime selectedDate = DateTime.now();

  List<String> buildingOptions = [];
  List<String> classTypeOptions = [];
  List<String> floorOptions = [];
  bool isLoading = true;
  bool isFilterExpanded = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _filterAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _filterSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _filterAnimationController, curve: Curves.easeInOut),
    );
    _loadFilterOptions();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _filterAnimationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleFilter() {
    setState(() {
      isFilterExpanded = !isFilterExpanded;
    });
    if (isFilterExpanded) {
      _filterAnimationController.forward();
    } else {
      _filterAnimationController.reverse();
    }
  }

  Future<void> _loadFilterOptions() async {
    try {
      final roomsSnapshot = await _firestore.collection('rooms').get();

      final buildings = <String>{};
      final classTypes = <String>{};
      final floors = <String>{};

      for (var doc in roomsSnapshot.docs) {
        final data = doc.data();
        buildings.add(data['buildingId'] ?? '');
        classTypes.add(data['classType'] ?? '');
        final floor = data['floor'];
        if (floor != null) {
          floors.add(floor.toString());
        }
      }

      setState(() {
        buildingOptions = buildings.where((b) => b.isNotEmpty).toList()..sort();
        classTypeOptions = classTypes.where((c) => c.isNotEmpty).toList()..sort();
        floorOptions = floors.where((f) => f.isNotEmpty).toList()
          ..sort((a, b) => int.tryParse(a)?.compareTo(int.tryParse(b) ?? 0) ?? a.compareTo(b));
        isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
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
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8D0035),
              onPrimary: Colors.white,
              surface: Colors.white,
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _roomsStream() {
    Query<Map<String, dynamic>> query = _firestore.collection('rooms');

    if (selectedBuilding != null && selectedBuilding!.isNotEmpty) {
      query = query.where('buildingId', isEqualTo: selectedBuilding);
    }

    if (selectedClassType != null && selectedClassType!.isNotEmpty) {
      query = query.where('classType', isEqualTo: selectedClassType);
    }

    if (selectedFloor != null && selectedFloor!.isNotEmpty) {
      // Convert to int if possible for proper comparison
      final floorValue = int.tryParse(selectedFloor!) ?? selectedFloor!;
      query = query.where('floor', isEqualTo: floorValue);
    }

    return query.snapshots();
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _filterRoomsBySearch(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> rooms,
      ) {
    if (searchQuery.isEmpty) return rooms;

    return rooms.where((room) {
      final data = room.data();
      final roomId = (data['id'] ?? '').toString().toLowerCase();
      return roomId.contains(searchQuery.toLowerCase());
    }).toList();
  }

  void _clearFilters() {
    setState(() {
      selectedBuilding = null;
      selectedClassType = null;
      selectedFloor = null;
      selectedDate = DateTime.now();
      searchQuery = '';
      _searchController.clear();
    });
  }

  int get _activeFiltersCount {
    int count = 0;
    if (selectedBuilding != null) count++;
    if (selectedClassType != null) count++;
    if (selectedFloor != null) count++;
    if (searchQuery.isNotEmpty) count++;
    if (selectedDate.day != DateTime.now().day) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: CustomAppBar(title: "Room Explorer"),
      body: isLoading
          ? const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D0035)),
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Collapsible Filter Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Filter Header (Always Visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: const Color(0xFF8D0035),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Filters',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        if (_activeFiltersCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8D0035),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$_activeFiltersCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (_activeFiltersCount > 0)
                          TextButton(
                            onPressed: _clearFilters,
                            child: const Text(
                              'Clear All',
                              style: TextStyle(
                                color: Color(0xFF8D0035),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: _toggleFilter,
                          icon: AnimatedRotation(
                            turns: isFilterExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 300),
                            child: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF8D0035),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Search (Always Visible)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Quick search rooms...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF8D0035),
                            size: 20,
                          ),
                          suffixIcon: searchQuery.isNotEmpty
                              ? IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                searchQuery = '';
                              });
                            },
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.grey,
                              size: 18,
                            ),
                          )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 14,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2D3748),
                        ),
                      ),
                    ),
                  ),

                  // Expandable Filter Content
                  SizeTransition(
                    sizeFactor: _filterSlideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        children: [
                          // Date Filter
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8D0035), Color(0xFFB91C4D)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8D0035).withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _selectDate,
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Selected Date',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Text(
                                            "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      const Icon(
                                        Icons.edit_calendar,
                                        color: Colors.white70,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Dropdown Filters
                          Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildEnhancedDropdown(
                                      value: selectedBuilding,
                                      hint: 'Buildings',
                                      icon: Icons.apartment,
                                      items: buildingOptions,
                                      onChanged: (val) {
                                        setState(() {
                                          selectedBuilding = val == '' ? null : val;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _buildEnhancedDropdown(
                                      value: selectedClassType,
                                      hint: 'Class Types',
                                      icon: Icons.school,
                                      items: classTypeOptions,
                                      onChanged: (val) {
                                        setState(() {
                                          selectedClassType = val == '' ? null : val;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildEnhancedDropdown(
                                value: selectedFloor,
                                hint: 'All Floors',
                                icon: Icons.layers,
                                items: floorOptions,
                                onChanged: (val) {
                                  setState(() {
                                    selectedFloor = val == '' ? null : val;
                                  });
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Enhanced Rooms List
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _roomsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8D0035)),
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Something went wrong',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Error: ${snapshot.error}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allRooms = snapshot.data?.docs ?? [];
                  final filteredRooms = _filterRoomsBySearch(allRooms);

                  if (filteredRooms.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            searchQuery.isNotEmpty ? Icons.search_off : Icons.filter_list_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isNotEmpty ? 'No rooms match your search' : 'No rooms found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            searchQuery.isNotEmpty
                                ? 'Try a different search term or adjust filters'
                                : 'Try adjusting your filters',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (_activeFiltersCount > 0) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Clear All Filters'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8D0035),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      // Results Summary
                      if (_activeFiltersCount > 0)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8D0035).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF8D0035).withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            '${filteredRooms.length} room${filteredRooms.length != 1 ? 's' : ''} found${searchQuery.isNotEmpty ? ' for "$searchQuery"' : ''}',
                            style: const TextStyle(
                              color: Color(0xFF8D0035),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),

                      // Rooms List
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredRooms.length,
                          itemBuilder: (context, index) {
                            final room = filteredRooms[index].data();
                            final roomId = room['id'];

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
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
                                  borderRadius: BorderRadius.circular(16),
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
                                            Icons.meeting_room,
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
                                                roomId ?? 'Unknown Room',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2D3748),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  _buildInfoChip(
                                                    Icons.layers,
                                                    'Floor ${room['floor'] ?? '-'}',
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _buildInfoChip(
                                                    Icons.people,
                                                    '${room['capacity'] ?? '-'} seats',
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              _buildInfoChip(
                                                Icons.category,
                                                room['classType'] ?? 'Unknown Type',
                                                isFullWidth: true,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_ios,
                                            size: 16,
                                            color: Color(0xFF8D0035),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF8D0035), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        items: [
          DropdownMenuItem(
            value: '',
            child: Text(
              'All ${hint}',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          ...items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(
              item,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          )),
        ],
        onChanged: onChanged,
        isExpanded: true,
        style: const TextStyle(fontSize: 12, color: Color(0xFF2D3748)),
        dropdownColor: Colors.white,
        isDense: true,
        icon: const Icon(
          Icons.keyboard_arrow_down,
          size: 20,
          color: Color(0xFF8D0035),
        ),
        selectedItemBuilder: (BuildContext context) {
          return [
            Text('All ${hint}', style: const TextStyle(fontSize: 12, color: Color(0xFF2D3748))),
            ...items.map((item) => Text(
              item,
              style: const TextStyle(fontSize: 12, color: Color(0xFF2D3748)),
              overflow: TextOverflow.ellipsis,
            )),
          ];
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label, {bool isFullWidth = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
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