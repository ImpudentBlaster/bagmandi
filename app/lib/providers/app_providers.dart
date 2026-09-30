import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../core/config/app_backend.dart';
import '../core/config/phone_auth_config.dart';
import '../models/models.dart';
import '../services/bagmandi_repository.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';

class AuthProvider extends ChangeNotifier {
  final _repo = BagMandiRepository.instance;

  AppUser? _user;
  bool _isLoading = false;
  String? _verificationId;
  String? _pendingPhone;
  bool _isGuest = false;
  String? _error;
  bool _ready = false;

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  bool get isGuest => _isGuest;
  UserRole? get role => _user?.role;
  String? get verificationId => _verificationId;
  String? get pendingPhone => _pendingPhone;
  String? get error => _error;
  bool get ready => _ready;
  String get backendMode => AppBackend.modeLabel;

  Future<void> bootstrap() async {
    try {
      await _repo.init();
      _user = await _repo.restoreSession();
      if (_user != null && _user!.id.startsWith('guest_')) {
        await _repo.signOut();
        _user = null;
        _isGuest = false;
      }
    } catch (e) {
      debugPrint('Auth bootstrap: $e');
      _user = null;
    } finally {
      _ready = true;
      notifyListeners();
    }
    if (_user != null && !_user!.id.startsWith('guest_')) {
      await _enableNotifications(_user!.id);
    }
  }

