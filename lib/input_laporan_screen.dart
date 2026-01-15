import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'upload_foto_screen.dart';

class InputLaporanScreen extends StatefulWidget {
  const InputLaporanScreen({super.key});

  @override
  State<InputLaporanScreen> createState() => _InputLaporanScreenState();
}

class _InputLaporanScreenState extends State<InputLaporanScreen> {
  final TextEditingController _locationController = TextEditingController(
    text: "Gedung Parkir Lt. 3",
  );
  final TextEditingController _descriptionController = TextEditingController();
  bool _isGettingLocation = false;
  String? _selectedMaintenance;
  String _selectedDuration = "2 Jam";

  final List<String> _maintenanceOptions = [
    "DISMALTING TIANG",
    "SISIP TIANG (SOK)",
    "TIANG ROBOH/KEROPOS/BENGKOK/PATAH/MIRING",
    "GANTI BATERAI",
    "PEMBUATAN KERANGKENG ODC/OLT",
    "PENAMBAHAN BANDWITH UPLINK OLT",
    "PERBAIKAN CRC COUNTING",
    "PERBAIKAN T-LINE / UPLINK",
    "GANTI ODP",
    "GANTI PASSIVE SPLITTER",
    "GANTI BASEDTRAY",
    "GANTI KABINET ODC",
    "MH/HH RUSAK",
    "KU TERJUNTAI/JATUH",
    "PERBAIKAN UC",
    "REPAIR FEEDER/DISTRIBUSI",
    "PENEGAKAN ODC",
    "PENINGGIAN KU",
    "RELOKASI ALPRO",
    "TAMBAH TIANG",
  ];

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever)
        throw 'Izin lokasi ditolak permanen.';

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      String mapUrl =
          "https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}";

      setState(() => _locationController.text = mapUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lokasi GPS berhasil diambil!")),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Gagal mengambil lokasi: $e")));
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _openGoogleMaps() async {
    final String currentText = _locationController.text;
    Uri url = currentText.startsWith('http')
        ? Uri.parse(currentText)
        : Uri.parse(
            "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(currentText)}",
          );

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak dapat membuka Google Maps.")),
      );
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
          'Input Laporan',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFieldLabel("Lokasi Pekerjaan"),
            _buildLocationInput(),
            const SizedBox(height: 20),
            _buildFieldLabel("Jenis Maintenance"),
            _buildMaintenanceDropdown(),
            const SizedBox(height: 20),
            _buildFieldLabel("Deskripsi Masalah"),
            _buildTextArea(
              hint: "Jelaskan detail masalah di sini...",
              controller: _descriptionController,
            ),
            const SizedBox(height: 20),
            _buildFieldLabel("Teknisi"),
            Wrap(
              spacing: 8,
              children: [
                _buildTechChip("Budi Santoso"),
                _buildTechChip("Ahmad Yani"),
                _buildAddChip(),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UploadFotoScreen(
                      lokasi: _locationController.text,
                      jenisMaintenance: _selectedMaintenance ?? "Belum Dipilih",
                      deskripsi: _descriptionController.text,
                      durasi: _selectedDuration,
                      teknisi: const ["Budi Santoso", "Ahmad Yani"],
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "Lanjut ke Upload Foto",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(Icons.arrow_forward, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(color: Colors.grey, fontSize: 14),
    ),
  );

  Widget _buildLocationInput() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: TextField(
      controller: _locationController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: IconButton(
          icon: const Icon(Icons.location_on, color: Colors.blue),
          onPressed: _openGoogleMaps,
        ),
        hintText: "Lokasi atau Link Maps",
        border: InputBorder.none,
        suffixIcon: IconButton(
          icon: _isGettingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.gps_fixed, color: Colors.blue),
          onPressed: _getCurrentLocation,
        ),
      ),
    ),
  );

  Widget _buildMaintenanceDropdown() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1E293B),
      value: _selectedMaintenance,
      hint: const Text(
        "Pilih Jenis Maintenance",
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        icon: Icon(Icons.build, color: Colors.blue),
        border: InputBorder.none,
      ),
      items: _maintenanceOptions
          .map(
            (e) => DropdownMenuItem(
              value: e,
              child: Text(e, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (val) => setState(() => _selectedMaintenance = val),
    ),
  );

  Widget _buildTextArea({
    required String hint,
    required TextEditingController controller,
  }) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: TextField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey),
        border: InputBorder.none,
      ),
    ),
  );

  Widget _buildTechChip(String name) => Chip(
    backgroundColor: const Color(0xFF1E293B),
    label: Text(
      name,
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.blue),
    ),
  );
  Widget _buildAddChip() => ActionChip(
    backgroundColor: Colors.transparent,
    label: const Text(
      "Tambah",
      style: TextStyle(color: Colors.grey, fontSize: 12),
    ),
    avatar: const Icon(Icons.add, color: Colors.grey, size: 16),
    onPressed: () {},
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: const BorderSide(color: Colors.grey),
    ),
  );
}
