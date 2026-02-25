import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({super.key});

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  File? _image;
  final _textController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Seniors usually prefer the camera over browsing files
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 50,
    );
    if (pickedFile != null) setState(() => _image = File(pickedFile.path));
  }

  Future<void> _uploadMemory() async {
    if (_image == null || _textController.text.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      // Replace with your actual local IP (e.g., 192.168.1.XX) or localhost for emulator
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('http://10.0.0.177:8000/api/upload'),
      );

      request.fields['description'] = _textController.text;
      request.files.add(
        await http.MultipartFile.fromPath('file', _image!.path),
      );

      var response = await request.send();

      if (response.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Memory Shared!")));
        setState(() {
          _image = null;
          _textController.clear();
        });
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add to Library', style: TextStyle(fontSize: 24)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 250,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: _image == null
                    ? const Icon(
                        Icons.add_a_photo,
                        size: 100,
                        color: Colors.blue,
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _textController,
              maxLines: 3,
              style: const TextStyle(fontSize: 20),
              decoration: const InputDecoration(
                labelText: 'What is this memory?',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isUploading ? null : _uploadMemory,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 80),
                backgroundColor: Colors.green,
              ),
              child: _isUploading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'Send to Family',
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
