import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui' as ui;

bool _locationInputRegistered = false;

void registerLocationInputFactory(TextEditingController locationController) {
  if (!_locationInputRegistered) {
    ui.platformViewRegistry.registerViewFactory(
      'location-input-html',
      (int viewId) {
        final input = html.InputElement()
          ..id = 'location_input'
          ..placeholder = 'Enter location...'
          ..tabIndex = 0
          ..setAttribute('data-semantics', 'input')
          ..style.padding = '16px'
          ..style.fontSize = '16px'
          ..style.width = '100%'
          ..style.height = '56px'
          ..style.backgroundColor = '#F8F4FF'
          ..style.border = '1px solid #000000'
          ..style.borderRadius = '12px'
          ..style.color = '#000000'
          ..style.boxShadow = 'none'
          ..style.outline = 'none'
          ..style.boxSizing = 'border-box'
          ..value = locationController.text;

        input.onInput.listen((event) {
          locationController.text = input.value ?? '';
        });

        // ✅ Focus input slightly after it is rendered
        Future.delayed(const Duration(milliseconds: 100), () {
          input.focus();
        });

        js.context.callMethod('eval', [''' 
          setTimeout(() => {
            const input = document.getElementById('location_input');
            if (input) {
              const autocomplete = new google.maps.places.Autocomplete(input);
              autocomplete.addListener('place_changed', () => {
                const place = autocomplete.getPlace();
                if (place.formatted_address) {
                  input.value = place.formatted_address;
                }
              });
            }
          }, 500);
        ''']);

        return input;
      },
    );
    _locationInputRegistered = true;
  }
}


class MyEventsPage extends StatefulWidget {
  const MyEventsPage({Key? key}) : super(key: key);

  @override
  State<MyEventsPage> createState() => _MyEventsPageState();
}

class _MyEventsPageState extends State<MyEventsPage> with SingleTickerProviderStateMixin {
  String? _userEmail;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _userEmail = FirebaseAuth.instance.currentUser?.email;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        title: const Text('My Events', style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFF8F4FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
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
                  return _buildNoEventsFound();
                }

                final events = snapshot.data!.docs;

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 3/4,
                  ),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    final doc = events[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final images = (data['imageUrls'] as List<dynamic>? ?? []).cast<String>();
                    final firstImage = images.isNotEmpty ? images[0] : null;

                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _animationController,
                        curve: Interval(
                          (index / events.length),
                          1.0,
                          curve: Curves.easeIn,
                        ),
                      ),
                      child: GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => EventDetailDialog(data: data, docId: doc.id),
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.deepPurple.shade100,
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                child: firstImage != null
                                    ? Image.network(
                                        firstImage,
                                        height: 150,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            height: 150,
                                            color: Colors.deepPurple.shade50,
                                            child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.deepPurple)),
                                          );
                                        },
                                      )
                                    : Container(
                                        height: 150,
                                        color: Colors.deepPurple.shade50,
                                        child: const Center(child: Icon(Icons.image, size: 40, color: Colors.deepPurple)),
                                      ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      data['title'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        data['category'] ?? '',
                                        style: const TextStyle(
                                          color: Colors.deepPurple,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildNoEventsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.event_busy, size: 80, color: Colors.deepPurple),
          SizedBox(height: 16),
          Text('No events found!', style: TextStyle(fontSize: 18, color: Colors.black87)),
        ],
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
        backgroundColor: const Color(0xFFF8F4FF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Interested Users", style: TextStyle(color: Colors.black)),
        content: emails.isEmpty
            ? const Text("No one has shown interest yet.", style: TextStyle(color: Colors.black87))
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: emails.map((e) => Text("- $e", style: const TextStyle(color: Colors.black87))).toList(),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Close", style: TextStyle(color: Colors.deepPurple)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final images = (widget.data['imageUrls'] as List?)?.cast<String>() ?? [];
    final title = widget.data['title'] ?? '';
    final category = widget.data['category'] ?? 'N/A';
    final date = widget.data['date'] ?? 'N/A';
    final location = widget.data['location'] ?? 'N/A';
    final description = widget.data['description'] ?? 'N/A';

    return Dialog(
      backgroundColor: const Color(0xFFF8F4FF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          images[index],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.deepPurple.shade50,
                              child: const Center(child: Icon(Icons.broken_image, size: 40, color: Colors.deepPurple)),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.deepPurple),
                      onPressed: () => _previousImage(images.length),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.deepPurple),
                      onPressed: () => _nextImage(images.length),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.deepPurple.shade50,
                ),
                child: const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.deepPurple)),
              ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.category, "Category", category),
            _buildInfoRow(Icons.calendar_today, "Date", date),
            _buildInfoRow(Icons.location_on, "Location", location),
            const SizedBox(height: 16),
            Text(
              "Description",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepPurple.shade400),
            ),
            const SizedBox(height: 8),
            Text(
              description.isNotEmpty ? description : 'No description provided.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
           Column(
             children: [
               Wrap(
                 alignment: WrapAlignment.center,
                 spacing: 12,
                 runSpacing: 8,
                 children: [
                   ElevatedButton(
                     onPressed: _showInterestedUsers,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.deepPurple,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: const Text("View Interested Users", style: TextStyle(fontSize: 14)),
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
                     style: ElevatedButton.styleFrom(
                       backgroundColor: Colors.indigo,
                       foregroundColor: Colors.white,
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     ),
                     child: const Text("Edit", style: TextStyle(fontSize: 14)),
                   ),
                 ],
               ),
               const SizedBox(height: 16),
               Center(
                 child: ElevatedButton(
                   onPressed: () => Navigator.of(context).pop(),
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.grey,
                     foregroundColor: Colors.white,
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                   ),
                   child: const Text("Close", style: TextStyle(fontSize: 14)),
                 ),
               ),
             ],
           ),
          ],
        ),
      ),
    );
  }

