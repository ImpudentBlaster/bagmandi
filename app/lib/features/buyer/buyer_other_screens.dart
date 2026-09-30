import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/chat_nav.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../features/shared/chat_screen.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common_widgets.dart';

class BuyerOrdersScreen extends StatefulWidget {
  const BuyerOrdersScreen({super.key});

  @override
  State<BuyerOrdersScreen> createState() => _BuyerOrdersScreenState();
}

class _BuyerOrdersScreenState extends State<BuyerOrdersScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<HomeProvider>().refreshOrders(buyerId: user?.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final all = context.watch<HomeProvider>().orders;
    final orders = _tab == 0
        ? all
        : _tab == 1
            ? all.where((o) => o.status == OrderStatus.ongoing || o.status == OrderStatus.confirmed).toList()
            : all.where((o) => o.status == OrderStatus.completed).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: Column(
        children: [
          PillTabs(
            tabs: const ['All', 'Ongoing', 'Completed'],
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: orders.isEmpty
                ? const Center(child: Text('No orders yet'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orders.length,
                    itemBuilder: (_, i) {
                      final o = orders[i];
                      return AppCard(
                        margin: const EdgeInsets.only(bottom: 12),
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            showDragHandle: true,
                            builder: (ctx) => Padding(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Order #${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                  const SizedBox(height: 10),
                                  Text('Manufacturer: ${o.manufacturerName}'),
                                  const SizedBox(height: 6),
                                  Text('Amount: ₹${o.totalAmount.toStringAsFixed(0)}'),
                                  const SizedBox(height: 6),
                                  Text('Status: ${o.status.name}'),
                                  const SizedBox(height: 6),
                                  Text('Date: ${DateFormat('dd MMM yyyy').format(o.createdAt)}'),
                                  const SizedBox(height: 16),
                                  PrimaryButton(
                                    label: 'Chat with manufacturer',
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      ChatNav.openRoom(context, o.manufacturerId);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                                const Spacer(),
                                StatusChip(label: o.status.name[0].toUpperCase() + o.status.name.substring(1), color: _statusColor(o.status)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(o.manufacturerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd MMM yyyy').format(o.createdAt)),
                            const SizedBox(height: 8),
                            Text(
                              '₹${o.totalAmount.toStringAsFixed(0)}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary),
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

  Color _statusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.completed:
        return AppColors.success;
      case OrderStatus.ongoing:
        return AppColors.info;
      case OrderStatus.confirmed:
        return AppColors.primary;
      case OrderStatus.cancelled:
        return AppColors.error;
    }
  }
}

class BuyerMessagesScreen extends StatelessWidget {
  const BuyerMessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Real inbox lives in shared/chat_screen.dart (MessagesInboxScreen).
    return const MessagesInboxScreen();
  }
}

class BuyerProfileScreen extends StatelessWidget {
  const BuyerProfileScreen({super.key});

  Future<void> _editField(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true && ctrl.text.trim().isNotEmpty) {
      await onSave(ctrl.text.trim());
    }
  }

  Future<void> _pickPhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => Material(
        color: Theme.of(ctx).colorScheme.surface,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !context.mounted) return;
    try {
      await context.read<AuthProvider>().uploadProfilePhoto(source: source);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(height: 28),
            SizedBox(width: 8),
            Text('Profile'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 48,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                      ? CachedNetworkImageProvider(user.profileImage!)
                      : null,
                  child: user.profileImage == null || user.profileImage!.isEmpty
                      ? const Icon(Icons.person, size: 48, color: AppColors.primary)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Material(
                    color: AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: auth.isLoading ? null : () => _pickPhoto(context),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(user.name ?? 'User', style: Theme.of(context).textTheme.headlineMedium),
            Text(user.phone, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            _ProfileTile(
              icon: Icons.person,
              title: 'Name',
              subtitle: user.name ?? '',
              onTap: () => _editField(
                context,
                title: 'Edit Name',
                initial: user.name ?? '',
                onSave: (v) => auth.updateProfile(name: v),
              ),
            ),
            _ProfileTile(
              icon: Icons.business,
              title: 'Business Name',
              subtitle: user.businessName ?? '',
              onTap: () => _editField(
                context,
                title: 'Business Name',
                initial: user.businessName ?? '',
                onSave: (v) => auth.updateProfile(businessName: v),
              ),
            ),
            _ProfileTile(
              icon: Icons.category,
              title: 'Business Type',
              subtitle: user.businessType ?? '',
              onTap: () => _editField(
                context,
                title: 'Business Type',
                initial: user.businessType ?? '',
                onSave: (v) => auth.updateProfile(businessType: v),
              ),
            ),
            _ProfileTile(
              icon: Icons.location_on,
              title: 'Location',
              subtitle: user.location ?? '',
              onTap: () => context.push('/location'),
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              label: 'Logout',
              icon: Icons.logout,
              onPressed: () async {
                final router = GoRouter.of(context);
                await context.read<AuthProvider>().signOut();
                router.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: onTap != null ? const Icon(Icons.edit_outlined, size: 18) : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
