import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'konfirmasi_laporan_screen.dart';

class UploadFotoScreen extends StatefulWidget {
  final String lokasi;
  final double? lat; // Parameter lat
  final double? lng; // Parameter lng
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final String tanggal;
  final List<String> teknisi;

  const UploadFotoScreen({
    super.key,
    required this.lokasi,
    this.lat,
    this.lng,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.tanggal,
    required this.teknisi,
  });

  @override
  State<UploadFotoScreen> createState() => _UploadFotoScreenState();
}

class _UploadFotoScreenState extends State<UploadFotoScreen> {
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) setState(() => _selectedImages.add(File(image.path)));
  }

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
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.file(
                        _selectedImages[index],
                        fit: BoxFit.cover,
                      ),
                    )
                  : InkWell(
                      onTap: _pickImage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Icon(
                          Icons.add_a_photo,
                          color: Colors.cyan,
                        ),
                      ),
                    ),
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
                          lat: widget.lat,
                          lng: widget.lng, // Teruskan koordinat
                          jenisMaintenance: widget.jenisMaintenance,
                          deskripsi: widget.deskripsi,
                          durasi: widget.durasi,
                          tanggal: widget.tanggal,
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
}
