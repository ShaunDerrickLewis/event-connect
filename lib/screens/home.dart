import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String rawSearchText = '';
  String searchQuery = '';
  String? selectedCategory;
  String sortOrder = 'Newest';
  Timer? _debounce;

  final List<String> categories = ['All', 'Sports', 'Music', 'Tech', 'Art', 'Food', 'Meetup', 'Chico'];

  final Map<String, IconData> categoryIcons = {
    'All': Icons.grid_view,
    'Sports': Icons.sports_soccer,
    'Music': Icons.music_note,
    'Tech': Icons.computer,
    'Art': Icons.brush,
    'Food': Icons.restaurant,
    'Meetup': Icons.people,
    'Chico': Icons.place,
  };

  final Map<String, IconData> sortIcons = {
    'Newest': Icons.access_time,
    'Oldest': Icons.history,
    'A–Z': Icons.sort_by_alpha,
  };

  final List<String> sortOptions = ['Newest', 'Oldest', 'A–Z'];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(160),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color(0xFFF8F4FF),
          elevation: 0,
          flexibleSpace: Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset('assets/chico_wildcat_welcome.png', height: 40),
                  const SizedBox(height: 8),
                  Text("EventConnect", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text("Discover events in Chico", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700])),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Material(
              elevation: 5,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF2ECFF), borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        style: GoogleFonts.poppins(fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search by title or location',
                          hintStyle: GoogleFonts.poppins(color: Colors.grey[700]),
                          prefixIcon: const Icon(Icons.search, color: Color(0xFF6D28D9)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        onChanged: (value) {
                          rawSearchText = value;
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), () {
                            if (searchQuery != rawSearchText) {
                              setState(() {
                                searchQuery = rawSearchText;
                              });
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedCategory ?? 'All',
                            items: categories.map((cat) {
                              return DropdownMenuItem(
                                value: cat,
                                child: Row(
                                  children: [
                                    Icon(categoryIcons[cat], size: 20, color: Colors.deepPurple),
                                    const SizedBox(width: 10),
                                    Text(cat, style: GoogleFonts.poppins()),
                                  ],
                                ),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Category',
                              labelStyle: GoogleFonts.poppins(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (value) => setState(() => selectedCategory = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: sortOrder,
                            items: sortOptions.map((opt) {
                              return DropdownMenuItem(
                                value: opt,
                                child: Row(
                                  children: [
                                    Icon(sortIcons[opt], size: 20, color: Colors.deepPurple),
                                    const SizedBox(width: 10),
                                    Text(opt, style: GoogleFonts.poppins()),
                                  ],
                                ),
                              );
                            }).toList(),
                            decoration: InputDecoration(
                              labelText: 'Sort by',
                              labelStyle: GoogleFonts.poppins(),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onChanged: (value) => setState(() => sortOrder = value ?? 'Newest'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                List<QueryDocumentSnapshot> events = snapshot.data!.docs;

                events = events.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final title = (data['title'] ?? '').toString().toLowerCase();
                  final location = (data['location'] ?? '').toString().toLowerCase();
                  final category = (data['category'] ?? '').toString();

                  return (selectedCategory == null || selectedCategory == 'All' || selectedCategory == category) &&
                      (searchQuery.isEmpty || title.contains(searchQuery.toLowerCase()) || location.contains(searchQuery.toLowerCase()));
                }).toList();

                if (sortOrder == 'Newest') {
                  events.sort((a, b) => b['createdAt'].compareTo(a['createdAt']));
                } else if (sortOrder == 'Oldest') {
                  events.sort((a, b) => a['createdAt'].compareTo(b['createdAt']));
                } else if (sortOrder == 'A–Z') {
                  events.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
                }

                if (events.isEmpty) {
                  return const Center(child: Text("No events found."));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final data = events[index].data() as Map<String, dynamic>;
                    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
                    final firstImage = imageUrls.isNotEmpty ? imageUrls[0] : null;
                    final title = data['title'] ?? '';
                    final category = data['category'] ?? '';

                    final AnimationController animController = AnimationController(
                      vsync: this,
                      duration: Duration(milliseconds: 300 + index * 50),
                    );
                    animController.forward();

                    return FadeTransition(
                      opacity: CurvedAnimation(parent: animController, curve: Curves.easeIn),
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animController),
                        child: GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => EventDetailsDialog(docId: events[index].id, data: data),
                          ),
                          child: Card(
                            elevation: 6,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                  child: SizedBox(
                                    height: 180,
                                    child: firstImage != null
                                        ? Image.network(
                                            firstImage,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Image.asset(
                                                'assets/CatsConnect.jpg',
                                                fit: BoxFit.contain,
                                                width: double.infinity,
                                              );
                                            },
                                          )
                                        : Image.asset(
                                            'assets/CatsConnect.jpg',
                                            fit: BoxFit.contain,
                                            width: double.infinity,
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 8),
                                      Chip(
                                        label: Text(category),
                                        backgroundColor: Colors.deepPurple.shade50,
                                        labelStyle: const TextStyle(color: Colors.deepPurple),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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

class EventDetailsDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EventDetailsDialog({Key? key, required this.docId, required this.data}) : super(key: key);

  @override
  _EventDetailsDialogState createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<EventDetailsDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  late String userId;
  List<dynamic> interestedUserIds = [];
  bool isInterested = false;

  @override
  void initState() {
    super.initState();
    userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    interestedUserIds = widget.data['interestedUserIds'] ?? [];
    isInterested = interestedUserIds.contains(userId);

    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    if (widget.data['imageUrls'] != null && (widget.data['imageUrls'] as List).length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (_pageController.hasClients) {
          int nextPage = (_currentPage + 1) % (widget.data['imageUrls'] as List).length;
          _pageController.animateToPage(
            nextPage,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

 Future<void> _toggleInterest() async {
  if (userId.isEmpty) return;

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docRef = FirebaseFirestore.instance.collection('events').doc(widget.docId);

      await docRef.update({
        'interestedUserIds': isInterested
            ? FieldValue.arrayRemove([user.uid])
            : FieldValue.arrayUnion([user.uid]),
        'interestedUserEmails': isInterested
            ? FieldValue.arrayRemove([user.email])
            : FieldValue.arrayUnion([user.email]),
      });

      setState(() {
        isInterested = !isInterested;
        if (isInterested) {
          interestedUserIds.add(userId);
        } else {
          interestedUserIds.remove(userId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isInterested ? 'Marked as Interested' : 'Removed from Interested'),
        ),
      );
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}


  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrls = (widget.data['imageUrls'] as List?)?.cast<String>() ?? [];
    final title = widget.data['title'] ?? 'Untitled';
    final category = widget.data['category'] ?? 'N/A';
    final dateRaw = widget.data['date']?.toString() ?? '';
    final location = widget.data['location'] ?? 'N/A';
    final description = widget.data['description'] ?? '';

    String formattedDate = 'N/A';
    try {
      final parsed = DateTime.parse(dateRaw);
      formattedDate = "${_monthName(parsed.month)} ${parsed.day}, ${parsed.year}";
    } catch (_) {}

    return FadeTransition(
      opacity: _animation,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF8F4FF),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrls.isNotEmpty)
                  Column(
                    children: [
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: imageUrls.length,
                          onPageChanged: (index) => setState(() => _currentPage = index),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (context, error, stackTrace) {
                              return Image.asset(
                                'assets/CatsConnect.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              );
                            },
                          ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imageUrls.length, (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 10 : 6,
                          height: _currentPage == index ? 10 : 6,
                          decoration: BoxDecoration(
                            color: _currentPage == index ? Colors.deepPurple : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        )),
                      ),
                    ],
                  ),
                const SizedBox(height: 20),
                Text(title,
                    style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
                _infoRow("Category", category),
                _infoRow("Date", formattedDate),
                _infoRow("Location", location),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Description:",
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15)),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(description.isNotEmpty ? description : "No description provided.",
                      style: GoogleFonts.poppins(fontSize: 14)),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _toggleInterest,
                  icon: Icon(isInterested ? Icons.favorite : Icons.favorite_border),
                  label: Text(isInterested ? 'Interested ✔' : 'Mark as Interested'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isInterested ? Colors.grey : Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Close", style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "$label: $value",
          style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[800]),
        ),
      ),
    );
  }

  String _monthName(int month) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month];
  }
}