  Future<void> _enableNotifications(String userId) async {
    try {
      await NotificationService.instance.init();
      final token = await NotificationService.instance.getToken();
      if (token != null && token != _user?.fcmToken) {
        _user = _user?.copyWith(fcmToken: token);
        if (_user != null) await _repo.saveUser(_user!);
      }
      NotificationService.instance.startInboxWatcher(userId);
    } catch (e) {
      debugPrint('Notifications setup: $e');
    }
  }

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<bool> sendOtp(String phone) async {
    _error = null;
    setLoading(true);
    try {
      final digits = phone.replaceAll(RegExp(r'\D'), '');
      final want = digits.length > 10 ? digits.substring(digits.length - 10) : digits;
      final existingPhone =
          (_user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
      if (_user != null &&
          (existingPhone.isEmpty || !existingPhone.endsWith(want))) {
        // Switching account — clear stale local session (Firebase signed out in repo).
        _user = null;
        _isGuest = false;
        NotificationService.instance.stopInboxWatcher();
      }

      _verificationId = await _repo.sendOtp(phone);
      _pendingPhone = want;
      if (_pendingPhone!.startsWith('91') && _pendingPhone!.length == 12) {
        _pendingPhone = _pendingPhone!.substring(2);
      }
      if (_pendingPhone!.length > 10) {
        _pendingPhone = _pendingPhone!.substring(_pendingPhone!.length - 10);
      }

      // Instant silent login (SMS auto-read / Play Integrity) — skip OTP screen.
      if (_verificationId == 'auto_verified') {
        _user = await _repo.verifyOtp(
          phone: _pendingPhone!,
          otp: '000000',
          verificationId: 'auto_verified',
        );
        _isGuest = false;
        setLoading(false);
        await _enableNotifications(_user!.id);
        return true;
      }

      setLoading(false);
      return true;
    } catch (e) {
      if (e is FirebaseAuthException) {
        _error = PhoneAuthConfig.friendlyError(e);
      } else {
        _error = e.toString().replaceFirst('Exception: ', '');
      }
      setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    _error = null;
    if (_verificationId == null || _pendingPhone == null) {
      _error = 'Please request OTP again';
      notifyListeners();
      return false;
    }
    setLoading(true);
    try {
      _user = await _repo.verifyOtp(
        phone: _pendingPhone!,
        otp: otp,
        verificationId: _verificationId!,
      );
      _isGuest = false;
      setLoading(false);
      await _enableNotifications(_user!.id);
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      setLoading(false);
      return false;
    }
  }

  Future<void> selectRole(UserRole role, {String? businessType}) async {
    if (_user == null) return;
    // Never overwrite admin from the mobile app — admin stays for web panel.
    if (_user!.role == UserRole.admin) {
      _error = 'Admin role is managed on the web panel. Use a buyer/manufacturer number to test the app.';
      notifyListeners();
      return;
    }
    if (role != UserRole.buyer && role != UserRole.manufacturer) return;
    // Role only — name / company details are collected on Complete Profile.
    _user = _user!.copyWith(
      role: role,
      businessType: businessType ?? _user!.businessType,
    );
    await _repo.saveUser(_user!);
    notifyListeners();
  }

  Future<void> setLocation(
    String location, {
    String? city,
    String? state,
    double? latitude,
    double? longitude,
  }) async {
    if (_user == null) return;
    _user = _user!.copyWith(
      location: location,
      city: city,
      state: state,
      latitude: latitude,
      longitude: longitude,
    );
    await _repo.saveUser(_user!);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    String? businessName,
    String? businessType,
    String? aboutUs,
    List<String>? products,
    String? gsmRange,
    int? minOrderKg,
    String? profileImage,
    String? location,
    String? city,
    String? state,
    String? email,
    String? gstNumber,
    DateTime? gstRegistrationDate,
    String? gstType,
    String? addressLine1,
    String? addressLine2,
    String? pincode,
    String? country,
    String? contactNumber,
    String? website,
    bool clearGstRegistrationDate = false,
  }) async {
    if (_user == null) return;
    final cityVal = city ?? _user!.city;
    final stateVal = state ?? _user!.state;
    // Public location is city + state only (never street / pincode).
    final composedLocation = [
      if (cityVal != null && cityVal.trim().isNotEmpty) cityVal.trim(),
      if (stateVal != null && stateVal.trim().isNotEmpty) stateVal.trim(),
    ].join(', ');

    _user = _user!.copyWith(
      name: name,
      businessName: businessName,
      businessType: businessType,
      aboutUs: aboutUs,
      products: products,
      gsmRange: gsmRange,
      minOrderKg: minOrderKg,
      profileImage: profileImage,
      location: location ?? (composedLocation.isNotEmpty ? composedLocation : null),
      city: city,
      state: state,
      email: email,
      gstNumber: gstNumber,
      gstRegistrationDate: gstRegistrationDate,
      gstType: gstType,
      clearGstRegistrationDate: clearGstRegistrationDate,
      addressLine1: addressLine1,
      addressLine2: addressLine2,
      pincode: pincode,
      country: country,
      contactNumber: contactNumber,
      website: website,
    );
    await _repo.saveUser(_user!);
    notifyListeners();
  }

  Future<void> uploadProfilePhoto({ImageSource source = ImageSource.gallery}) async {
    if (_user == null) return;
    final storage = StorageService();
    final file = await storage.pickImage(source: source);
    if (file == null) return;
    setLoading(true);
    try {
      final url = await storage.uploadProfileImage(userId: _user!.id, file: file);
      await updateProfile(profileImage: url);
    } finally {
      setLoading(false);
    }
  }

  Future<void> continueAsGuest() async {
    _isGuest = true;
    _user = AppUser(
      id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
      phone: '',
      role: UserRole.buyer,
      name: 'Guest',
      businessName: 'Guest Buyer',
      location: null,
      city: null,
      state: null,
      createdAt: DateTime.now(),
    );
    // Guest is session-only — do not persist across app restarts.
    notifyListeners();
  }

  Future<void> signOut() async {
    NotificationService.instance.stopInboxWatcher();
    try {
      await _repo.signOut();
    } catch (e) {
      debugPrint('signOut: $e');
    }
    _user = null;
    _isGuest = false;
    _verificationId = null;
    _pendingPhone = null;
    _error = null;
    notifyListeners();
  }
}

class EnquiryProvider extends ChangeNotifier {
  final _repo = BagMandiRepository.instance;

  List<Enquiry> _enquiries = [];
  List<Quote> _quotes = [];
  EnquiryStatus? _filter;
  bool _loading = false;
  String? _error;

  bool get loading => _loading;
  String? get error => _error;

  List<Enquiry> get enquiries {
    if (_filter == null) return _enquiries;
    return _enquiries.where((e) => e.status == _filter).toList();
  }

