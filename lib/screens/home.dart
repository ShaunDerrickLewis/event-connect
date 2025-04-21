// lib/screens/home.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:firebase_auth/firebase_auth.dart';


class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String searchQuery = '';
  String? selectedCategory;
  String sortOrder = 'Newest';

  final List<String> categories = ['All', 'Sports', 'Music', 'Tech', 'Art', 'Food', 'Meetup', 'Chico'];
  final List<String> sortOptions = ['Newest', 'Oldest', 'A–Z'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EventConnect')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search by title or location',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory ?? 'All',
                        items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        decoration: const InputDecoration(labelText: 'Category'),
                        onChanged: (value) => setState(() => selectedCategory = value),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: sortOrder,
                        items: sortOptions.map((opt) => DropdownMenuItem(value: opt, child: Text(opt))).toList(),
                        decoration: const InputDecoration(labelText: 'Sort by'),
                        onChanged: (value) => setState(() => sortOrder = value ?? 'Newest'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('events').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                List<QueryDocumentSnapshot> events = snapshot.data!.docs;

                // Filter and sort
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

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 3 / 4,
                  ),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final data = events[index].data() as Map<String, dynamic>;
                    final imageUrls = (data['imageUrls'] as List?)?.cast<String>() ?? [];
                    final firstImage = imageUrls.isNotEmpty ? imageUrls[0] : null;

                    return GestureDetector(
                      onTap: () => showDialog(
                        context: context,
                        builder: (_) => EventDetailsDialog(docId: events[index].id, data: data),
                      ),
                      child: Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            firstImage != null
                                ? ClipRRect(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    child: Image.network(firstImage, height: 140, fit: BoxFit.cover),
                                  )
                                : Container(
                                    height: 140,
                                    decoration: const BoxDecoration(color: Colors.grey),
                                    child: const Icon(Icons.image, size: 40),
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
          ),
        ],
      ),
    );
  }
}

class EventDetailsDialog extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;

  const EventDetailsDialog({super.key, required this.docId, required this.data});

  @override
  State<EventDetailsDialog> createState() => _EventDetailsDialogState();
}

class _EventDetailsDialogState extends State<EventDetailsDialog> {
  late List<String> imageUrls;
  late String userId;
  List<dynamic> interestedUserIds = [];
  bool isInterested = false;

  @override
  void initState() {
    super.initState();
    imageUrls = (widget.data['imageUrls'] as List?)?.cast<String>() ?? [];
    interestedUserIds = widget.data['interestedUserIds'] ?? [];
  userId = FirebaseAuth.instance.currentUser?.uid ?? '';
  isInterested = interestedUserIds.contains(userId);
  
  }

  Future<void> _markAsInterested() async {
  if (userId.isEmpty || isInterested) return;

  try {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
  await FirebaseFirestore.instance.collection('events').doc(widget.docId).update({
    'interestedUserIds': FieldValue.arrayUnion([user.uid]),
    'interestedUserEmails': FieldValue.arrayUnion([user.email]),
  });
}

    setState(() {
      isInterested = true;
      interestedUserIds.add(userId);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('You marked this event as Interested!')),
    );
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to mark interest: $e')),
    );
  }
}

  Future<void> _addImages() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      List<String> newUrls = [];

      for (final file in files) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(file);
        await reader.onLoadEnd.first;

        final data = reader.result as Uint8List;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
        final ref = FirebaseStorage.instance.ref('event_images/$fileName');

        try {
          final uploadTask = await ref.putData(data);
          final downloadUrl = await uploadTask.ref.getDownloadURL();
          newUrls.add(downloadUrl);
        } catch (_) {}
      }

      final updated = [...imageUrls, ...newUrls];
      await FirebaseFirestore.instance.collection('events').doc(widget.docId).update({'imageUrls': updated});
      setState(() => imageUrls = updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.data['title'] ?? '', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text("Category: ${widget.data['category'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            Text("Date: ${widget.data['date'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            Text("Location: ${widget.data['location'] ?? 'N/A'}"),
            const SizedBox(height: 4),
            Text("Description: ${widget.data['description'] ?? 'N/A'}"),
            const SizedBox(height: 12),
            if (imageUrls.isNotEmpty)
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: Image.network(imageUrls[index]),
                  ),
                ),
              )
            else
              const Text("No images yet."),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _addImages,
              child: const Text("Add More Images"),
            ),
            ElevatedButton.icon(
  onPressed: isInterested ? null : _markAsInterested,
  icon: const Icon(Icons.favorite_border),
  label: Text(isInterested ? 'Interested ✔' : 'Mark as Interested'),
),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        ),
      ),
    );
  }
}
