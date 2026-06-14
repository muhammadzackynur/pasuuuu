import 'package:flutter/material.dart';

class FilterLaporanScreen extends StatefulWidget {
  final String role;

  const FilterLaporanScreen({Key? key, required this.role}) : super(key: key);

  @override
  _FilterLaporanScreenState createState() => _FilterLaporanScreenState();
}

class _FilterLaporanScreenState extends State<FilterLaporanScreen> {
  String? selectedMonth;
  List<String> selectedGangguan = [];

  DateTime? dateFrom;
  DateTime? dateTo;

  // Flag: apakah user sudah set tanggal secara manual via date picker
  bool _dateSetManually = false;

  static const Color bgColor = Color(0xFF0F1623);
  static const Color cardColor = Color(0xFF1E2A3A);
  static const Color accentColor = Color(0xFF00E5FF);
  static const Color tileColor = Color(0xFF1A2535);

  final List<Map<String, dynamic>> jenisGangguan = [
    {
      'id': 'DISMALTING TIANG',
      'title': 'Dismantling Tiang',
      'icon': Icons.build_circle_outlined,
      'count': 24,
    },
    {
      'id': 'SISIP TIANG (SOK)',
      'title': 'Sisip Tiang (Sok)',
      'icon': Icons.straighten,
      'count': 9,
    },
    {
      'id': 'TIANG ROBOH/KEROPOS/BENGKOK/PATAH/MIRING',
      'title': 'Tiang Roboh / Keropos / Bengkok',
      'icon': Icons.cell_tower,
      'count': 12,
    },
    {
      'id': 'GANTI BATERAI',
      'title': 'Ganti Baterai',
      'icon': Icons.battery_alert,
      'count': 7,
    },
    {
      'id': 'PEMBUATAN KERANGKENG ODC/OLT',
      'title': 'Pembuatan Kerangkeng ODC/OLT',
      'icon': Icons.security,
      'count': 3,
    },
    {
      'id': 'PENAMBAHAN BANDWITH UPLINK OLT',
      'title': 'Penambahan Bandwith Uplink',
      'icon': Icons.speed,
      'count': 5,
    },
    {
      'id': 'PERBAIKAN CRC COUNTING',
      'title': 'Perbaikan CRC Counting',
      'icon': Icons.memory,
      'count': 11,
    },
    {
      'id': 'PERBAIKAN T-LINE / UPLINK',
      'title': 'Perbaikan T-Line / Uplink',
      'icon': Icons.settings_ethernet,
      'count': 8,
    },
    {
      'id': 'GANTI ODP',
      'title': 'Ganti ODP',
      'icon': Icons.device_hub,
      'count': 6,
    },
    {
      'id': 'GANTI PASSIVE SPLITTER',
      'title': 'Ganti Passive Splitter',
      'icon': Icons.call_split,
      'count': 4,
    },
    {
      'id': 'GANTI BASEDTRAY',
      'title': 'Ganti Basedtray',
      'icon': Icons.dns,
      'count': 2,
    },
    {
      'id': 'GANTI KABINET ODC',
      'title': 'Ganti Kabinet ODC',
      'icon': Icons.kitchen,
      'count': 1,
    },
    {
      'id': 'MH/HH RUSAK',
      'title': 'MH/HH Rusak',
      'icon': Icons.warning_amber_rounded,
      'count': 15,
    },
    {
      'id': 'KU TERJUNTAI/JATUH',
      'title': 'KU Terjuntai / Jatuh',
      'icon': Icons.cable,
      'count': 10,
    },
    {
      'id': 'PERBAIKAN UC',
      'title': 'Perbaikan UC',
      'icon': Icons.handyman,
      'count': 13,
    },
    {
      'id': 'REPAIR FEEDER/DISTRIBUSI',
      'title': 'Repair Feeder / Distribusi',
      'icon': Icons.electrical_services,
      'count': 19,
    },
    {
      'id': 'PENEGAKAN ODC',
      'title': 'Penegakan ODC',
      'icon': Icons.arrow_upward,
      'count': 7,
    },
    {
      'id': 'PENINGGIAN KU',
      'title': 'Peninggian KU',
      'icon': Icons.height,
      'count': 5,
    },
    {
      'id': 'RELOKASI ALPRO',
      'title': 'Relokasi Alpro',
      'icon': Icons.transfer_within_a_station,
      'count': 9,
    },
    {
      'id': 'TAMBAH TIANG',
      'title': 'Tambah Tiang',
      'icon': Icons.add_business,
      'count': 14,
    },
  ];

