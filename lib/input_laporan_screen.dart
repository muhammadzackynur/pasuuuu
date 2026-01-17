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
  final TextEditingController _dateController = TextEditingController();

  bool _isGettingLocation = false;
  String? _selectedMaintenance;
  String _selectedDuration = "2 Jam";
  DateTime? _selectedDate;

  // Variabel untuk menyimpan koordinat GPS murni
  double? _currentLat;
  double? _currentLng;

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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied)
        permission = await Geolocator.requestPermission();

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Simpan koordinat murni
      _currentLat = position.latitude;
      _currentLng = position.longitude;

      setState(
        () => _locationController.text =
            "https://www.google.com/maps?q=${position.latitude},${position.longitude}",
      );

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1424),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
            _buildFieldLabel("Time Plan (Tanggal Pekerjaan)"),
            _buildDateInput(),
            const SizedBox(height: 20),
            _buildFieldLabel("Deskripsi Masalah"),
            _buildTextArea(
              hint: "Jelaskan detail masalah...",
              controller: _descriptionController,
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
                      lat: _currentLat, // Kirim lat
                      lng: _currentLng, // Kirim lng
                      jenisMaintenance: _selectedMaintenance ?? "Belum Dipilih",
                      deskripsi: _descriptionController.text,
                      durasi: _selectedDuration,
                      tanggal: _dateController.text.isEmpty
                          ? "-"
                          : _dateController.text,
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
                child: const Text(
                  "Lanjut ke Upload Foto",
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
        prefixIcon: const Icon(Icons.location_on, color: Colors.blue),
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
        border: InputBorder.none,
      ),
    ),
  );

  Widget _buildDateInput() => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF1E293B),
      borderRadius: BorderRadius.circular(15),
    ),
    child: TextField(
      controller: _dateController,
      readOnly: true,
      onTap: () => _selectDate(context),
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: "Pilih Tanggal Pekerjaan",
        hintStyle: TextStyle(color: Colors.grey),
        prefixIcon: Icon(Icons.calendar_today, color: Colors.blue),
        border: InputBorder.none,
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
