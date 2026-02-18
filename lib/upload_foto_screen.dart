import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'konfirmasi_laporan_screen.dart';

class UploadFotoScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

  // Data Form
  final String area;
  final String district;
  final String witel;
  final String sto;
  final String mitraPelaksana;
  final String kategoriKegiatan;
  final String uraianPekerjaan;
  final List<String> teknisi;

  const UploadFotoScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
    required this.area,
    required this.district,
    required this.witel,
    required this.sto,
    required this.mitraPelaksana,
    required this.kategoriKegiatan,
    required this.uraianPekerjaan,
    required this.teknisi,
  });

  @override
  State<UploadFotoScreen> createState() => _UploadFotoScreenState();
}

class _UploadFotoScreenState extends State<UploadFotoScreen> {
  File? _imageBefore;
  File? _imageProgress;
  File? _imageAfter;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(String type) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40, // Kompresi agar upload lebih cepat
    );

    if (pickedFile != null) {
      setState(() {
        if (type == "before") _imageBefore = File(pickedFile.path);
        if (type == "progress") _imageProgress = File(pickedFile.path);
        if (type == "after") _imageAfter = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Upload Foto',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildUploadCard("Foto Before", _imageBefore, "before"),
            const SizedBox(height: 20),
            _buildUploadCard("Foto Progress", _imageProgress, "progress"),
            const SizedBox(height: 20),
            _buildUploadCard("Foto After", _imageAfter, "after"),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (_imageBefore == null ||
                      _imageProgress == null ||
                      _imageAfter == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Semua foto wajib diupload!"),
                      ),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KonfirmasiLaporanScreen(
                        userName: widget.userName,
                        role: widget.role,
                        userId: widget.userId,
                        databaseId: widget.databaseId,
                        area: widget.area,
                        district: widget.district,
                        witel: widget.witel,
                        sto: widget.sto,
                        mitraPelaksana: widget.mitraPelaksana,
                        kategoriKegiatan: widget.kategoriKegiatan,
                        uraianPekerjaan: widget.uraianPekerjaan,
                        teknisi: widget.teknisi,
                        fotoBefore: _imageBefore!,
                        fotoProgress: _imageProgress!,
                        fotoAfter: _imageAfter!,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "Review Laporan",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadCard(String label, File? image, String type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _pickImage(type),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue.withOpacity(0.5), width: 1),
            ),
            child: image == null
                ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt, color: Colors.blue, size: 40),
                      SizedBox(height: 8),
                      Text(
                        "Ketuk untuk ambil foto",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ],
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
