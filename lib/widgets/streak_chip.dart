import 'package:flutter/material.dart';

import '../services/streak_service.dart';
import '../theme/app_colors.dart';

/// A small flame chip showing the current daily streak. Hidden at 0.
class StreakChip extends StatelessWidget {
  const StreakChip({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StreakService.instance,
      builder: (context, _) {
        final streak = StreakService.instance.state.current;
        if (streak <= 0) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$streak',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