Widget _buildInfoRow(IconData icon, String label, String value) {
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8),
      color: Colors.deepPurple.shade50,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(width: 8),
        Icon(icon, size: 20, color: Colors.deepPurple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$label:",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(color: Colors.black87),
                softWrap: true,
                overflow: TextOverflow.visible,
              ),
            ],
          ),
        ),
      ],
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
    _loadGooglePlacesScript();
    final data = widget.existingData;
    _titleController.text = data['title'] ?? '';
    _descController.text = data['description'] ?? '';
    _locationController.text = data['location'] ?? '';
    _category = data['category'];
    _selectedDate = DateTime.tryParse(data['date'] ?? '');
    _imageUrls = List<String>.from(data['imageUrls'] ?? []);
    registerLocationInputFactory(_locationController);
    _locationController.addListener(() {
      setState(() {});  // Rebuild when location text changes
    });

  }

  void _loadGooglePlacesScript() {
    if (html.document.getElementById('google_places_api') != null) {
      return;
    }
    final script = html.ScriptElement()
      ..id = 'google_places_api'
      ..type = 'text/javascript'
      ..src = 'https://maps.googleapis.com/maps/api/js?key=AIzaSyCy9qUApiH7s6bUdShV4w6BiIs_N2Fb3u0&libraries=places';
    html.document.head!.append(script);
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Event updated successfully!', style: TextStyle(color: Colors.white))),
              ],
            ),
            backgroundColor: Colors.deepPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: ${e.toString()}"),
          backgroundColor: Colors.redAccent,
        ),
      );
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
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        title: const Text("Edit Event", style: TextStyle(color: Colors.black)),
        backgroundColor: const Color(0xFFF8F4FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildTextField(_titleController, "Event Title"),
                        const SizedBox(height: 16),
                        _buildTextField(_descController, "Description", maxLines: 3),
                        const SizedBox(height: 16),
                        _buildLocationField(),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          value: _category,
                          items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) => setState(() => _category = val),
                          decoration: InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'Please select a category' : null,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickDate,
                          label: Text(
                            _selectedDate == null
                                ? 'Select Date'
                                : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            side: BorderSide(color: Colors.deepPurple.shade200),
                          ),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.upload),
                          onPressed: _pickAndUploadImages,
                          label: const Text('Upload Images'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            side: BorderSide(color: Colors.deepPurple.shade200),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildImagePreview(),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _saveChanges,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                          ),
                          child: const Text(
                            "Save Changes",
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  Widget _buildLocationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_locationController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 4, left: 8),
            child: Text(
              "Location",
              style: TextStyle(
                fontSize: 12,
                color: Colors.deepPurple.shade400,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.deepPurple.shade200),
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF8F4FF),
          ),
          child: const HtmlElementView(
            viewType: 'location-input-html',
          ),
        ),
      ],
    );
  }


  static void _allowKeyboardEvents(int viewId) {
    html.document.getElementById('location_input')?.focus();
  }


Widget _buildImagePreview() {
  if (_imageUrls.isEmpty) {
    return const SizedBox.shrink();
  }

  return SizedBox(
    height: 100,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: _imageUrls.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                _imageUrls[i],
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 100,
                    height: 100,
                    color: Colors.deepPurple.shade50,
                    child: const Icon(Icons.broken_image, size: 30, color: Colors.deepPurple),
                  );
                },
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _imageUrls.removeAt(i);
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

}
