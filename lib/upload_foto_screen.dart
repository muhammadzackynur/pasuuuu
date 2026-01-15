import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'konfirmasi_laporan_screen.dart';

class UploadFotoScreen extends StatefulWidget {
  final String lokasi;
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final List<String> teknisi;

  const UploadFotoScreen({
    super.key,
    required this.lokasi,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.teknisi,
  });

  @override
  State<UploadFotoScreen> createState() => _UploadFotoScreenState();
}

class _UploadFotoScreenState extends State<UploadFotoScreen> {
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();
  final int _maxPhotos = 6;

  Future<void> _pickImage() async {
    if (_selectedImages.length >= _maxPhotos) return;
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) setState(() => _selectedImages.add(File(image.path)));
  }

  void _removeImage(int index) =>
      setState(() => _selectedImages.removeAt(index));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Upload Dokumentasi'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _selectedImages.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemBuilder: (context, index) => index < _selectedImages.length
                  ? _uploadedPhoto(index)
                  : _addPhotoButton(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedImages.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Unggah minimal 1 foto")),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KonfirmasiLaporanScreen(
                          lokasi: widget.lokasi,
                          jenisMaintenance: widget.jenisMaintenance,
                          deskripsi: widget.deskripsi,
                          durasi: widget.durasi,
                          teknisi: widget.teknisi,
                          fotoDokumentasi: _selectedImages,
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Lanjut ke Konfirmasi",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uploadedPhoto(int index) => Stack(
    children: [
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          image: DecorationImage(
            image: FileImage(_selectedImages[index]),
            fit: BoxFit.cover,
          ),
        ),
      ),
      Positioned(
        top: 5,
        right: 5,
        child: GestureDetector(
          onTap: () => _removeImage(index),
          child: const CircleAvatar(
            radius: 12,
            backgroundColor: Colors.red,
            child: Icon(Icons.close, color: Colors.white, size: 16),
          ),
        ),
      ),
    ],
  );

  Widget _addPhotoButton() => InkWell(
    onTap: _pickImage,
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.cyan.withOpacity(0.5)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_a_photo, color: Colors.cyan, size: 30),
          Text(
            "Tambah Foto",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    ),
  );
}