  final List<String> months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  int _monthIndexFromName(String name) => months.indexOf(name) + 1;

  int _daysInMonth(int year, int month) {
    // Mendapatkan hari terakhir dalam suatu bulan
    return DateTime(year, month + 1, 0).day;
  }

  void _onMonthTap(String m) {
    setState(() {
      if (selectedMonth == m) {
        // Jika klik bulan yang sudah terpilih (untuk membatalkan pilihan)
        selectedMonth = null;
        if (!_dateSetManually) {
          dateFrom = null;
          dateTo = null;
        }
      } else {
        // Jika klik bulan baru
        selectedMonth = m;

        bool shouldOverrideDates = true;

        // Cek apakah user sudah mensetting tanggal secara manual
        if (_dateSetManually) {
          final monthNum = _monthIndexFromName(m);
          // Jika bulan pada tanggal yang diset manual SAMA dengan bulan yang diklik,
          // maka JANGAN ubah tanggal dari dan sampai (biarkan sesuai settingan user)
          bool fromMatch = dateFrom != null && dateFrom!.month == monthNum;
          bool toMatch = dateTo != null && dateTo!.month == monthNum;

          if (fromMatch || toMatch) {
            shouldOverrideDates = false;
          }
        }

        // Jika tidak diset manual atau user memilih bulan yang berbeda dari tanggal manualnya
        if (shouldOverrideDates) {
          final now = DateTime.now();
          final monthNum = _monthIndexFromName(m);
          final year = now.year;
          final lastDay = _daysInMonth(year, monthNum);

          dateFrom = DateTime(year, monthNum, 1);
          dateTo = DateTime(year, monthNum, lastDay);

          // Reset flag manual karena tanggal dioverride otomatis oleh pilihan bulan
          _dateSetManually = false;
        }
      }
    });
  }

  void toggleGangguan(String id) {
    setState(() {
      if (selectedGangguan.contains(id)) {
        selectedGangguan.remove(id);
      } else {
        selectedGangguan.add(id);
      }
    });
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (dateFrom ?? now) : (dateTo ?? now),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: accentColor,
              onPrimary: Colors.black,
              surface: cardColor,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: bgColor,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dateSetManually = true; // Tandai user bahwa tanggal diset manual
        if (isFrom) {
          dateFrom = picked;
        } else {
          dateTo = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '--';
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${dt.day.toString().padLeft(2, '0')} ${monthNames[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Filter Laporan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PERIODE LAPORAN',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildDateBox('DARI', dateFrom, () => _pickDate(true)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateBox(
                    'SAMPAI',
                    dateTo,
                    () => _pickDate(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2.2,
              ),
              itemCount: months.length,
              itemBuilder: (context, index) {
                final m = months[index];
                final isSelected = selectedMonth == m;
                return GestureDetector(
                  onTap: () => _onMonthTap(m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? accentColor.withOpacity(0.12)
                          : cardColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? accentColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      m,
                      style: TextStyle(
                        color: isSelected ? accentColor : Colors.grey,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            const Text(
              'JENIS GANGGUAN',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: jenisGangguan.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = jenisGangguan[index];
                final isSelected = selectedGangguan.contains(item['id']);
                return _buildGangguanTile(item, isSelected);
              },
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: bgColor,
          border: Border(top: BorderSide(color: cardColor, width: 1.5)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    selectedMonth = null;
                    selectedGangguan.clear();
                    dateFrom = null;
                    dateTo = null;
                    _dateSetManually = false;
                  });
                },
                icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                label: const Text(
                  'Reset',
                  style: TextStyle(color: Colors.white, fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: cardColor, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: () {
                  final filterData = <String, dynamic>{
                    'bulan': selectedMonth,
                    'gangguan': selectedGangguan,
                    'role': widget.role,
                    'date_from': dateFrom?.toIso8601String(),
                    'date_to': dateTo?.toIso8601String(),
                  };
                  Navigator.pop(context, filterData);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: accentColor,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Terapkan Filter',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBox(String label, DateTime? date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(date),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.calendar_today_outlined,
              color: accentColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGangguanTile(Map<String, dynamic> item, bool isSelected) {
    return GestureDetector(
      onTap: () => toggleGangguan(item['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: tileColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isSelected
                    ? accentColor.withOpacity(0.15)
                    : const Color(0xFF0F1623),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item['icon'] as IconData,
                color: isSelected ? accentColor : Colors.grey,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item['count']} Laporan',
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: accentColor, size: 22)
            else
              const SizedBox(width: 22),
          ],
        ),
      ),
    );
  }
}
