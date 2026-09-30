import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/chat_nav.dart';
import '../../core/utils/location_format.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/common_widgets.dart';

class SendQuoteScreen extends StatefulWidget {
  final String enquiryId;

  const SendQuoteScreen({super.key, required this.enquiryId});

  @override
  State<SendQuoteScreen> createState() => _SendQuoteScreenState();
}

class _SendQuoteScreenState extends State<SendQuoteScreen> {
  final _bagPriceController = TextEditingController();
  final _printingController = TextEditingController();
  final _gstController = TextEditingController();
  final _transportController = TextEditingController();
  final _otherController = TextEditingController();
  final _deliveryDaysController = TextEditingController();
  String _validity = '7 Days';
  String _paymentTerms = AppStrings.paymentTerms.first;

  @override
  void initState() {
    super.initState();
    for (final c in [
      _bagPriceController,
      _printingController,
      _gstController,
      _transportController,
      _otherController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _bagPriceController.dispose();
    _printingController.dispose();
    _gstController.dispose();
    _transportController.dispose();
    _otherController.dispose();
    _deliveryDaysController.dispose();
    super.dispose();
  }

  double _totalApprox(double quantityKg) {
    final bagPrice = double.tryParse(_bagPriceController.text) ?? 0;
    final printing = double.tryParse(_printingController.text) ?? 0;
    final gst = double.tryParse(_gstController.text) ?? 0;
    final transport = double.tryParse(_transportController.text) ?? 0;
    final other = double.tryParse(_otherController.text) ?? 0;
    final subtotal = (bagPrice + printing) * quantityKg;
    final gstAmount = subtotal * gst / 100;
    return subtotal + gstAmount + transport + other;
  }

  Future<void> _submit() async {
    final enquiry = context.read<EnquiryProvider>().getEnquiry(widget.enquiryId);
    if (enquiry == null) return;

    final bag = double.tryParse(_bagPriceController.text);
    final printing = double.tryParse(_printingController.text);
    final gst = double.tryParse(_gstController.text);
    final transport = double.tryParse(_transportController.text);
    final other = double.tryParse(_otherController.text) ?? 0;
    final days = int.tryParse(_deliveryDaysController.text);

    if (bag == null || bag <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid bag price / KG')));
      return;
    }
    if (printing == null || printing < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid printing price')));
      return;
    }
    if (gst == null || gst < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid GST %')));
      return;
    }
    if (transport == null || transport < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid transport charges')));
      return;
    }
    if (days == null || days <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter delivery days')));
      return;
    }

    final user = context.read<AuthProvider>().user;
    final quote = Quote(
      id: const Uuid().v4(),
      enquiryId: widget.enquiryId,
      manufacturerId: user?.id ?? 'm1',
      manufacturerName: user?.businessName ?? user?.name ?? 'Manufacturer',
      bagPricePerKg: bag,
      printingPricePerKg: printing,
      gstPercent: gst,
      transportCharges: transport,
      otherCharges: other,
      totalApprox: _totalApprox(enquiry.quantityKg),
      deliveryDays: days,
      validity: _validity,
      paymentTerms: _paymentTerms,
      createdAt: DateTime.now(),
    );

    await context.read<EnquiryProvider>().addQuote(quote);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Quote sent successfully!')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final enquiry = context.watch<EnquiryProvider>().getEnquiry(widget.enquiryId);

    if (enquiry == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Enquiry not found')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Send Quote')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              color: AppColors.primaryLight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Buyer Requirement', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('${enquiry.bagType}  •  ${enquiry.size}'),
                  Text('${enquiry.color}  •  ${enquiry.gsm} GSM  •  ${enquiry.printing}'),
                  Text('Qty: ${enquiry.quantityKg.toInt()} KG'),
                  Text('Delivery: ${enquiry.deliveryLocation}'),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: enquiry.buyerId.isEmpty
                          ? null
                          : () => ChatNav.openRoom(context, enquiry.buyerId),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        minimumSize: const Size(0, 48),
                      ),
                      icon: const Icon(Icons.chat_outlined, size: 18),
                      label: const Text('Chat with buyer', maxLines: 1, softWrap: false),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppTextField(label: 'Bag Price / KG (₹)', controller: _bagPriceController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: 'Printing Price / KG (₹)', controller: _printingController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: 'GST %', controller: _gstController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: 'Transport Charges (₹)', controller: _transportController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: 'Other Charges (₹)', controller: _otherController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppTextField(label: 'Delivery Time (Days)', controller: _deliveryDaysController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppDropdown(
              label: 'Quote Validity',
              value: _validity,
              items: const ['5 Days', '7 Days', '10 Days', '15 Days'],
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _validity = v!),
            ),
            const SizedBox(height: 16),
            AppDropdown(
              label: 'Payment Terms',
              value: _paymentTerms,
              items: AppStrings.paymentTerms,
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _paymentTerms = v!),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total (Approx.)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  Text(
                    '₹${_totalApprox(enquiry.quantityKg).toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: AppColors.primary, fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Submit Quote', color: AppColors.manufacturer, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class MaterialRequirementScreen extends StatefulWidget {
  const MaterialRequirementScreen({super.key});

  @override
  State<MaterialRequirementScreen> createState() => _MaterialRequirementScreenState();
}

class _MaterialRequirementScreenState extends State<MaterialRequirementScreen> {
  String _material = AppStrings.ppMaterials.first;
  String _color = AppStrings.colors.first;
  final _gsmController = TextEditingController();
  final _qtyController = TextEditingController();

  @override
  void dispose() {
    _gsmController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Material Requirement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Source raw material from suppliers',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            AppDropdown(
              label: 'Material',
              value: _material,
              items: AppStrings.ppMaterials,
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _material = v!),
            ),
            const SizedBox(height: 16),
            AppTextField(label: 'GSM', controller: _gsmController, keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            AppDropdown(
              label: 'Color',
              value: _color,
              items: AppStrings.colors,
              itemLabel: (e) => e,
              onChanged: (v) => setState(() => _color = v!),
            ),
            const SizedBox(height: 16),
            AppTextField(label: 'Quantity (KG)', controller: _qtyController, keyboardType: TextInputType.number),
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'Post Requirement',
              color: AppColors.manufacturer,
              onPressed: () async {
                final gsm = int.tryParse(_gsmController.text);
                final qty = double.tryParse(_qtyController.text);
                if (gsm == null || gsm <= 0 || qty == null || qty <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Enter valid GSM and quantity')),
                  );
                  return;
                }
                final user = context.read<AuthProvider>().user;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please login first')),
                  );
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final home = context.read<HomeProvider>();
                await home.addListing(
                      MarketplaceItem(
                        id: '',
                        sellerId: user.id,
                        sellerName: user.businessName ?? user.name ?? 'Manufacturer',
                        category: 'Raw Material',
                        title: 'Need: $_material',
                        description: 'REQUIREMENT • $gsm GSM • $_color • Qty ${qty.toInt()} KG',
                        price: 0,
                        unit: 'KG',
                        quantity: qty,
                        location: () {
                          final loc = publicCityState(
                            city: user.city,
                            state: user.state,
                            fallbackLocation: user.location,
                          );
                          return loc.isEmpty ? 'India' : loc;
                        }(),
                        createdAt: DateTime.now(),
                      ),
                    );
                if (!mounted) return;
                messenger.showSnackBar(
                  const SnackBar(content: Text('Material requirement posted to Market')),
                );
                context.go('/manufacturer/marketplace');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<HomeProvider>().load(manufacturerId: user?.id);
    });
  }

  Future<void> _postListing() async {
    final titleCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String category = AppStrings.materialCategories[_tab];

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Post Listing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                items: AppStrings.materialCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => category = v ?? category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
              TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
              TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Price')),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Post')),
        ],
      ),
    );

    if (ok != true || !mounted) return;
    final price = double.tryParse(priceCtrl.text);
    final qty = double.tryParse(qtyCtrl.text);
    if (titleCtrl.text.trim().isEmpty || price == null || qty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fill title, price and quantity')));
      return;
    }
    final user = context.read<AuthProvider>().user;
    await context.read<HomeProvider>().addListing(
          MarketplaceItem(
            id: '',
            sellerId: user?.id ?? '',
            sellerName: user?.businessName ?? user?.name ?? 'Seller',
            category: category,
            title: titleCtrl.text.trim(),
            description: descCtrl.text.trim().isEmpty ? titleCtrl.text.trim() : descCtrl.text.trim(),
            price: price,
            unit: 'KG',
            quantity: qty,
            location: () {
              final loc = publicCityState(
                city: user?.city,
                state: user?.state,
                fallbackLocation: user?.location,
              );
              return loc.isEmpty ? 'India' : loc;
            }(),
            createdAt: DateTime.now(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing posted')));
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<HomeProvider>().marketplaceItems;
    final category = AppStrings.materialCategories[_tab];
    final filtered = items.where((i) => i.category == category).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Market')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _postListing,
        backgroundColor: AppColors.manufacturer,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Post Listing'),
      ),
      body: Column(
        children: [
          PillTabs(
            tabs: AppStrings.materialCategories,
            selected: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('No listings in this category yet'))
                : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final item = filtered[i];
                return AppCard(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                          StatusChip(label: item.category, color: AppColors.manufacturer),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(item.description),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text(
                            item.price <= 0 ? 'Requirement' : '₹${item.price.toStringAsFixed(0)}/${item.unit}',
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const Spacer(),
                          Text('${item.quantity.toInt()} ${item.unit}  •  ${item.location}'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: () {
                            final me = context.read<AuthProvider>().user;
                            if (me == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login first')),
                              );
                              return;
                            }
                            if (item.sellerId == me.id) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('This is your own listing')),
                              );
                              return;
                            }
                            ChatNav.openRoom(context, item.sellerId);
                          },
                          child: Text(item.price <= 0 ? 'Contact Supplier' : 'Chat & Offer'),
                        ),
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

class ManufacturerOrdersScreen extends StatefulWidget {
  const ManufacturerOrdersScreen({super.key});

  @override
  State<ManufacturerOrdersScreen> createState() => _ManufacturerOrdersScreenState();
}

class _ManufacturerOrdersScreenState extends State<ManufacturerOrdersScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = context.read<AuthProvider>().user;
      context.read<HomeProvider>().refreshOrders(manufacturerId: user?.id);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('#${o.id}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textSecondary)),
                          const Spacer(),
                          StatusChip(
                            label: o.status.name[0].toUpperCase() + o.status.name.substring(1),
                            color: o.status == OrderStatus.completed ? AppColors.success : AppColors.info,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(o.buyerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      const SizedBox(height: 4),
                      Text('Enquiry  •  ${o.enquiryId}'),
                      const SizedBox(height: 8),
                      Text(
                        '₹${o.totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.manufacturer),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => ChatNav.openRoom(context, o.buyerId),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            minimumSize: const Size(0, 48),
                          ),
                          icon: const Icon(Icons.chat_outlined, size: 18),
                          label: const Text('Chat with buyer', maxLines: 1, softWrap: false),
                        ),
                      ),
                      if (o.status != OrderStatus.completed && o.status != OrderStatus.cancelled) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (o.status == OrderStatus.confirmed)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => context.read<HomeProvider>().updateOrderStatus(o, OrderStatus.ongoing),
                                  child: const Text('Mark Ongoing'),
                                ),
                              ),
                            if (o.status == OrderStatus.confirmed) const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => context.read<HomeProvider>().updateOrderStatus(o, OrderStatus.completed),
                                child: const Text('Mark Completed'),
                              ),
                            ),
                          ],
                        ),
                      ],
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