  List<Enquiry> get allEnquiries => _enquiries;
  List<Quote> get allQuotes => _quotes;

  Future<void> load({String? buyerId, bool asManufacturer = false}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _enquiries = await _repo.fetchEnquiries(buyerId: asManufacturer ? null : buyerId);
      _quotes = await _repo.fetchQuotes();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  void setFilter(EnquiryStatus? status) {
    _filter = status;
    notifyListeners();
  }

  Enquiry? getEnquiry(String id) {
    try {
      return _enquiries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  List<Quote> getQuotesForEnquiry(String enquiryId) {
    return _quotes.where((q) => q.enquiryId == enquiryId).toList();
  }

  Quote? getQuote(String enquiryId, String quoteId) {
    try {
      return _quotes.firstWhere((q) => q.id == quoteId && q.enquiryId == enquiryId);
    } catch (_) {
      return null;
    }
  }

  Future<Enquiry> addEnquiry(Enquiry enquiry) async {
    final saved = await _repo.createEnquiry(enquiry);
    _enquiries.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<Quote> addQuote(Quote quote) async {
    final saved = await _repo.submitQuote(quote);
    _quotes.add(saved);
    final idx = _enquiries.indexWhere((e) => e.id == quote.enquiryId);
    if (idx >= 0) {
      final e = _enquiries[idx];
      _enquiries[idx] = e.copyWith(status: EnquiryStatus.quoted, quoteCount: e.quoteCount + 1);
    }
    notifyListeners();
    return saved;
  }

  Future<Order> acceptQuote(Quote quote) async {
    final enquiry = getEnquiry(quote.enquiryId);
    if (enquiry == null) throw Exception('Enquiry not found');
    final order = await _repo.acceptQuote(quote: quote, enquiry: enquiry);

    final qIdx = _quotes.indexWhere((q) => q.id == quote.id);
    if (qIdx >= 0) _quotes[qIdx] = quote.copyWith(status: QuoteStatus.accepted);
    for (var i = 0; i < _quotes.length; i++) {
      if (_quotes[i].enquiryId == enquiry.id && _quotes[i].id != quote.id) {
        _quotes[i] = _quotes[i].copyWith(status: QuoteStatus.rejected);
      }
    }
    final eIdx = _enquiries.indexWhere((e) => e.id == enquiry.id);
    if (eIdx >= 0) _enquiries[eIdx] = enquiry.copyWith(status: EnquiryStatus.closed);
    notifyListeners();
    return order;
  }
}

class HomeProvider extends ChangeNotifier {
  final _repo = BagMandiRepository.instance;

  List<PPRate> ppRates = [];
  List<Manufacturer> manufacturers = [];
  List<Manufacturer> verifiedManufacturers = [];
  List<MarketplaceItem> marketplaceItems = [];
  List<Order> orders = [];
  bool loading = false;

  Future<void> load({String? buyerId, String? manufacturerId}) async {
    loading = true;
    notifyListeners();
    ppRates = await _repo.fetchRates();
    manufacturers = await _repo.fetchManufacturers();
    verifiedManufacturers = manufacturers.where((m) => m.isVerified).toList();
    marketplaceItems = await _repo.fetchMarket();
    orders = await _repo.fetchOrders(buyerId: buyerId, manufacturerId: manufacturerId);
    loading = false;
    notifyListeners();
  }

  Future<void> refreshOrders({String? buyerId, String? manufacturerId}) async {
    orders = await _repo.fetchOrders(buyerId: buyerId, manufacturerId: manufacturerId);
    notifyListeners();
  }

  Future<MarketplaceItem> addListing(MarketplaceItem item) async {
    final saved = await _repo.createMarketListing(item);
    marketplaceItems.insert(0, saved);
    notifyListeners();
    return saved;
  }

  Future<void> updateOrderStatus(Order order, OrderStatus status) async {
    await _repo.updateOrderStatus(order, status);
    final idx = orders.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      orders[idx] = order.copyWith(status: status);
      notifyListeners();
    }
  }
}
