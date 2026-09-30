import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';
import '../../shared/widgets/common_widgets.dart';

class PostRequirementScreen extends StatefulWidget {
  final String? initialBagType;

  const PostRequirementScreen({super.key, this.initialBagType});

  @override
  State<PostRequirementScreen> createState() => _PostRequirementScreenState();
}

class _PostRequirementScreenState extends State<PostRequirementScreen> {
  final _formKey = GlobalKey<FormState>();
  late String? _bagType;
  String? _color = AppStrings.colors.first;
  String? _printing = AppStrings.printingOptions.first;
  String _unit = 'KG';
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _gsmController = TextEditingController();
  final _quantityController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  late final TextEditingController _deadlineController;
  DateTime _requiredBy = DateTime.now().add(const Duration(days: 15));

  @override
  void initState() {
    super.initState();
    final initial = widget.initialBagType?.trim();
    if (initial != null && initial.isNotEmpty) {
      final normalized = initial.toLowerCase();
      if (normalized == 'other') {
        _bagType = 'Other Bag';
      } else if (normalized.contains('side') && normalized.contains('gusset')) {
        _bagType = 'Side Gusset Bag';
      } else {
        final match = AppStrings.bagTypes.firstWhere(
          (t) => t.toLowerCase().contains(normalized) || normalized.contains(t.toLowerCase().split(' ').first),
          orElse: () => AppStrings.bagTypes.first,
        );
        final byLabel = AppStrings.bagTypes.where((t) => t.toLowerCase().startsWith(normalized)).toList();
        _bagType = byLabel.isNotEmpty ? byLabel.first : match;
      }
    } else {
      _bagType = AppStrings.bagTypes.first;
    }
    _deadlineController = TextEditingController(
      text: DateFormat('dd MMM yyyy').format(_requiredBy),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final loc = context.read<AuthProvider>().user?.location?.trim();
      if (loc != null && loc.isNotEmpty) {
        _locationController.text = loc;
      }
    });
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    _gsmController.dispose();
    _quantityController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>().user;
    if (auth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first')),
      );
      return;
    }

    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    final gsm = int.tryParse(_gsmController.text);
    final qty = double.tryParse(_quantityController.text);

    if (width == null || width <= 0 || height == null || height <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter valid size (width x height)')),
      );
      return;
    }
    if (gsm == null || gsm < 20 || gsm > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GSM must be between 20 and 500')),
      );
      return;
    }
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid quantity')),
      );
      return;
    }

    final enquiry = Enquiry(
      id: 'BM${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      buyerId: auth.id,
      buyerName: auth.businessName ?? auth.name ?? 'Buyer',
      bagType: _bagType!,
      size: '${width}x$height inch',
      color: _color!,
      gsm: gsm,
      printing: _printing!,
      quantityKg: qty,
      deliveryLocation: _locationController.text.trim(),
      requiredBy: _requiredBy,
      additionalNotes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      createdAt: DateTime.now(),
    );

    await context.read<EnquiryProvider>().addEnquiry(enquiry);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requirement posted successfully!')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post Requirement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppDropdown(
                label: 'Bag Type',
                value: _bagType,
                items: AppStrings.bagTypes,
                itemLabel: (e) => e,
                onChanged: (v) => setState(() => _bagType = v),
              ),
              const SizedBox(height: 16),
              Text(
                'Size',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _widthController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Width'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('×', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _heightController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(hintText: 'Height'),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text('inch', style: TextStyle(fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'GSM',
                controller: _gsmController,
                keyboardType: TextInputType.number,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppDropdown(
                label: 'Color',
                value: _color,
                items: AppStrings.colors,
                itemLabel: (e) => e,
                onChanged: (v) => setState(() => _color = v),
              ),
              const SizedBox(height: 16),
              AppDropdown(
                label: 'Printing',
                value: _printing,
                items: AppStrings.printingOptions,
                itemLabel: (e) => e,
                onChanged: (v) => setState(() => _printing = v),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: AppTextField(
                      label: 'Quantity',
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDropdown(
                      label: 'Unit',
                      value: _unit,
                      items: const ['KG', 'Pcs'],
                      itemLabel: (e) => e,
                      onChanged: (v) => setState(() => _unit = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Delivery Location',
                controller: _locationController,
                prefix: const Icon(Icons.location_on_outlined, color: AppColors.primary),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Deadline',
                controller: _deadlineController,
                readOnly: true,
                prefix: const Icon(Icons.calendar_today_outlined, color: AppColors.primary, size: 20),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _requiredBy,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() {
                      _requiredBy = date;
                      _deadlineController.text = DateFormat('dd MMM yyyy').format(date);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Additional Requirements',
                hint: 'Any special requirements...',
                controller: _notesController,
                maxLines: 3,
              ),
              const SizedBox(height: 28),
              PrimaryButton(label: 'Post Requirement', onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
