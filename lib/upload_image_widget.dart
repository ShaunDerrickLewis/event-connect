import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UploadImageWidget extends StatefulWidget {
  @override
  _UploadImageWidgetState createState() => _UploadImageWidgetState();
}

class _UploadImageWidgetState extends State<UploadImageWidget> {
  PlatformFile? _pickedFile;
  String? _downloadURL;
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _pickedFile = result.files.single;
        _downloadURL = null;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No image selected')),
      );
    }
  }

  Future<void> _uploadImage() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select an image first')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final storageRef = FirebaseStorage.instance.ref().child('uploads/${_pickedFile!.name}');

      final blob = html.Blob([_pickedFile!.bytes!]);
      final uploadTask = storageRef.putBlob(blob);

      final snapshot = await uploadTask.whenComplete(() => {});
      final url = await snapshot.ref.getDownloadURL();

      setState(() {
        _downloadURL = url;
        _isUploading = false;
      });

      print('Upload complete! URL: $url');
    } catch (e, stack) {
      print('Upload failed: $e');
      print(stack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );

      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _pickImage,
          child: Text('Select Image'),
        ),
        if (_pickedFile != null) Text('Selected: ${_pickedFile!.name}'),
        if (_pickedFile != null)
          ElevatedButton(
            onPressed: _isUploading ? null : _uploadImage,
            child: Text(_isUploading ? 'Uploading...' : 'Upload to Firebase'),
          ),
        if (_downloadURL != null)
          Column(
            children: [
              SizedBox(height: 10),
              Text('Uploaded Image Preview:'),
              Image.network(_downloadURL!),
            ],
          ),
      ],
    );
  }
}
