import 'package:flutter/material.dart';
import 'konfirmasi_laporan_screen.dart';

class InputLaporanScreen extends StatefulWidget {
  final String userName;
  final String role;
  final String userId;
  final int databaseId;

  const InputLaporanScreen({
    super.key,
    required this.userName,
    required this.role,
    required this.userId,
    required this.databaseId,
  });

  @override
  State<InputLaporanScreen> createState() => _InputLaporanScreenState();
}

class _InputLaporanScreenState extends State<InputLaporanScreen> {
  // Controller Data Otomatis
  final TextEditingController _areaController = TextEditingController(text: "2");
  final TextEditingController _districtController = TextEditingController(text: "SURAMADU");
  final TextEditingController _witelController = TextEditingController(text: "SURABAYA UTARA");
  
  // Controller Input Manual
  final TextEditingController _uraianController = TextEditingController(); 

  // State Dropdowns
  String? _selectedKategori; 
  String? _selectedSTO;
  String? _selectedMitra; 

  // Data Dropdown Options
  final List<String> _stoOptions = [
    "KENJERAN", "KAPASAN", "KEBALEN", "KALIANAK", "MERGOYOSO", 
    "TANDES", "KANDANGAN", "KRP", "KARANGPILANG", "LAKASANTRI", 
    "GRESIK", "CERME", "LAMONGAN", "BALOPANGGANG", "BERONDONG", 
    "DUDUKSAMPEYAN", "BAWEAN", "BABAT", "SUKODADI", "KEDAMEAN"
  ];

  final List<String> _kategoriOptions = [
    "DISMALTING TIANG", "SISIP TIANG (SOK)", "TIANG ROBOH/KEROPOS/BENGKOK/PATAH/MIRING",
    "GANTI BATERAI", "PEMBUATAN KERANGKENG ODC/OLT", "PENAMBAHAN BANDWITH UPLINK OLT",
    "PERBAIKAN CRC COUNTING", "PERBAIKAN T-LINE / UPLINK", "GANTI ODP",
    "GANTI PASSIVE SPLITTER", "GANTI BASEDTRAY", "GANTI KABINET ODC",
    "MH/HH RUSAK", "KU TERJUNTAI/JATUH", "PERBAIKAN UC", "REPAIR FEEDER/DISTRIBUSI",
    "PENEGAKAN ODC", "PENINGGIAN KU", "RELOKASI ALPRO", "TAMBAH TIANG",
  ];

  final List<String> _mitraOptions = [
    "PT. Cipta Akses Indotama",
    "PT. Bangtelindo",
    "PT. OPMC Indonesia",
    "PT. Centralindo Panca Sakti",
    "PT. Prima Akses Solusi Global",
    "PT. Akses Kwalitas Unggul",
    "PT. Telkom Akses"
  ];

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
        title: const Text('Input Laporan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      // MENGGUNAKAN SafeArea DI SINI
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- AREA (Otomatis) ---
              _buildFieldLabel("Area"),
              _buildReadOnlyField(_areaController),
              const SizedBox(height: 15),
  
              // --- DISTRICT (Otomatis) ---
              _buildFieldLabel("District"),
              _buildReadOnlyField(_districtController),
              const SizedBox(height: 15),
  
              // --- WITEL (Otomatis) ---
              _buildFieldLabel("Witel"),
              _buildReadOnlyField(_witelController),
              const SizedBox(height: 15),
  
              // --- STO (Dropdown) ---
              _buildFieldLabel("STO"),
              _buildDropdownField("Pilih STO", _selectedSTO, _stoOptions, (val) => setState(() => _selectedSTO = val)),
              const SizedBox(height: 15),
  
              // --- MITRA PELAKSANA ---
              _buildFieldLabel("MITRA PELAKSANA"),
              _buildDropdownField("Pilih Mitra", _selectedMitra, _mitraOptions, (val) => setState(() => _selectedMitra = val)),
              const SizedBox(height: 15),
  
              // --- KATEGORI KEGIATAN ---
              _buildFieldLabel("KATEGORI KEGIATAN"),
              _buildDropdownField("Pilih Kategori", _selectedKategori, _kategoriOptions, (val) => setState(() => _selectedKategori = val)),
              const SizedBox(height: 15),
  
              // --- URAIAN PEKERJAAN ---
              _buildFieldLabel("URAIAN PEKERJAAN"),
              _buildTextArea(hint: "Jelaskan detail pekerjaan...", controller: _uraianController),
              const SizedBox(height: 30),
  
              // --- TOMBOL LANJUT (LANGSUNG KE KONFIRMASI) ---
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () {
                    if (_selectedSTO == null || _selectedMitra == null || _selectedKategori == null || _uraianController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mohon lengkapi semua data!")));
                      return;
                    }
                    
                    // Navigasi Langsung ke Konfirmasi
                    Navigator.push(context, MaterialPageRoute(builder: (context) => KonfirmasiLaporanScreen(
                      userName: widget.userName,
                      role: widget.role,
                      userId: widget.userId,
                      databaseId: widget.databaseId,
                      area: _areaController.text,
                      district: _districtController.text,
                      witel: _witelController.text,
                      sto: _selectedSTO!,
                      mitraPelaksana: _selectedMitra!,
                      kategoriKegiatan: _selectedKategori!,
                      uraianPekerjaan: _uraianController.text,
                    )));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Lanjut ke Konfirmasi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(width: 10),
                      Icon(Icons.arrow_forward, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold));

  Widget _buildReadOnlyField(TextEditingController controller) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
    child: Text(controller.text, style: const TextStyle(color: Colors.white70, fontSize: 15)),
  );

  Widget _buildDropdownField(String hint, String? value, List<String> items, Function(String?) onChanged) => Container(
    margin: const EdgeInsets.only(top: 5),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
    child: DropdownButtonFormField<String>(
      dropdownColor: const Color(0xFF1E293B),
      value: value,
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      style: const TextStyle(color: Colors.white),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(border: InputBorder.none),
    ),
  );

  Widget _buildTextArea({required String hint, required TextEditingController controller}) => Container(
    margin: const EdgeInsets.only(top: 5),
    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
    child: TextField(
      controller: controller, 
      maxLines: 4, 
      style: const TextStyle(color: Colors.white), 
      decoration: InputDecoration(
        hintText: hint, 
        hintStyle: const TextStyle(color: Colors.grey), 
        contentPadding: const EdgeInsets.all(15), 
        border: InputBorder.none
      )
    ),
  );
}