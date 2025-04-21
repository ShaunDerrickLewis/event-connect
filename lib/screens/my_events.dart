import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:typed_data';

class MyEventsPage extends StatefulWidget {
  const MyEventsPage({Key? key}) : super(key: key);

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> {
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Events')),
      body: _userEmail == null
          ? const Center(child: Text("User not logged in"))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('events')
                  .where('email', isEqualTo: _userEmail)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No events found.'));
                }

                final events = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final doc = events[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final images = (data['imageUrls'] as List<dynamic>? ?? []).cast<String>();
                    final firstImage = images.isNotEmpty ? images[0] : null;

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => EventDetailDialog(data: data, docId: doc.id),
                        );
                      },
                      child: Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (firstImage != null)
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.network(
                                  firstImage,
                                  height: 140,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Container(
                                height: 140,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                child: const Center(child: Icon(Icons.image, size: 40)),
                              ),
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(data['category'] ?? '', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class EventDetailDialog extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const EventDetailDialog({Key? key, required this.data, required this.docId}) : super(key: key);

  @override
  State<EventDetailDialog> createState() => _EventDetailDialogState();
}



 class _EventDetailDialogState extends State<EventDetailDialog> {
  late PageController _pageController;
  int _currentImage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _previousImage(int count) {
    if (_currentImage > 0) {
      setState(() => _currentImage--);
      _pageController.animateToPage(
        _currentImage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _nextImage(int count) {
    if (_currentImage < count - 1) {
      setState(() => _currentImage++);
      _pageController.animateToPage(
        _currentImage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showInterestedUsers() async {
    final doc = await FirebaseFirestore.instance.collection('events').doc(widget.docId).get();
    final emails = List<String>.from(doc.data()?['interestedUserEmails'] ?? []);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Interested Users"),
        content: emails.isEmpty
            ? const Text("No one has shown interest yet.")
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: emails.map((e) => Text("- $e")).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = (widget.data['imageUrls'] as List?)?.cast<String>() ?? [];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (images.isNotEmpty)
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    height: 200,
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) => setState(() => _currentImage = index),
                      itemBuilder: (context, index) => ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(images[index], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios),
                      onPressed: () => _previousImage(images.length),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      onPressed: () => _nextImage(images.length),
                    ),
                  ),
                ],
              )
            else
              const SizedBox(height: 200, child: Center(child: Text('No images'))),
            const SizedBox(height: 16),
            Text(widget.data['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Category: ${widget.data['category'] ?? 'N/A'}"),
            Text("Date: ${widget.data['date'] ?? 'N/A'}"),
            Text("Location: ${widget.data['location'] ?? 'N/A'}"),
            Text("Description: ${widget.data['description'] ?? 'N/A'}"),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Close"),
                ),
                ElevatedButton(
                  onPressed: _showInterestedUsers,
                  child: const Text("View Interested"),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditEventPage(
                          docId: widget.docId,
                          existingData: widget.data,
                        ),
                      ),
                    );
                  },
                  child: const Text("Edit"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class EditEventPage extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> existingData;

  const EditEventPage({super.key, required this.docId, required this.existingData});

  @override
  State<EditEventPage> createState() => _EditEventPageState();
}

class _EditEventPageState extends State<EditEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _locationController = TextEditingController();
  String? _category;
  DateTime? _selectedDate;
  List<String> _imageUrls = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final data = widget.existingData;
    _titleController.text = data['title'] ?? '';
    _descController.text = data['description'] ?? '';
    _locationController.text = data['location'] ?? '';
    _category = data['category'];
    _selectedDate = DateTime.tryParse(data['date'] ?? '');
    _imageUrls = List<String>.from(data['imageUrls'] ?? []);
  }

  Future<void> _pickAndUploadImages() async {
    final input = html.FileUploadInputElement();
    input.accept = 'image/*';
    input.multiple = true;
    input.click();

    input.onChange.listen((event) async {
      final files = input.files;
      if (files == null || files.isEmpty) return;

      setState(() => _isLoading = true);

      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;

        final data = reader.result as Uint8List;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref('event_images/$fileName');

        try {
          final task = await ref.putData(data);
          final url = await task.ref.getDownloadURL();
          _imageUrls.add(url);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${file.name}')));
        }
      }

      setState(() => _isLoading = false);
    });
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('events').doc(widget.docId).update({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'location': _locationController.text.trim(),
        'category': _category,
        'date': _selectedDate?.toIso8601String(),
        'imageUrls': _imageUrls,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Event updated!")));
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['Music', 'Sports', 'Art', 'Tech', 'Food', 'Meetup', 'Chico'];

    return Scaffold(
      appBar: AppBar(title: const Text("Edit Event")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(labelText: 'Location'),
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _category,
                      items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (val) => setState(() => _category = val),
                      decoration: const InputDecoration(labelText: 'Category'),
                      validator: (v) => v == null || v.isEmpty ? 'Select one' : null,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _pickAndUploadImages,
                      child: const Text('Add More Images'),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageUrls.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Image.network(_imageUrls[i]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveChanges,
                      child: const Text("Save Changes"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
