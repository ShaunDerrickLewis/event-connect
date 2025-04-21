import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:ui' as ui;

class CreateEventPage extends StatefulWidget {
  const CreateEventPage({Key? key}) : super(key: key);

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _emailController = TextEditingController();
  final _locationController = TextEditingController();

  DateTime? _selectedDate;
  String? _selectedCategory;
  String? _userEmail;
  List<Uint8List> _imageBytesList = [];
  List<String> _uploadedImageUrls = [];
  String? _locationError;
  bool _isLoading = false;
  String _placesElementId = 'google_places_container';
  bool _placesInitialized = false;

  final List<String> _categories = [
  'Sports', 'Music', 'Tech', 'Art', 'Food', 'Meetup', 'Chico'
];

  // Google Places API Key
  static const String _googlePlacesApiKey = "AIzaSyCy9qUApiH7s6bUdShV4w6BiIs_N2Fb3u0";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email;
      _emailController.text = _userEmail!;
    }

    // Load Google Places API script
    _loadGooglePlacesScript();
  }

  void _loadGooglePlacesScript() {
    if (html.document.getElementById('google_places_api') != null) {
      // Script already loaded
      _initPlacesAutocomplete();
      return;
    }

    final script = html.ScriptElement()
      ..id = 'google_places_api'
      ..type = 'text/javascript'
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$_googlePlacesApiKey&libraries=places'
      ..onLoad.listen((event) {
        _initPlacesAutocomplete();
      });

    html.document.head!.append(script);
  }

  void _initPlacesAutocomplete() {
    js.context['selectPlace'] = (place) {
      if (mounted) {
        setState(() {
          _locationController.text = place;
          if (_locationError != null) {
            _locationError = null;
          }
        });
      }
    };

    // This will be called when the places element is ready
    _placesInitialized = true;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _emailController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    final uploadInput = html.FileUploadInputElement();
    uploadInput.accept = 'image/*';
    uploadInput.multiple = true;
    uploadInput.click();

    uploadInput.onChange.listen((event) async {
      final files = uploadInput.files;
      if (files == null || files.isEmpty) return;

      List<String> newUrls = [];
      List<Uint8List> newImages = [];

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
          newImages.add(data);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Upload failed: ${file.name}')),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _uploadedImageUrls = newUrls;
          _imageBytesList = newImages;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Images uploaded')),
        );
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  void _showPlacesSearchDialog() {
    // Create unique ID for this search instance
    final searchId = 'places_search_${DateTime.now().millisecondsSinceEpoch}';
    
    // Create the HTML element
    final searchDiv = html.DivElement()
      ..id = searchId
      ..style.width = '400px'
      ..style.height = '50px';
    
    final searchInput = html.InputElement()
      ..id = '${searchId}_input'
      ..style.width = '100%'
      ..style.height = '40px'
      ..style.padding = '8px'
      ..style.fontSize = '16px'
      ..style.borderRadius = '4px'
      ..style.border = '1px solid #ccc'
      ..placeholder = 'Search for a location...';
    
    searchDiv.append(searchInput);
    
    html.document.body!.append(searchDiv);
    
    // Initialize Google Places Autocomplete
    js.context.callMethod('eval', ['''
      (function() {
        function initAutocomplete() {
          const input = document.getElementById('${searchId}_input');
          const autocomplete = new google.maps.places.Autocomplete(input);
          autocomplete.addListener('place_changed', function() {
            const place = autocomplete.getPlace();
            if (place.formatted_address) {
              window.selectPlace(place.formatted_address);
              // Close dialog
              document.getElementById('${searchId}').remove();
            }
          });
        }
        
        if (typeof google !== 'undefined' && google.maps && google.maps.places) {
          initAutocomplete();
          // Focus the input
          setTimeout(() => document.getElementById('${searchId}_input').focus(), 100);
        } else {
          console.error('Google Places API not loaded yet');
        }
      })();
    ''']);
    
    // Show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Search Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please use the search box that appeared on the page to find a location.'),
              const SizedBox(height: 16),
              if (_locationController.text.isNotEmpty)
                Text('Current: ${_locationController.text}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Remove the HTML element when closing dialog
                html.document.getElementById(searchId)?.remove();
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (_locationController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a location')),
                  );
                  return;
                }
                // Remove the HTML element when closing dialog
                html.document.getElementById(searchId)?.remove();
                Navigator.of(context).pop();
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    ).then((_) {
      // Ensure element is removed if dialog is dismissed
      html.document.getElementById(searchId)?.remove();
    });
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final location = _locationController.text.trim();

    if (location.isEmpty) {
      setState(() => _locationError = 'Please enter a location');
      return;
    }

    if (_uploadedImageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('events').add({
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedCategory,
        'location': location,
        'date': _selectedDate?.toIso8601String(),
        'organizerId': FirebaseAuth.instance.currentUser?.uid,
        'email': _userEmail,
        'createdAt': FieldValue.serverTimestamp(),
        'imageUrls': _uploadedImageUrls,
        'interestedUsers': [],
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event created successfully!')),
      );

      _formKey.currentState?.reset();
      setState(() {
        _selectedCategory = null;
        _selectedDate = null;
        _locationController.text = '';
        _uploadedImageUrls.clear();
        _imageBytesList.clear();
        _locationError = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('>> Selected category: $_selectedCategory');
debugPrint('>> Available categories: $_categories');
debugPrint('>> Matching: ${_categories.where((e) => e == _selectedCategory).toList()}');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Event'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveEvent,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Event Title',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    DropdownButtonFormField<String>(
  value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
  decoration: const InputDecoration(
    labelText: 'Category',
    border: OutlineInputBorder(),
  ),
  items: _categories.toSet().map((e) => DropdownMenuItem(
    value: e,
    child: Text(e),
  )).toList(),
  onChanged: (value) {
    setState(() {
      _selectedCategory = value;
    });
  },
  validator: (value) =>
      value == null ? 'Please select a category' : null,
),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: InputDecoration(
                        labelText: 'Location',
                        errorText: _locationError,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: _showPlacesSearchDialog,
                        ),
                      ),
                      readOnly: true,
                      onTap: _showPlacesSearchDialog,
                      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Contact Email',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _pickDate,
                      child: Text(
                        _selectedDate == null
                            ? 'Select Date'
                            : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: _pickAndUploadImages,
                      child: const Text('Upload Images'),
                    ),
                    if (_uploadedImageUrls.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Uploaded Images (${_uploadedImageUrls.length})',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _uploadedImageUrls.length,
                          itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Image.network(_uploadedImageUrls[index]),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveEvent,
                      child: const Text('Create Event'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}