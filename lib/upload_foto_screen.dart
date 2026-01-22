import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'konfirmasi_laporan_screen.dart';

class UploadFotoScreen extends StatefulWidget {
  final String lokasi;
  final double? lat;
  final double? lng;
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
  final List<File> _imagesBefore = [];
  final List<File> _imagesProgress = [];
  final List<File> _imagesAfter = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(List<File> targetList) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
    );
    if (image != null) {
      setState(() {
        targetList.add(File(image.path));
      });
    }
  }

  void _removeImage(List<File> targetList, int index) {
    setState(() {
      targetList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Upload Dokumentasi',
          style: TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUploadSection("Foto Before", _imagesBefore),
            const SizedBox(height: 25),
            _buildUploadSection("Foto Progress", _imagesProgress),
            const SizedBox(height: 25),
            _buildUploadSection("Foto After", _imagesAfter),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  if (_imagesBefore.isEmpty ||
                      _imagesProgress.isEmpty ||
                      _imagesAfter.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Lengkapi semua foto (Before, Progress, dan After)",
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => KonfirmasiLaporanScreen(
                          lokasi: widget.lokasi,
                          lat: widget.lat,
                          lng: widget.lng,
                          jenisMaintenance: widget.jenisMaintenance,
                          deskripsi: widget.deskripsi,
                          durasi: widget.durasi,
                          tanggal: widget.tanggal,
                          teknisi: widget.teknisi,
                          fotoBefore: _imagesBefore,
                          fotoProgress: _imagesProgress,
                          fotoAfter: _imagesAfter,
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
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSection(String title, List<File> currentList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: currentList.length + 1,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemBuilder: (context, index) {
            if (index < currentList.length) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: FileImage(currentList[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => _removeImage(currentList, index),
                      child: const CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Icon(Icons.close, size: 12, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              return GestureDetector(
                onTap: () => _pickImage(currentList),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.cyan.withOpacity(0.5)),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.cyan, size: 28),
                      SizedBox(height: 4),
                      Text(
                        "Tambah",
                        style: TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ],
    );
  }
}
