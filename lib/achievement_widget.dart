import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AchievementWidget extends StatelessWidget {
  final String rank; // "bronze", "silver", atau "crown"
  final bool showLabel; // tampilkan teks "Pencapaian Tim: ..." atau tidak
  final double size; // ukuran animasi (lebar & tinggi)

  const AchievementWidget({
    super.key,
    required this.rank,
    this.showLabel = true,
    this.size = 200,
  });

  String _getAnimationPath() {
    switch (rank.toLowerCase()) {
      case 'silver':
        return 'assets/animations/silver_medal.json';
      case 'crown':
        return 'assets/animations/crown_medal.json';
      case 'bronze':
      default:
        return 'assets/animations/bronze_medal.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: Lottie.asset(
            _getAnimationPath(),
            repeat: true, // Ubah ke false jika ingin animasi hanya sekali
            animate: true,
          ),
        ),
      ],
    );
  }
}
