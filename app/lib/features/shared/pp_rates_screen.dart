import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

/// Live PP rate history / trend for buyers & manufacturers.
class PpRatesScreen extends StatefulWidget {
  const PpRatesScreen({super.key});

  @override
  State<PpRatesScreen> createState() => _PpRatesScreenState();
}

class _PpRatesScreenState extends State<PpRatesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final home = context.read<HomeProvider>();
      if (home.ppRates.isEmpty) {
        final user = context.read<AuthProvider>().user;
        home.load(buyerId: user?.id, manufacturerId: user?.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rates = context.watch<HomeProvider>().ppRates;

    return Scaffold(
      appBar: AppBar(title: const Text('PP Rate History')),
      body: rates.isEmpty
          ? const Center(child: Text('No rate data available yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rates.length,
              itemBuilder: (_, i) {
                final rate = rates[i];
                final history = [...rate.history]
                  ..sort((a, b) => b.date.compareTo(a.date));
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rate.materialType,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          Text(
                            '₹${rate.currentRate.toStringAsFixed(2)}/KG',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rate.changePercent >= 0 ? '+' : ''}${rate.changePercent.toStringAsFixed(2)}%  •  Updated ${DateFormat('dd MMM yyyy').format(rate.updatedAt)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (history.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          'Price trend',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 72,
                          child: _MiniTrend(history: history.reversed.toList()),
                        ),
                        const SizedBox(height: 12),
                        ...history.take(10).map((h) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Text(
                                  DateFormat('dd MMM yyyy').format(h.date),
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const Spacer(),
                                Text(
                                  '₹${h.rate.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          );
                        }),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'History will appear as rates are updated.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _MiniTrend extends StatelessWidget {
  final List<RateHistory> history;

  const _MiniTrend({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final values = history.map((h) => h.rate).toList();
    final min = values.reduce((a, b) => a < b ? a : b);
    final max = values.reduce((a, b) => a > b ? a : b);
    final span = (max - min).abs() < 0.01 ? 1.0 : (max - min);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final h in history)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                height: 18 + ((h.rate - min) / span) * 50,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
