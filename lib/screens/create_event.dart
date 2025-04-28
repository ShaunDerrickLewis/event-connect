// CREATE_EVENT
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_nav.dart';

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
  bool _placesInitialized = false;
  final List<String> _categories = ['Sports', 'Music', 'Tech', 'Art', 'Food', 'Meetup', 'Chico'];

  static const String _googlePlacesApiKey = "AIzaSyCy9qUApiH7s6bUdShV4w6BiIs_N2Fb3u0";

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userEmail = user.email;
      _emailController.text = _userEmail!;
    }
    _loadGooglePlacesScript();
  }

  void _loadGooglePlacesScript() {
    if (html.document.getElementById('google_places_api') != null) {
      _placesInitialized = true;
      return;
    }
    final script = html.ScriptElement()
      ..id = 'google_places_api'
      ..type = 'text/javascript'
      ..src = 'https://maps.googleapis.com/maps/api/js?key=$_googlePlacesApiKey&libraries=places'
      ..onLoad.listen((event) {
        _placesInitialized = true;
      });
    html.document.head!.append(script);
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
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: ${file.name}')));
          }
        }
      }

      if (mounted) {
        setState(() {
          _uploadedImageUrls = newUrls;
          _imageBytesList = newImages;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Images uploaded')));
      }
    });
  }

  ButtonStyle _buildButtonStyle() {
    return ElevatedButton.styleFrom(
      backgroundColor: Colors.deepPurple.shade50,
      foregroundColor: Colors.deepPurple,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F4FF),
      appBar: AppBar(
        title: Text('Create New Event', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFFF8F4FF),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildInputField(_titleController, 'Event Title'),
                          const SizedBox(height: 16),
                          _buildInputField(_descController, 'Description', maxLines: 3),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: _categories.contains(_selectedCategory) ? _selectedCategory : null,
                            decoration: _buildInputDecoration('Category'),
                            items: _categories.map((e) {
                              return DropdownMenuItem(
                                value: e,
                                child: Text(e, style: GoogleFonts.poppins()),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _selectedCategory = val),
                            validator: (value) => value == null ? 'Please select a category' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _locationController,
                            decoration: _buildInputDecoration('Location').copyWith(
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.search),
                                onPressed: _showPlacesSearchDialog,
                              ),
                              errorText: _locationError,
                            ),
                            readOnly: true,
                            onTap: _showPlacesSearchDialog,
                            validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          _buildInputField(_emailController, 'Contact Email'),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickDate,
                            style: _buildButtonStyle(),
                            icon: const Icon(Icons.calendar_today),
                            label: Text(
                              _selectedDate == null
                                  ? 'Select Date'
                                  : 'Date: ${_selectedDate!.toLocal().toString().split(' ')[0]}',
                              style: GoogleFonts.poppins(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _pickAndUploadImages,
                            icon: const Icon(Icons.upload),
                            label: Text('Upload Images', style: GoogleFonts.poppins()),
                            style: _buildButtonStyle(),
                          ),
                          if (_uploadedImageUrls.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              'Uploaded Images (${_uploadedImageUrls.length})',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _uploadedImageUrls.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black12,
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        _uploadedImageUrls[index],
                                        width: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          const SizedBox(height: 30),
                          ElevatedButton(
                            onPressed: _isLoading ? null : _saveEvent,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Text('Create Event', style: GoogleFonts.poppins(fontSize: 16)),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepPurple,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
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
        const SnackBar(content: Text('🎉 Event created successfully!')),
      );

      _formKey.currentState?.reset();
      setState(() {
        _selectedCategory = null;
        _selectedDate = null;
        _locationController.clear();
        _uploadedImageUrls.clear();
        _imageBytesList.clear();
        _locationError = null;
      });

      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
      Navigator.of(context).pushReplacement(  
        MaterialPageRoute(builder: (context) => const MainNav()), // << and this!
      );
    }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPlacesSearchDialog() {
    final dialogKey = 'places_dialog_${DateTime.now().millisecondsSinceEpoch}';
    final inputId = 'autocomplete_input_${DateTime.now().millisecondsSinceEpoch}';

    final overlayDiv = html.DivElement()
      ..id = dialogKey
      ..style.position = 'fixed'
      ..style.top = '0'
      ..style.left = '0'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = 'rgba(0, 0, 0, 0.5)'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.zIndex = '10000';

    final cardDiv = html.DivElement()
      ..style.width = '90%'
      ..style.maxWidth = '400px'
      ..style.backgroundColor = '#fff'
      ..style.borderRadius = '12px'
      ..style.padding = '20px'
      ..style.boxShadow = '0 4px 16px rgba(0,0,0,0.2)'
      ..style.display = 'flex'
      ..style.flexDirection = 'column';

    final title = html.HeadingElement.h3()
      ..text = 'Search for Location'
      ..style.marginBottom = '12px'
      ..style.fontFamily = 'sans-serif';

    final input = html.InputElement()
      ..id = inputId
      ..placeholder = 'Start typing...'
      ..style.padding = '10px'
      ..style.fontSize = '16px'
      ..style.borderRadius = '6px'
      ..style.border = '1px solid #ccc';

    final buttonRow = html.DivElement()
      ..style.marginTop = '16px'
      ..style.display = 'flex'
      ..style.justifyContent = 'flex-end';

    final cancelBtn = html.ButtonElement()
      ..text = 'Cancel'
      ..style.marginRight = '10px'
      ..onClick.listen((_) => overlayDiv.remove());

    final confirmBtn = html.ButtonElement()
      ..text = 'Confirm'
      ..onClick.listen((_) {
        if (input.value != null && input.value!.trim().isNotEmpty) {
          setState(() {
            _locationController.text = input.value!.trim();
            _locationError = null;
          });
          overlayDiv.remove();
        }
      });

    buttonRow.append(cancelBtn);
    buttonRow.append(confirmBtn);

    cardDiv.append(title);
    cardDiv.append(input);
    cardDiv.append(buttonRow);
    overlayDiv.append(cardDiv);
    html.document.body!.append(overlayDiv);

    js.context.callMethod('eval', [
      '''
      setTimeout(() => {
        const input = document.getElementById('$inputId');
        const autocomplete = new google.maps.places.Autocomplete(input);

        const observer = new MutationObserver((mutations) => {
          document.querySelectorAll('.pac-container').forEach(el => {
            el.style.zIndex = '10001';
          });
        });
        observer.observe(document.body, { childList: true, subtree: true });

        autocomplete.addListener('place_changed', () => {
          const place = autocomplete.getPlace();
          if (place.formatted_address) {
            window.selectPlace(place.formatted_address);
            document.getElementById('$dialogKey')?.remove();
            observer.disconnect();
          }
        });

        input.focus();
      }, 100);
      '''
    ]);
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: GoogleFonts.poppins(color: Colors.grey[800]),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.deepPurple),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, {bool readOnly = false, int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      decoration: _buildInputDecoration(label),
      validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
    );
  }
}