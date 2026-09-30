import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/auth_navigation.dart';
import '../../models/models.dart';
import '../../providers/app_providers.dart';

/// Forced after login when name/company profile is incomplete.
class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _businessCtrl;
  late final TextEditingController _gstCtrl;
  late final TextEditingController _address1Ctrl;
  late final TextEditingController _address2Ctrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _websiteCtrl;
  String? _businessType;
  String? _gstType;
  String? _state;
  String _country = 'India';
  DateTime? _gstDate;
  bool _saving = false;
  bool _seeded = false;
  bool _skipGst = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _businessCtrl = TextEditingController();
    _gstCtrl = TextEditingController();
    _address1Ctrl = TextEditingController();
    _address2Ctrl = TextEditingController();
    _cityCtrl = TextEditingController();
    _pincodeCtrl = TextEditingController();
    _contactCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _websiteCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seeded) return;
    _seeded = true;
    final user = context.read<AuthProvider>().user;
    final isMfr = user?.role == UserRole.manufacturer;
    final types = isMfr ? AppStrings.manufacturerTypes : AppStrings.buyerTypes;

    final rawName = user?.name?.trim() ?? '';
    final name = RegExp(r'^User\s+\d+$').hasMatch(rawName) ? '' : rawName;
    final rawBiz = user?.businessName?.trim() ?? '';
    final biz = (rawBiz == 'My Business' || rawBiz == 'My Manufacturing Unit')
        ? ''
        : rawBiz;

    _nameCtrl.text = name;
    _businessCtrl.text = biz;
    _businessType = (user?.businessType != null && types.contains(user!.businessType))
        ? user.businessType
        : types.first;
    _gstCtrl.text = user?.gstNumber ?? '';
    _gstType = (user?.gstType != null && AppStrings.gstTypes.contains(user!.gstType))
        ? user.gstType
        : null;
    _gstDate = user?.gstRegistrationDate;
    _skipGst = user?.gstType == 'Not Registered';
    _address1Ctrl.text = user?.addressLine1 ?? '';
    _address2Ctrl.text = user?.addressLine2 ?? '';
    _cityCtrl.text = user?.city ?? '';
    _state = (user?.state != null && AppStrings.indianStates.contains(user!.state))
        ? user.state
        : null;
    _pincodeCtrl.text = user?.pincode ?? '';
    _country = (user?.country?.trim().isNotEmpty == true) ? user!.country! : 'India';
    _contactCtrl.text = user?.contactNumber?.trim().isNotEmpty == true
        ? user!.contactNumber!
        : (user?.phone ?? '');
    _emailCtrl.text = user?.email ?? '';
    _websiteCtrl.text = user?.website ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _businessCtrl.dispose();
    _gstCtrl.dispose();
    _address1Ctrl.dispose();
    _address2Ctrl.dispose();
    _cityCtrl.dispose();
    _pincodeCtrl.dispose();
    _contactCtrl.dispose();
    _emailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickGstDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _gstDate ?? DateTime(now.year - 1),
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) setState(() => _gstDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final isMfr = auth.user?.role == UserRole.manufacturer;
    if (isMfr && !_skipGst && _gstDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select GST registration date, or skip GST')),
      );
      return;
    }
    if (isMfr && !_skipGst && (_gstType == null || _gstType!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select GST type, or skip GST')),
      );
      return;
    }
    if (isMfr && (_state == null || _state!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select state')),
      );
      return;
    }

    setState(() => _saving = true);
    final gstNumber = isMfr
        ? (_skipGst ? '' : _gstCtrl.text.trim().toUpperCase())
        : null;
    final gstType = isMfr
        ? (_skipGst ? 'Not Registered' : _gstType)
        : null;
    await auth.updateProfile(
      name: isMfr
          ? (_nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : _businessCtrl.text.trim())
          : _nameCtrl.text.trim(),
      businessName: _businessCtrl.text.trim(),
      businessType: _businessType,
      gstNumber: gstNumber,
      gstRegistrationDate: isMfr && !_skipGst ? _gstDate : null,
      gstType: gstType,
      clearGstRegistrationDate: isMfr && _skipGst,
      addressLine1: isMfr ? _address1Ctrl.text.trim() : null,
      addressLine2: isMfr ? _address2Ctrl.text.trim() : null,
      city: isMfr ? _cityCtrl.text.trim() : null,
      state: isMfr ? _state : null,
      pincode: isMfr ? _pincodeCtrl.text.trim() : null,
      country: isMfr ? _country : null,
      contactNumber: isMfr ? _contactCtrl.text.trim() : null,
      email: isMfr ? _emailCtrl.text.trim() : null,
      website: isMfr ? _websiteCtrl.text.trim() : null,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    final user = auth.user;
    if (user == null) {
      context.go('/login');
      return;
    }
    context.go(AuthNavigation.routeFor(user));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isMfr = user?.role == UserRole.manufacturer;
    final types = isMfr ? AppStrings.manufacturerTypes : AppStrings.buyerTypes;
    final accent = isMfr ? AppColors.manufacturer : AppColors.primary;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.go('/role-selection');
      },
      child: Scaffold(
        backgroundColor: isMfr ? const Color(0xFF0B0D10) : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: isMfr ? Colors.white : AppColors.textPrimary,
                  ),
                  onPressed: () => context.go('/role-selection'),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Form(
                    key: _formKey,
                    child: isMfr
                        ? _buildCompanyForm(accent)
                        : _buildBuyerForm(types),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                isMfr ? 'Save & Continue' : 'Continue',
                                style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (isMfr) ...[
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 18),
                              ],
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBuyerForm(List<String> types) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Set up your profile',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Complete this once to continue using BagMandi.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.45,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 28),
        _label('Your name', dark: false),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().length < 2) ? 'Enter your full name' : null,
          decoration: _inputDecoration('e.g. Rahul Sharma', dark: false),
        ),
        const SizedBox(height: 18),
        _label('Business name', dark: false),
        const SizedBox(height: 8),
        TextFormField(
          controller: _businessCtrl,
          textCapitalization: TextCapitalization.words,
          validator: (v) =>
              (v == null || v.trim().length < 2) ? 'Enter your business name' : null,
          decoration: _inputDecoration('e.g. Raj Traders', dark: false),
        ),
        const SizedBox(height: 18),
        _label('Business type', dark: false),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _businessType,
          items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) => setState(() => _businessType = v),
          validator: (v) => v == null || v.isEmpty ? 'Select business type' : null,
          decoration: _inputDecoration('Select type', dark: false),
        ),
      ],
    );
  }

  TextStyle _inputTextStyle({bool dark = true}) {
    return GoogleFonts.poppins(
      fontSize: 14,
      color: dark ? Colors.white : AppColors.textPrimary,
    );
  }

  Widget _buildCompanyForm(Color accent) {
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        colorScheme: baseTheme.colorScheme.copyWith(onSurface: Colors.white),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: Colors.white,
          selectionColor: accent.withValues(alpha: 0.4),
          selectionHandleColor: accent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        Text(
          'Set up company profile',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Provide complete company details to build trust with buyers and grow your business on BagMandi.',
          style: GoogleFonts.poppins(
            fontSize: 13,
            height: 1.45,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 22),
        _sectionCard(
          accent: accent,
          icon: Icons.description_outlined,
          title: 'GST Details',
          subtitle: _skipGst
              ? 'GST skipped — you can add it later from company profile'
              : 'Add GST if available, or skip if your company is not registered',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() {
                  _skipGst = !_skipGst;
                  if (_skipGst) {
                    _gstCtrl.clear();
                    _gstType = null;
                    _gstDate = null;
                  }
                }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: _skipGst
                        ? accent.withValues(alpha: 0.15)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _skipGst ? accent.withValues(alpha: 0.5) : Colors.white12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _skipGst ? Icons.check_box : Icons.check_box_outline_blank,
                        color: _skipGst ? accent : Colors.white54,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'I don\'t have GST — skip for now',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!_skipGst) ...[
                const SizedBox(height: 14),
                _label('GST Number'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _gstCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: _inputTextStyle(),
                  cursorColor: Colors.white,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (v) {
                    if (_skipGst) return null;
                    final value = v?.trim().toUpperCase() ?? '';
                    if (value.length != 15) return 'Enter valid 15-digit GSTIN';
                    if (!RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][A-Z0-9]Z[A-Z0-9]$')
                        .hasMatch(value)) {
                      return 'Invalid GSTIN format';
                    }
                    return null;
                  },
                  decoration: _inputDecoration('e.g. 27ABCDE1234F1Z5'),
                ),
                const SizedBox(height: 14),
                _label('GST Registration Date'),
                const SizedBox(height: 8),
                InkWell(
                  onTap: _pickGstDate,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: InputDecorator(
                    decoration: _inputDecoration('Select date').copyWith(
                      suffixIcon: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                        color: Colors.white54,
                      ),
                    ),
                    child: Text(
                      _gstDate == null
                          ? 'Select date'
                          : DateFormat('dd MMM yyyy').format(_gstDate!),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: _gstDate == null ? Colors.white38 : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _label('GST Type'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _gstType,
                  isExpanded: true,
                  dropdownColor: const Color(0xFF1A1D21),
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                  items: AppStrings.gstTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _gstType = v),
                  decoration: _inputDecoration('Select type'),
                ),
              ],
              const SizedBox(height: 14),
              _label('Business Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _businessCtrl,
                textCapitalization: TextCapitalization.words,
                style: _inputTextStyle(),
                cursorColor: Colors.white,
                validator: (v) => (v == null || v.trim().length < 2)
                    ? 'Enter business name'
                    : null,
                decoration: _inputDecoration(
                  _skipGst
                      ? 'e.g. ABC Bags Private Limited'
                      : 'e.g. ABC Bags Private Limited (as per GST)',
                ),
              ),
              const SizedBox(height: 14),
              _label('Business type'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _businessType,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A1D21),
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                items: AppStrings.manufacturerTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _businessType = v),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Select business type' : null,
                decoration: _inputDecoration('Select type'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          accent: accent,
          icon: Icons.location_on_outlined,
          title: 'Business Address',
          subtitle: 'Add your registered business address',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Address Line 1'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _address1Ctrl,
                textCapitalization: TextCapitalization.words,
                style: _inputTextStyle(),
                cursorColor: Colors.white,
                validator: (v) =>
                    (v == null || v.trim().length < 3) ? 'Enter address line 1' : null,
                decoration: _inputDecoration('e.g. 123, Industrial Area'),
              ),
              const SizedBox(height: 14),
              _label('Address Line 2 (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _address2Ctrl,
                textCapitalization: TextCapitalization.words,
                style: _inputTextStyle(),
                cursorColor: Colors.white,
                decoration: _inputDecoration('e.g. Near Patel Chowk'),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('City'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cityCtrl,
                          textCapitalization: TextCapitalization.words,
                          style: _inputTextStyle(),
                          cursorColor: Colors.white,
                          validator: (v) =>
                              (v == null || v.trim().length < 2) ? 'Enter city' : null,
                          decoration: _inputDecoration('e.g. Bhiwani'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('State'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _state,
                          isExpanded: true,
                          dropdownColor: const Color(0xFF1A1D21),
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
                          items: AppStrings.indianStates
                              .map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _state = v),
                          decoration: _inputDecoration('e.g. Haryana'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Pincode'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _pincodeCtrl,
                          keyboardType: TextInputType.number,
                          style: _inputTextStyle(),
                          cursorColor: Colors.white,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          validator: (v) {
                            if (v == null || v.trim().length != 6) {
                              return 'Enter 6-digit pincode';
                            }
                            return null;
                          },
                          decoration: _inputDecoration('e.g. 127021'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Country'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _country,
                          dropdownColor: const Color(0xFF1A1D21),
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
                          items: const [
                            DropdownMenuItem(value: 'India', child: Text('India')),
                          ],
                          onChanged: (v) => setState(() => _country = v ?? 'India'),
                          decoration: _inputDecoration('India'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          accent: accent,
          icon: Icons.phone_outlined,
          title: 'Other Details',
          subtitle: 'Help buyers and partners reach you easily',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Contact Number'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _contactCtrl,
                          keyboardType: TextInputType.phone,
                          style: _inputTextStyle(),
                          cursorColor: Colors.white,
                          validator: (v) => (v == null || v.trim().length < 10)
                              ? 'Enter contact number'
                              : null,
                          decoration: _inputDecoration('e.g. +91 98765 43210'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Email ID'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          style: _inputTextStyle(),
                          cursorColor: Colors.white,
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Enter email';
                            if (!value.contains('@') || !value.contains('.')) {
                              return 'Invalid email';
                            }
                            return null;
                          },
                          decoration: _inputDecoration('e.g. info@abcbags.com'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _label('Website (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _websiteCtrl,
                keyboardType: TextInputType.url,
                style: _inputTextStyle(),
                cursorColor: Colors.white,
                decoration: _inputDecoration('e.g. www.abcbags.com'),
              ),
            ],
          ),
        ),
      ],
    ),
    );
  }

  Widget _sectionCard({
    required Color accent,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _label(String text, {bool dark = true}) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: dark ? Colors.white : AppColors.textPrimary,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {bool dark = true}) {
    final fill = dark ? const Color(0xFF1E2228) : const Color(0xFFF7F8F7);
    final borderColor = dark ? Colors.white12 : AppColors.border;
    final focus = dark ? AppColors.manufacturer : AppColors.primary;
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.poppins(
        fontSize: 13,
        color: dark ? Colors.white38 : AppColors.textSecondary,
      ),
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: focus, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}