class ManufacturerProfileScreen extends StatelessWidget {
  const ManufacturerProfileScreen({super.key});

  Future<void> _editField(
    BuildContext context, {
    required String title,
    required String initial,
    required Future<void> Function(String) onSave,
    int maxLines = 1,
  }) async {
    final ctrl = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
        ),
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

  Future<void> _editProducts(BuildContext context, List<String> current) async {
    final ctrl = TextEditingController(text: current.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Products'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Comma separated, e.g. D-Cut, W-Cut, Loop Handle',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok == true) {
      if (!context.mounted) return;
      final products = ctrl.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      await context.read<AuthProvider>().updateProfile(products: products);
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
    final company = (user.businessName?.trim().isNotEmpty == true)
        ? user.businessName!
        : (user.name?.trim().isNotEmpty == true ? user.name! : 'Company');
    final initial = company.isNotEmpty ? company[0].toUpperCase() : 'C';
    final location = user.location?.trim().isNotEmpty == true ? user.location! : 'Add location';
    final about = user.aboutUs?.trim() ?? '';
    final products = user.products;
    final gsm = user.gsmRange?.trim() ?? '';
    final minOrder = user.minOrderKg;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppLogoMark(height: 28),
            SizedBox(width: 8),
            Text('Company Profile'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: AppColors.manufacturerLight,
                        backgroundImage: user.profileImage != null && user.profileImage!.isNotEmpty
                            ? CachedNetworkImageProvider(user.profileImage!)
                            : null,
                        child: user.profileImage == null || user.profileImage!.isEmpty
                            ? Text(
                                initial,
                                style: const TextStyle(
                                  fontSize: 36,
                                  color: AppColors.manufacturer,
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Material(
                          color: AppColors.manufacturer,
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(company, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  if (user.businessType != null && user.businessType!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user.businessType!, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.textSecondary),
                      Flexible(
                        child: Text(
                          ' $location',
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.verified, color: AppColors.primary, size: 18),
                      ],
                    ],
                  ),
                  if (user.phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(user.phone, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            _MfrProfileTile(
              icon: Icons.business,
              title: 'Company name',
              subtitle: user.businessName ?? '',
              onTap: () => _editField(
                context,
                title: 'Company name',
                initial: user.businessName ?? '',
                onSave: (v) => auth.updateProfile(businessName: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.receipt_long_outlined,
              title: 'GST Number',
              subtitle: user.gstType == 'Not Registered'
                  ? 'No GST (skipped)'
                  : (user.gstNumber ?? 'Add GSTIN'),
              onTap: () => context.go('/complete-profile'),
            ),
            _MfrProfileTile(
              icon: Icons.badge_outlined,
              title: 'GST Type',
              subtitle: user.gstType ?? 'Not set',
              onTap: () => context.go('/complete-profile'),
            ),
            _MfrProfileTile(
              icon: Icons.person_outline,
              title: 'Contact person',
              subtitle: user.name ?? '',
              onTap: () => _editField(
                context,
                title: 'Contact person',
                initial: user.name ?? '',
                onSave: (v) => auth.updateProfile(name: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.category_outlined,
              title: 'Business type',
              subtitle: user.businessType ?? '',
              onTap: () => _editField(
                context,
                title: 'Business type',
                initial: user.businessType ?? '',
                onSave: (v) => auth.updateProfile(businessType: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.location_on_outlined,
              title: 'Business address',
              subtitle: () {
                final addr = [
                  user.addressLine1,
                  user.city,
                  user.state,
                  user.pincode,
                ].where((e) => e != null && e.trim().isNotEmpty).join(', ');
                return addr.isEmpty ? 'Add address' : addr;
              }(),
              onTap: () => context.go('/complete-profile'),
            ),
            _MfrProfileTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: user.email ?? 'Add email',
              onTap: () => _editField(
                context,
                title: 'Email',
                initial: user.email ?? '',
                onSave: (v) => auth.updateProfile(email: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.language,
              title: 'Website',
              subtitle: user.website?.isNotEmpty == true ? user.website! : 'Add website',
              onTap: () => _editField(
                context,
                title: 'Website',
                initial: user.website ?? '',
                onSave: (v) => auth.updateProfile(website: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.info_outline,
              title: 'About us',
              subtitle: about.isEmpty ? 'Add company description' : about,
              onTap: () => _editField(
                context,
                title: 'About us',
                initial: about,
                maxLines: 4,
                onSave: (v) => auth.updateProfile(aboutUs: v),
              ),
            ),
            _MfrProfileTile(
              icon: Icons.inventory_2_outlined,
              title: 'Products',
              subtitle: products.isEmpty ? 'Add products you manufacture' : products.join(', '),
              onTap: () => _editProducts(context, products),
            ),
            const SizedBox(height: 8),
            SecondaryButton(
              label: 'Edit full company profile',
              icon: Icons.edit_outlined,
              onPressed: () => context.go('/complete-profile'),
            ),
            const SizedBox(height: 12),
            Text('Capabilities', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _editField(
                      context,
                      title: 'GSM Range',
                      initial: gsm,
                      onSave: (v) => auth.updateProfile(gsmRange: v),
                    ),
                    child: _CapabilityCard(
                      title: 'GSM Range',
                      value: gsm.isEmpty ? 'Add' : gsm,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _editField(
                      context,
                      title: 'Min Order (KG)',
                      initial: minOrder?.toString() ?? '',
                      onSave: (v) async {
                        final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
                        if (n != null) {
                          await auth.updateProfile(minOrderKg: n);
                        }
                      },
                    ),
                    child: _CapabilityCard(
                      title: 'Min Order',
                      value: minOrder == null ? 'Add' : '$minOrder KG',
                    ),
                  ),
                ),
              ],
            ),
            if (products.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: products
                    .map(
                      (p) => Chip(
                        label: Text(p),
                        backgroundColor: AppColors.manufacturerLight,
                        labelStyle: const TextStyle(
                          color: AppColors.manufacturer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Post material requirement',
              color: AppColors.manufacturer,
              onPressed: () => context.push('/manufacturer/material-requirement'),
            ),
            const SizedBox(height: 12),
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

class _MfrProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MfrProfileTile({
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
        leading: Icon(icon, color: AppColors.manufacturer),
        title: Text(title),
        subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
        trailing: onTap != null
            ? const Icon(Icons.edit_outlined, size: 18)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  final String title;
  final String value;

  const _CapabilityCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}

