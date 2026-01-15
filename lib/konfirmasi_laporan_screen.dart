import 'dart:io';
import 'package:flutter/material.dart';

class KonfirmasiLaporanScreen extends StatelessWidget {
  final String lokasi;
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final List<String> teknisi;
  final List<File> fotoDokumentasi;

  const KonfirmasiLaporanScreen({
    super.key,
    required this.lokasi,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.teknisi,
    required this.fotoDokumentasi,
  });

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
          'Konfirmasi Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "RINGKASAN LAPORAN",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.location_on,
              title: "LOKASI PEKERJAAN",
              value: lokasi,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.settings,
              title: "JENIS & DURASI",
              value: "$jenisMaintenance • $durasi",
              iconColor: Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildDescriptionCard(
              title: "DESKRIPSI MASALAH",
              content: deskripsi.isEmpty ? "Tidak ada deskripsi" : deskripsi,
            ),
            const SizedBox(height: 12),
            _buildTechnicianCard(teknisi),
            const SizedBox(height: 24),
            _buildPhotoGrid(),
            const SizedBox(height: 30),
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    Color iconColor = Colors.blue,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 10),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDescriptionCard({
    required String title,
    required String content,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _buildTechnicianCard(List<String> names) => Wrap(
    spacing: 8,
    children: names
        .map(
          (n) => Chip(
            label: Text(
              n,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
            backgroundColor: Colors.blue.withOpacity(0.1),
          ),
        )
        .toList(),
  );

  Widget _buildPhotoGrid() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: fotoDokumentasi.length,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
    ),
    itemBuilder: (context, index) => ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(fotoDokumentasi[index], fit: BoxFit.cover),
    ),
  );

  Widget _buildSubmitButton(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 60,
    child: ElevatedButton(
      onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2196F3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: const Text(
        "Kirim Laporan",
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
}
