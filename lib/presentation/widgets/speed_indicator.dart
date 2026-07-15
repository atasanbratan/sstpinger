import 'package:flutter/material.dart';

class SpeedIndicator extends StatelessWidget {
  final String label;
  final String speed;
  final String total;
  final IconData icon;
  final Color color;

  const SpeedIndicator({
    super.key,
    required this.label,
    required this.speed,
    required this.total,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                letterSpacing: 1,
                color: Colors.grey[400],
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              speed,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Total: $total',
              style: const TextStyle(fontSize: 10, color: Colors.white38),
            ),
          ],
        ),
      ],
    );
  }
}
