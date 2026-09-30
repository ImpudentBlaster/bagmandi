import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/bag_category_assets.dart';
import '../../core/utils/chat_nav.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common_widgets.dart';

class BuyerHomeScreen extends StatefulWidget {
  const BuyerHomeScreen({super.key});

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<HomeProvider>().load(buyerId: user?.id);
      context.read<EnquiryProvider>().load(buyerId: user?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeProvider>();
    final ppRate = home.ppRates.isNotEmpty ? home.ppRates.first : null;
    final location = context.watch<AuthProvider>().user?.location?.trim().isNotEmpty == true
        ? context.watch<AuthProvider>().user!.location!
        : 'Set location';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 12,
        centerTitle: false,
        title: Row(
          children: [
            const AppLogoMark(height: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: InkWell(
                          onTap: () => context.push('/location'),
                          child: Text(
                            location,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => context.push('/location'),
                        child: const Icon(Icons.keyboard_arrow_down, size: 18, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  Text(
                    'Delivering nearby rates',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.rateCard,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ppRate == null
                          ? "TODAY'S PP RATE"
                          : "TODAY'S RATE (${ppRate.materialType})",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                            fontSize: 11,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          ppRate == null
                              ? '—'
                              : '₹${ppRate.currentRate.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                color: Colors.white,
                                fontSize: 32,
                              ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('/ KG', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13)),
                        ),
                        const Spacer(),
                        if (ppRate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  ppRate.changePercent >= 0 ? Icons.trending_up : Icons.trending_down,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${ppRate.changePercent >= 0 ? '+' : ''}${ppRate.changePercent.toStringAsFixed(2)}%',
                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/pp-rates'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Rate History', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => context.push('/pp-rates'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white24),
                              minimumSize: const Size(0, 40),
                            ),
                            child: const Text('Price Trend', style: TextStyle(fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const SectionHeader(title: 'What are you looking for?'),
            SizedBox(
              height: 98,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _QuickAction(
                    icon: Icons.post_add_rounded,
                    label: 'Post\nRequirement',
                    color: AppColors.primary,
                    onTap: () => context.push('/buyer/post-requirement'),
                  ),
                  _QuickAction(
                    icon: Icons.factory_outlined,
                    label: 'Find\nManufacturer',
                    color: AppColors.manufacturer,
                    onTap: () => context.push('/buyer/find-manufacturer'),
                  ),
                  _QuickAction(
                    icon: Icons.list_alt_outlined,
                    label: 'My\nEnquiries',
                    color: AppColors.info,
                    onTap: () => context.go('/buyer/enquiries'),
                  ),
                  _QuickAction(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Top\nBags',
                    color: AppColors.warning,
                    onTap: () => context.push('/buyer/post-requirement'),
                  ),
                ],
              ),
            ),
            const SectionHeader(title: 'Popular Categories'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.82,
                children: BagCategoryAssets.items
                    .map(
                      (c) => _CategoryTile(
                        label: c.label,
                        imageAsset: c.imageAsset,
                        onTap: () => context.push(
                          '/buyer/post-requirement?bagType=${Uri.encodeComponent(c.bagTypeQuery)}',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            SectionHeader(
              title: 'Top Manufacturers',
              actionLabel: 'See All',
              onAction: () => context.push('/buyer/find-manufacturer'),
            ),
            if (home.verifiedManufacturers.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Text(
                  'Verified manufacturers will appear here after admin approval.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: home.verifiedManufacturers.length,
                itemBuilder: (_, i) {
                  final m = home.verifiedManufacturers[i];
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primaryLight,
                          child: Text(
                            m.name.isNotEmpty ? m.name[0] : 'M',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      m.name,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.verified, color: AppColors.primary, size: 16),
                                ],
                              ),
                              if (m.location.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(m.location, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => ChatNav.openRoom(context, m.id),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            minimumSize: const Size(0, 36),
                          ),
                          child: const Text('Contact', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                boxShadow: AppShadows.soft,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final String imageAsset;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.imageAsset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.md)),
              child: Image.asset(
                imageAsset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.primaryLight,
                  child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class FindManufacturerScreen extends StatelessWidget {
  const FindManufacturerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final manufacturers = context.watch<HomeProvider>().verifiedManufacturers;
    return Scaffold(
      appBar: AppBar(title: const Text('Find Manufacturer')),
      body: manufacturers.isEmpty
          ? const Center(child: Text('No verified manufacturers yet.\nAdmin will verify companies soon.'))
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: manufacturers.length,
        itemBuilder: (_, i) {
          final m = manufacturers[i];
          return AppCard(
            margin: const EdgeInsets.only(bottom: 12),
            onTap: () => ChatNav.openRoom(context, m.id),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    m.name.isNotEmpty ? m.name[0] : 'M',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          const Padding(
                            padding: EdgeInsets.only(left: 4),
                            child: Icon(Icons.verified, color: AppColors.primary, size: 16),
                          ),
                        ],
                      ),
                      if (m.location.isNotEmpty)
                        Text(m.location, style: Theme.of(context).textTheme.bodyMedium),
                      if (m.products.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          children: m.products
                              .map((p) => StatusChip(label: p, color: AppColors.primary))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
