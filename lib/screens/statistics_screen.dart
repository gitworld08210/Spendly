import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../repositories/transaction_repository.dart';
import 'share_report_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

enum StatRange { week, month, year }

/// Statistics screen: a Week/Month/Year toggle, a smooth spend line chart,
/// and a Top Spending breakdown — matching the reference design.
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  StatRange _range = StatRange.month;

  (DateTime, DateTime) get _bounds {
    final now = DateTime.now();
    switch (_range) {
      case StatRange.week:
        return (now.subtract(const Duration(days: 7)), now);
      case StatRange.month:
        return (DateTime(now.year, now.month), now);
      case StatRange.year:
        return (DateTime(now.year), now);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = TransactionRepository.instance;

    return AnimatedBuilder(
      animation: repo,
      builder: (context, _) {
        final (from, to) = _bounds;
        final summary = repo.summaryBetween(from, to);
        final top = repo.topSpending(from, to);
        final spark = _buildSpark(repo, from, to);

        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 120),
            children: [
              Row(
                children: [
                  const SizedBox(width: 40),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Statistics',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.ios_share_rounded, size: 20),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ShareReportScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Column(
                  children: [
                    Text(
                      Formatters.money(summary.expense),
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Spent · ${Formatters.date(to)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _RangeToggle(
                value: _range,
                onChanged: (r) => setState(() => _range = r),
              ),
              const SizedBox(height: AppSpacing.lg),
              _SpendChart(points: spark),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'Top Spending',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (top.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    'No spending in this period.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              else
                ...top.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TopSpendRow(
                      name: e.key.name,
                      icon: e.key.icon,
                      color: e.key.color,
                      amount: e.value,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Builds evenly-spaced cumulative-spend points across the range for the
  /// line chart. Buckets debits into N slots.
  List<double> _buildSpark(
      TransactionRepository repo, DateTime from, DateTime to) {
    const buckets = 7;
    final slots = List<double>.filled(buckets, 0);
    final span = to.difference(from).inMilliseconds;
    if (span <= 0) return slots;
    for (final t in repo.all) {
      if (t.isCredit) continue;
      if (t.date.isBefore(from) || t.date.isAfter(to)) continue;
      final pos = t.date.difference(from).inMilliseconds / span;
      final idx = (pos * (buckets - 1)).round().clamp(0, buckets - 1);
      slots[idx] += t.amount;
    }
    return slots;
  }
}

class _RangeToggle extends StatelessWidget {
  const _RangeToggle({required this.value, required this.onChanged});

  final StatRange value;
  final ValueChanged<StatRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
      ),
      child: Row(
        children: [
          for (final r in StatRange.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == r ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  child: Text(
                    _label(r),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: value == r
                          ? AppColors.textOnDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _label(StatRange r) => switch (r) {
        StatRange.week => 'Week',
        StatRange.month => 'Month',
        StatRange.year => 'Year',
      };
}

class _SpendChart extends StatelessWidget {
  const _SpendChart({required this.points});

  final List<double> points;

  @override
  Widget build(BuildContext context) {
    final maxY = (points.isEmpty ? 0 : points.reduce((a, b) => a > b ? a : b));
    final spots = [
      for (var i = 0; i < points.length; i++)
        FlSpot(i.toDouble(), points[i]),
    ];

    return Container(
      height: 190,
      padding: const EdgeInsets.fromLTRB(8, AppSpacing.md, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusCard),
        boxShadow: AppTheme.cardShadow,
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.2,
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.35,
              color: AppColors.ink,
              barWidth: 3,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.accentOrange.withValues(alpha: 0.18),
                    AppColors.accentOrange.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSpendRow extends StatelessWidget {
  const _TopSpendRow({
    required this.name,
    required this.icon,
    required this.color,
    required this.amount,
  });

  final String name;
  final IconData icon;
  final Color color;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSmall),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            Formatters.signedMoney(-amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
