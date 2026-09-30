import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class BuyerEnquiriesScreen extends StatefulWidget {
  const BuyerEnquiriesScreen({super.key});

  @override
  State<BuyerEnquiriesScreen> createState() => _BuyerEnquiriesScreenState();
}

class _BuyerEnquiriesScreenState extends State<BuyerEnquiriesScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = context.read<AuthProvider>().user;
      context.read<EnquiryProvider>().setFilter(null);
      context.read<EnquiryProvider>().load(buyerId: user?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<EnquiryProvider>();
    final enquiries = provider.enquiries;

    return Scaffold(
      appBar: AppBar(title: const Text('My Enquiries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/buyer/post-requirement'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post New'),
      ),
      body: Column(
        children: [
          PillTabs(
            tabs: const ['All', 'Open', 'Quoted', 'Closed'],
            selected: _tab,
            onChanged: (i) {
              setState(() => _tab = i);
              switch (i) {
                case 0:
                  provider.setFilter(null);
                case 1:
                  provider.setFilter(EnquiryStatus.open);
                case 2:
                  provider.setFilter(EnquiryStatus.quoted);
                case 3:
                  provider.setFilter(EnquiryStatus.closed);
              }
            },
          ),
          Expanded(
            child: enquiries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('No enquiries yet', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text('Post your first requirement', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: enquiries.length,
                    itemBuilder: (_, i) {
                      final e = enquiries[i];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        onTap: () => context.push('/buyer/enquiry/${e.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  '#${e.id}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const Spacer(),
                                StatusChip.enquiry(e.status.name),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(e.bagType, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 4),
                            Text('${e.size}  •  ${e.color}  •  ${e.gsm} GSM  •  ${e.printing}'),
                            Text('Qty: ${e.quantityKg.toInt()} KG'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                                Expanded(
                                  child: Text(' ${e.deliveryLocation}', style: Theme.of(context).textTheme.bodyMedium),
                                ),
                                if (e.quoteCount > 0)
                                  StatusChip(
                                    label: '${e.quoteCount} Quotes Received',
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Deadline: ${DateFormat('dd MMM yyyy').format(e.requiredBy)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
