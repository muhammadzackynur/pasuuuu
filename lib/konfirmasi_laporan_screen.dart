import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class KonfirmasiLaporanScreen extends StatefulWidget {
  final String lokasi;
  final double? lat;
  final double? lng;
  final String jenisMaintenance;
  final String deskripsi;
  final String durasi;
  final String tanggal;
  final List<String> teknisi;
  final List<File> fotoBefore;
  final List<File> fotoProgress;
  final List<File> fotoAfter;

  const KonfirmasiLaporanScreen({
    super.key,
    required this.lokasi,
    this.lat,
    this.lng,
    required this.jenisMaintenance,
    required this.deskripsi,
    required this.durasi,
    required this.tanggal,
    required this.teknisi,
    required this.fotoBefore,
    required this.fotoProgress,
    required this.fotoAfter,
  });

  @override
  State<KonfirmasiLaporanScreen> createState() =>
      _KonfirmasiLaporanScreenState();
}

class _KonfirmasiLaporanScreenState extends State<KonfirmasiLaporanScreen> {
  String _detailAlamat = "Sedang mengambil data alamat...";

  @override
  void initState() {
    super.initState();
    if (widget.lat != null && widget.lng != null) {
      _getAddressFromLatLng();
    }
  }

  Future<void> _getAddressFromLatLng() async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.lat!,
        widget.lng!,
      );
      Placemark place = placemarks[0];
      setState(() {
        _detailAlamat =
            "Kota: ${place.subAdministrativeArea}\n"
            "Kecamatan: ${place.locality}\n"
            "Desa/Kel: ${place.subLocality}";
      });
    } catch (e) {
      setState(() => _detailAlamat = "Gagal memuat alamat.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Konfirmasi Laporan'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryHeader(),
            const SizedBox(height: 20),
            _buildMapSection(),
            const SizedBox(height: 20),
            _buildPhotoCategory("DOKUMENTASI BEFORE", widget.fotoBefore),
            const SizedBox(height: 15),
            _buildPhotoCategory("DOKUMENTASI PROGRESS", widget.fotoProgress),
            const SizedBox(height: 15),
            _buildPhotoCategory("DOKUMENTASI AFTER", widget.fotoAfter),
            const SizedBox(height: 30),
            _buildSubmitButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryHeader() {
    return Column(
      children: [
        _buildInfoCard(
          Icons.calendar_month,
          "TIME PLAN",
          widget.tanggal,
          Colors.green,
        ),
        const SizedBox(height: 12),
        _buildInfoCard(
          Icons.settings,
          "MAINTENANCE",
          widget.jenisMaintenance,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.lat != null && widget.lng != null)
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(widget.lat!, widget.lng!),
                  zoom: 15,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId("lokasi"),
                    position: LatLng(widget.lat!, widget.lng!),
                  ),
                },
              ),
            ),
          ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _detailAlamat,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoCategory(String title, List<File> images) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(images[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String title,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 15),
          Column(
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2196F3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
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
}
