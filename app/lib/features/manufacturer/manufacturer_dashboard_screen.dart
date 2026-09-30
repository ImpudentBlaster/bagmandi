import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/location_format.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../services/chat_service.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common_widgets.dart';

class ManufacturerDashboardScreen extends StatefulWidget {
  const ManufacturerDashboardScreen({super.key});

  @override
  State<ManufacturerDashboardScreen> createState() => _ManufacturerDashboardScreenState();
}

class _ManufacturerDashboardScreenState extends State<ManufacturerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<EnquiryProvider>().load(asManufacturer: true);
      context.read<HomeProvider>().load(manufacturerId: user?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enquiries = context.watch<EnquiryProvider>().allEnquiries;
    final openCount = enquiries.where((e) => e.status == EnquiryStatus.open).length;
    final quotesSent = context.watch<EnquiryProvider>().allQuotes
        .where((q) => q.manufacturerId == context.read<AuthProvider>().user?.id)
        .length;
    final orders = context.watch<HomeProvider>().orders;
    final won = orders.where((o) => o.status == OrderStatus.completed || o.status == OrderStatus.confirmed).length;
    final pending = orders.where((o) => o.status == OrderStatus.ongoing || o.status == OrderStatus.confirmed).length;
    final rates = context.watch<HomeProvider>().ppRates;
    final ppRate = rates.isNotEmpty ? rates.first : null;
    final company = context.watch<AuthProvider>().user;
    final companyLocation = publicCityState(
      city: company?.city,
      state: company?.state,
      fallbackLocation: company?.location,
    );

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        titleSpacing: 12,
        title: Row(
          children: [
            const AppLogoMark(height: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    company?.businessName ?? company?.name ?? 'Manufacturer',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    companyLocation.isEmpty ? 'India' : companyLocation,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StreamBuilder<int>(
            stream: company?.id == null
                ? Stream.value(0)
                : ChatService.instance.watchTotalUnread(company!.id),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 99 ? '99+' : '$count'),
                  child: const Icon(Icons.chat_outlined),
                ),
                onPressed: () => ChatNav.openInbox(context),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => context.push('/pp-rates'),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.rateCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Text(
                      ppRate == null
                          ? 'Live Rate'
                          : 'Live Rate  •  ${ppRate.materialType}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const Spacer(),
                    Text(
                      ppRate == null
                          ? 'Rate unavailable'
                          : '₹${ppRate.currentRate.toStringAsFixed(2)} / KG',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                    if (ppRate != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          '${ppRate.changePercent >= 0 ? '+' : ''}${ppRate.changePercent.toStringAsFixed(2)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.35,
              children: [
                StatCard(
                  title: 'New Enquiries',
                  value: '$openCount',
                  icon: Icons.inbox,
                  color: AppColors.info,
                  onTap: () => context.go('/manufacturer/enquiries'),
                ),
                StatCard(
                  title: 'Quotes Sent',
                  value: '$quotesSent',
                  icon: Icons.send,
                  color: AppColors.manufacturer,
                  onTap: () => context.go('/manufacturer/enquiries'),
                ),
                StatCard(
                  title: 'Orders Won',
                  value: '$won',
                  icon: Icons.check_circle,
                  color: AppColors.success,
                  onTap: () => context.go('/manufacturer/orders'),
                ),
                StatCard(
                  title: 'Pending Orders',
                  value: '$pending',
                  icon: Icons.pending,
                  color: AppColors.warning,
                  onTap: () => context.go('/manufacturer/orders'),
                ),
              ],
            ),
            const SectionHeader(title: 'Quick Actions', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
            Row(
              children: [
                _ActionCard(
                  icon: Icons.post_add,
                  label: 'Post\nRequirement',
                  onTap: () => context.push('/manufacturer/material-requirement'),
                ),
                _ActionCard(
                  icon: Icons.inbox_outlined,
                  label: 'My\nEnquiries',
                  onTap: () => context.go('/manufacturer/enquiries'),
                ),
                _ActionCard(
                  icon: Icons.chat_outlined,
                  label: 'Messages',
                  onTap: () => ChatNav.openInbox(context),
                ),
                _ActionCard(
                  icon: Icons.store_outlined,
                  label: 'Market',
                  onTap: () => context.push('/manufacturer/marketplace'),
                ),
              ],
            ),
            const SectionHeader(title: 'Recent Enquiries', padding: EdgeInsets.fromLTRB(0, 20, 0, 10)),
            ...enquiries.take(3).map(
                  (e) => AppCard(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.bagType, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text('${e.quantityKg.toInt()} KG  •  ${e.deliveryLocation}'),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => context.push('/manufacturer/send-quote/${e.id}'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 34),
                          ),
                          child: const Text('Send Quote', style: TextStyle(fontSize: 12)),
                        ),
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionCard({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            children: [
              Icon(icon, color: AppColors.manufacturer, size: 24),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

class ManufacturerEnquiriesScreen extends StatefulWidget {
  const ManufacturerEnquiriesScreen({super.key});

  @override
  State<ManufacturerEnquiriesScreen> createState() => _ManufacturerEnquiriesScreenState();
}

class _ManufacturerEnquiriesScreenState extends State<ManufacturerEnquiriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnquiryProvider>().load(asManufacturer: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enquiries = context.watch<EnquiryProvider>().allEnquiries;

    return Scaffold(
      appBar: AppBar(title: const Text('New Enquiries')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: enquiries.length,
        itemBuilder: (_, i) {
          final e = enquiries[i];
          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('#${e.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                    const Spacer(),
                    StatusChip.enquiry(e.status.name),
                  ],
                ),
                const SizedBox(height: 8),
                Text(e.bagType, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text('Buyer: ${e.buyerName}'),
                Text('${e.size}  •  ${e.color}  •  ${e.gsm} GSM  •  ${e.printing}'),
                Text('Qty: ${e.quantityKg.toInt()} KG'),
                Text('Delivery: ${e.deliveryLocation}'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: e.buyerId.isEmpty
                          ? null
                          : () => ChatNav.openRoom(context, e.buyerId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        minimumSize: const Size(0, 44),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Chat', maxLines: 1, softWrap: false),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => context.push('/manufacturer/send-quote/${e.id}'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(0, 44),
                        ),
                        child: const Text('Send Quote', maxLines: 1),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
