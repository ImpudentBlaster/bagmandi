import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/date_parse.dart';
import '../models/models.dart';

/// Persistent local database used until Firebase credentials are configured.
class LocalStore {
  static const _kUsers = 'bm_users';
  static const _kEnquiries = 'bm_enquiries';
  static const _kQuotes = 'bm_quotes';
  static const _kOrders = 'bm_orders';
  static const _kMarket = 'bm_market';
  static const _kRates = 'bm_rates';
  static const _kManufacturers = 'bm_manufacturers';
  static const _kSession = 'bm_session_user_id';
  static const _kSeeded = 'bm_seeded_v3';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    if (!(_prefs!.getBool(_kSeeded) ?? false)) {
      await _seedEmpty();
      await _prefs!.setBool(_kSeeded, true);
    }
  }

  /// No demo companies / enquiries — production starts empty.
  Future<void> _seedEmpty() async {
    await saveEnquiries([]);
    await saveQuotes([]);
    await saveOrders([]);
    await saveMarket([]);
    await saveRates([]);
    await saveManufacturers([]);
  }

  String? get sessionUserId => _prefs?.getString(_kSession);
  Future<void> setSessionUserId(String? id) async {
    if (id == null) {
      await _prefs?.remove(_kSession);
    } else {
      await _prefs?.setString(_kSession, id);
    }
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    await _prefs?.setString(key, jsonEncode(items));
  }

  // Users
  Future<List<AppUser>> getUsers() async {
    return _readList(_kUsers).map((m) => AppUser.fromMap(m, m['id'] as String)).toList();
  }

  Future<AppUser?> getUser(String id) async {
    final users = await getUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<AppUser?> getUserByPhone(String phone) async {
    final normalized = phone.replaceAll(RegExp(r'\D'), '');
    final users = await getUsers();
    try {
      return users.firstWhere((u) => u.phone.replaceAll(RegExp(r'\D'), '').endsWith(normalized));
    } catch (_) {
      return null;
    }
  }

  Future<void> saveUser(AppUser user) async {
    final users = await getUsers();
    final idx = users.indexWhere((u) => u.id == user.id);
    final map = user.toMap()..['id'] = user.id;
    map['createdAt'] = encodeAppDate(user.createdAt);
    if (idx >= 0) {
      users[idx] = user;
      final list = users.map((u) => u.toMap()..['id'] = u.id..['createdAt'] = encodeAppDate(u.createdAt)).toList();
      await _writeList(_kUsers, list);
    } else {
      final list = [..._readList(_kUsers), map];
      await _writeList(_kUsers, list);
    }
  }

  // Enquiries
  Future<List<Enquiry>> getEnquiries() async {
    return _readList(_kEnquiries).map((m) => Enquiry.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveEnquiries(List<Enquiry> items) async {
    await _writeList(
      _kEnquiries,
      items
          .map((e) => e.toMap()
            ..['id'] = e.id
            ..['requiredBy'] = encodeAppDate(e.requiredBy)
            ..['createdAt'] = encodeAppDate(e.createdAt))
          .toList(),
    );
  }

  Future<Enquiry> upsertEnquiry(Enquiry enquiry) async {
    final list = await getEnquiries();
    final idx = list.indexWhere((e) => e.id == enquiry.id);
    if (idx >= 0) {
      list[idx] = enquiry;
    } else {
      list.insert(0, enquiry);
    }
    await saveEnquiries(list);
    return enquiry;
  }

  // Quotes
  Future<List<Quote>> getQuotes() async {
    return _readList(_kQuotes).map((m) => Quote.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveQuotes(List<Quote> items) async {
    await _writeList(
      _kQuotes,
      items
          .map((q) => q.toMap()
            ..['id'] = q.id
            ..['createdAt'] = encodeAppDate(q.createdAt))
          .toList(),
    );
  }

  Future<Quote> upsertQuote(Quote quote) async {
    final list = await getQuotes();
    final idx = list.indexWhere((q) => q.id == quote.id);
    if (idx >= 0) {
      list[idx] = quote;
    } else {
      list.add(quote);
    }
    await saveQuotes(list);
    return quote;
  }

  // Orders
  Future<List<Order>> getOrders() async {
    return _readList(_kOrders).map((m) => Order.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveOrders(List<Order> items) async {
    await _writeList(
      _kOrders,
      items
          .map((o) => o.toMap()
            ..['id'] = o.id
            ..['createdAt'] = encodeAppDate(o.createdAt))
          .toList(),
    );
  }

  Future<Order> upsertOrder(Order order) async {
    final list = await getOrders();
    final idx = list.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      list[idx] = order;
    } else {
      list.insert(0, order);
    }
    await saveOrders(list);
    return order;
  }

  // Market
  Future<List<MarketplaceItem>> getMarket() async {
    return _readList(_kMarket).map((m) => MarketplaceItem.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveMarket(List<MarketplaceItem> items) async {
    await _writeList(
      _kMarket,
      items
          .map((i) => i.toMap()
            ..['id'] = i.id
            ..['createdAt'] = encodeAppDate(i.createdAt))
          .toList(),
    );
  }

  Future<MarketplaceItem> upsertMarketItem(MarketplaceItem item) async {
    final list = await getMarket();
    final idx = list.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      list[idx] = item;
    } else {
      list.insert(0, item);
    }
    await saveMarket(list);
    return item;
  }

  // Rates
  Future<List<PPRate>> getRates() async {
    return _readList(_kRates).map((m) => PPRate.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveRates(List<PPRate> items) async {
    await _writeList(
      _kRates,
      items
          .map((r) => r.toMap()
            ..['id'] = r.id
            ..['updatedAt'] = encodeAppDate(r.updatedAt)
            ..['history'] = r.history
                .map((h) => {'rate': h.rate, 'date': encodeAppDate(h.date)})
                .toList())
          .toList(),
    );
  }

  // Manufacturers
  Future<List<Manufacturer>> getManufacturers() async {
    return _readList(_kManufacturers).map((m) => Manufacturer.fromMap(m, m['id'] as String)).toList();
  }

  Future<void> saveManufacturers(List<Manufacturer> items) async {
    await _writeList(
      _kManufacturers,
      items.map((m) => m.toMap()..['id'] = m.id).toList(),
    );
  }
}
