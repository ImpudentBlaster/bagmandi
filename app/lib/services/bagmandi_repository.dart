import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../core/config/app_backend.dart';
import '../core/config/phone_auth_config.dart';
import '../core/utils/date_parse.dart';
import '../core/utils/location_format.dart';
import '../models/models.dart';
import 'local_store.dart';
import 'notification_service.dart';

class BagMandiRepository {
  BagMandiRepository._();
  static final instance = BagMandiRepository._();

  final LocalStore local = LocalStore();
  final _uuid = const Uuid();

  FirebaseFirestore? get _db {
    if (!AppBackend.firebaseReady) return null;
    return FirebaseFirestore.instance;
  }

  FirebaseAuth? get _auth {
    if (!AppBackend.firebaseReady) return null;
    return FirebaseAuth.instance;
  }

  Future<void> init() async {
    await local.init();
    await ensureFirebaseSeedData();
  }

  /// Seeds default PP rates into Firestore when the collection is empty.
  Future<void> ensureFirebaseSeedData() async {
    final db = _db;
    if (db == null) return;
    try {
      final rates = await db.collection('pp_rates').limit(1).get();
      if (rates.docs.isEmpty) {
        final batch = db.batch();
        final virgin = db.collection('pp_rates').doc('virgin');
        final recycled = db.collection('pp_rates').doc('recycled');
        final now = DateTime.now();
        batch.set(virgin, {
          'materialType': 'Virgin',
          'currentRate': 110.50,
          'changePercent': 2.35,
          'history': [
            {'rate': 107.0, 'date': Timestamp.fromDate(now.subtract(const Duration(days: 7)))},
            {'rate': 108.5, 'date': Timestamp.fromDate(now.subtract(const Duration(days: 5)))},
            {'rate': 109.2, 'date': Timestamp.fromDate(now.subtract(const Duration(days: 3)))},
            {'rate': 110.5, 'date': Timestamp.fromDate(now)},
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        batch.set(recycled, {
          'materialType': 'Recycled PP',
          'currentRate': 95.00,
          'changePercent': -1.2,
          'history': [
            {'rate': 96.0, 'date': Timestamp.fromDate(now.subtract(const Duration(days: 5)))},
            {'rate': 95.0, 'date': Timestamp.fromDate(now)},
          ],
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await batch.commit();
      }
    } catch (e) {
      // Firestore may not be ready yet; local rates still work.
      assert(() {
        // ignore: avoid_print
        print('Firebase seed skipped: $e');
        return true;
      }());
    }
  }

  // ─── Auth ───────────────────────────────────────────────

  Future<String?> sendOtp(String phone) async {
    var digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      digits = digits.substring(2);
    }
    if (digits.length > 10) {
      digits = digits.substring(digits.length - 10);
    }
    if (digits.length != 10) {
      throw Exception('Enter a valid 10-digit mobile number');
    }

    final auth = _auth;
    if (auth != null) {
      final e164 = '+91$digits';

      // Existing session for a different number can block fresh OTP.
      try {
        final current = auth.currentUser;
        if (current != null) {
          final existing =
              (current.phoneNumber ?? '').replaceAll(RegExp(r'\D'), '');
          if (existing.isEmpty || !existing.endsWith(digits)) {
            await auth.signOut();
          }
        }
      } catch (_) {}

      // Firebase Console test numbers: skip Play Integrity / reCAPTCHA.
      final isTest = PhoneAuthConfig.isTestNumber(e164);
      if (isTest) {
        await auth.setSettings(
          appVerificationDisabledForTesting: true,
          forceRecaptchaFlow: false,
        );
        try {
          return await _verifyPhoneNumber(auth, e164, forceRecaptcha: false);
        } finally {
          await PhoneAuthConfig.configure();
        }
      }

      // 1) Play Integrity first (works when SHA + API key OK).
      try {
        await auth.setSettings(
          appVerificationDisabledForTesting: false,
          forceRecaptchaFlow: false,
        );
        return await _verifyPhoneNumber(auth, e164, forceRecaptcha: false);
      } on Exception catch (e) {
        final msg = e.toString().toLowerCase();
        final needsRecaptcha = msg.contains('app identifier') ||
            msg.contains('play integrity') ||
            msg.contains('play_integrity') ||
            msg.contains('sha-256') ||
            msg.contains('sha256') ||
            msg.contains('not authorized') ||
            msg.contains('recaptcha') ||
            msg.contains('17093') ||
            msg.contains('could not verify this device') ||
            msg.contains('missing_client_identifier') ||
            msg.contains('network error') ||
            msg.contains('error 17028');
        if (!needsRecaptcha) {
          if (e is FirebaseAuthException) {
            throw Exception(PhoneAuthConfig.friendlyError(e));
          }
          rethrow;
        }

        // 2) Fallback: reCAPTCHA browser flow.
        await auth.setSettings(
          appVerificationDisabledForTesting: false,
          forceRecaptchaFlow: true,
        );
        try {
          return await _verifyPhoneNumber(auth, e164, forceRecaptcha: true);
        } on FirebaseAuthException catch (re) {
          throw Exception(PhoneAuthConfig.friendlyError(re));
        } finally {
          await PhoneAuthConfig.configure();
        }
      }
    }

    await Future.delayed(const Duration(milliseconds: 600));
    return 'local_$digits';
  }

  Future<String> _verifyPhoneNumber(
    FirebaseAuth auth,
    String e164, {
    required bool forceRecaptcha,
  }) async {
    final completer = Completer<String>();
    await auth.verifyPhoneNumber(
      phoneNumber: e164,
      timeout: const Duration(seconds: 120),
      verificationCompleted: (credential) async {
        try {
          await auth.signInWithCredential(credential);
          if (!completer.isCompleted) completer.complete('auto_verified');
        } catch (_) {
          if (!completer.isCompleted) {
            completer.completeError(
              Exception('Auto verification failed. Enter OTP manually.'),
            );
          }
        }
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) {
          // Keep original Firebase text so Play Integrity SHA mismatch
          // can fall back to reCAPTCHA in sendOtp().
          completer.completeError(e);
        }
      },
      codeSent: (id, _) {
        if (!completer.isCompleted) completer.complete(id);
      },
      codeAutoRetrievalTimeout: (id) {
        // Auto-SMS read timed out — OTP SMS was still requested; unlock OTP screen.
        if (!completer.isCompleted) completer.complete(id);
      },
    );
    final id = await completer.future.timeout(
      const Duration(seconds: 130),
      onTimeout: () => throw Exception(
        'OTP request timed out. Check internet / Play Services and try again.',
      ),
    );
    if (id.isEmpty) {
      throw Exception('OTP could not be sent. Please try again.');
    }
    return id;
  }

  Future<AppUser> verifyOtp({
    required String phone,
    required String otp,
    required String verificationId,
  }) async {
    if (otp.length != 6 || !RegExp(r'^\d{6}$').hasMatch(otp)) {
      throw Exception('Enter a valid 6-digit OTP');
    }

    final digits = phone.replaceAll(RegExp(r'\D'), '');
    final auth = _auth;
    String uid;
    String phoneE164 = '+91$digits';

    if (auth != null && verificationId == 'auto_verified' && auth.currentUser != null) {
      uid = auth.currentUser!.uid;
      phoneE164 = auth.currentUser!.phoneNumber ?? phoneE164;
    } else if (auth != null && !verificationId.startsWith('local_')) {
      final cred = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );
      final result = await auth.signInWithCredential(cred);
      uid = result.user!.uid;
      phoneE164 = result.user!.phoneNumber ?? phoneE164;
    } else {
      await Future.delayed(const Duration(milliseconds: 400));
      uid = 'u_$digits';
    }

    AppUser? existing;
    if (_db != null) {
      final doc = await _db!.collection('users').doc(uid).get();
      if (doc.exists) {
        existing = AppUser.fromMap(doc.data()!, doc.id);
      }
    } else {
      existing = await local.getUser(uid) ?? await local.getUserByPhone(digits);
    }

    final user = existing ??
        AppUser(
          id: uid,
          phone: phoneE164,
          name: 'User ${digits.substring(6)}',
          createdAt: DateTime.now(),
        );

    await saveUser(user);
    await local.setSessionUserId(user.id);
    return user;
  }

  Future<AppUser?> restoreSession() async {
    final auth = _auth;
    // Wait until Firebase restores any persisted signed-in user from disk.
    if (auth != null) {
      await _waitForAuthPersistence(auth);
    }

    final firebaseUser = auth?.currentUser;
    if (firebaseUser != null) {
      final uid = firebaseUser.uid;
      AppUser? user;

      if (_db != null) {
        try {
          final doc = await _db!.collection('users').doc(uid).get();
          if (doc.exists) {
            user = AppUser.fromMap(doc.data()!, doc.id);
          }
        } catch (e) {
          // Offline / rules — fall through to local cache.
          assert(() {
            // ignore: avoid_print
            print('restoreSession firestore: $e');
            return true;
          }());
        }
      }

      user ??= await local.getUser(uid);

      // Still signed in with Firebase — never force OTP again.
      if (user == null) {
        final phone = firebaseUser.phoneNumber ?? '';
        final digits = phone.replaceAll(RegExp(r'\D'), '');
        final suffix = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        user = AppUser(
          id: uid,
          phone: phone.isEmpty ? digits : phone,
          name: suffix.isEmpty ? null : 'User $suffix',
          createdAt: DateTime.now(),
        );
      }

      await local.saveUser(user);
      await local.setSessionUserId(user.id);
      return user;
    }

    final sid = local.sessionUserId;
    if (sid == null || sid.startsWith('guest_')) {
      if (sid != null) await local.setSessionUserId(null);
      return null;
    }
    return local.getUser(sid);
  }

  /// Firebase Auth can report null briefly before disk persistence loads.
  Future<void> _waitForAuthPersistence(FirebaseAuth auth) async {
    if (auth.currentUser != null) return;

    final sid = local.sessionUserId;
    final expectSession = sid != null && !sid.startsWith('guest_');
    final timeout = expectSession
        ? const Duration(seconds: 3)
        : const Duration(milliseconds: 500);

    try {
      await Future.any<void>([
        auth.authStateChanges().where((u) => u != null).first.then((_) {}),
        Future<void>.delayed(timeout),
      ]);
    } catch (_) {}
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    await local.setSessionUserId(null);
  }

  Future<void> saveUser(AppUser user) async {
    await local.saveUser(user);
    if (_db != null) {
      final map = user.toMap();
      map['createdAt'] = encodeAppDate(user.createdAt, forFirestore: true);
      if (user.gstRegistrationDate != null) {
        map['gstRegistrationDate'] =
            encodeAppDate(user.gstRegistrationDate!, forFirestore: true);
      }
      await _db!.collection('users').doc(user.id).set(map, SetOptions(merge: true));
    }
  }

  // ─── Enquiries ──────────────────────────────────────────

  Future<List<Enquiry>> fetchEnquiries({String? buyerId}) async {
    if (_db != null) {
      Query q = _db!.collection('enquiries').orderBy('createdAt', descending: true);
      if (buyerId != null) q = q.where('buyerId', isEqualTo: buyerId);
      final snap = await q.get();
      return snap.docs
          .map((d) => Enquiry.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    }
    final all = await local.getEnquiries();
    if (buyerId == null) return all;
    return all.where((e) => e.buyerId == buyerId).toList();
  }

  Future<Enquiry> createEnquiry(Enquiry enquiry) async {
    var id = enquiry.id;
    if (_db != null) {
      final map = enquiry.toMap();
      map['requiredBy'] = encodeAppDate(enquiry.requiredBy, forFirestore: true);
      map['createdAt'] = encodeAppDate(enquiry.createdAt, forFirestore: true);
      final doc = await _db!.collection('enquiries').add(map);
      id = doc.id;
    }
    final saved = Enquiry(
      id: id,
      buyerId: enquiry.buyerId,
      buyerName: enquiry.buyerName,
      bagType: enquiry.bagType,
      size: enquiry.size,
      color: enquiry.color,
      gsm: enquiry.gsm,
      printing: enquiry.printing,
      quantityKg: enquiry.quantityKg,
      deliveryLocation: enquiry.deliveryLocation,
      requiredBy: enquiry.requiredBy,
      additionalNotes: enquiry.additionalNotes,
      status: enquiry.status,
      quoteCount: enquiry.quoteCount,
      createdAt: enquiry.createdAt,
    );
    await local.upsertEnquiry(saved);
    return saved;
  }

  Future<void> updateEnquiry(Enquiry enquiry) async {
    await local.upsertEnquiry(enquiry);
    if (_db != null) {
      final map = enquiry.toMap();
      map['requiredBy'] = encodeAppDate(enquiry.requiredBy, forFirestore: true);
      map['createdAt'] = encodeAppDate(enquiry.createdAt, forFirestore: true);
      await _db!.collection('enquiries').doc(enquiry.id).set(map, SetOptions(merge: true));
    }
  }

  // ─── Quotes ─────────────────────────────────────────────

  Future<List<Quote>> fetchQuotes({String? enquiryId, String? manufacturerId}) async {
    if (_db != null) {
      Query q = _db!.collection('quotes');
      if (enquiryId != null) q = q.where('enquiryId', isEqualTo: enquiryId);
      if (manufacturerId != null) q = q.where('manufacturerId', isEqualTo: manufacturerId);
      final snap = await q.get();
      return snap.docs
          .map((d) => Quote.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    }
    var all = await local.getQuotes();
    if (enquiryId != null) all = all.where((q) => q.enquiryId == enquiryId).toList();
    if (manufacturerId != null) all = all.where((q) => q.manufacturerId == manufacturerId).toList();
    return all;
  }

  Future<Quote> submitQuote(Quote quote) async {
    var id = quote.id.isEmpty ? _uuid.v4() : quote.id;
    if (_db != null) {
      final map = quote.toMap();
      map['createdAt'] = encodeAppDate(quote.createdAt, forFirestore: true);
      final doc = await _db!.collection('quotes').add(map);
      id = doc.id;
      await _db!.collection('enquiries').doc(quote.enquiryId).update({
        'quoteCount': FieldValue.increment(1),
        'status': EnquiryStatus.quoted.name,
      });
      // Notify buyer about new quote
      final enquiryDoc = await _db!.collection('enquiries').doc(quote.enquiryId).get();
      final buyerId = enquiryDoc.data()?['buyerId'] as String?;
      if (buyerId != null && buyerId.isNotEmpty) {
        await NotificationService.instance.createNotification(
          userId: buyerId,
          title: 'New quote received',
          body: '${quote.manufacturerName} sent a quote for your enquiry',
          type: 'quote',
          refId: quote.enquiryId,
        );
      }
    }

    final saved = Quote(
      id: id,
      enquiryId: quote.enquiryId,
      manufacturerId: quote.manufacturerId,
      manufacturerName: quote.manufacturerName,
      bagPricePerKg: quote.bagPricePerKg,
      printingPricePerKg: quote.printingPricePerKg,
      gstPercent: quote.gstPercent,
      transportCharges: quote.transportCharges,
      otherCharges: quote.otherCharges,
      totalApprox: quote.totalApprox,
      deliveryDays: quote.deliveryDays,
      validity: quote.validity,
      paymentTerms: quote.paymentTerms,
      status: quote.status,
      createdAt: quote.createdAt,
    );

    await local.upsertQuote(saved);

    final enquiries = await local.getEnquiries();
    final idx = enquiries.indexWhere((e) => e.id == quote.enquiryId);
    if (idx >= 0) {
      final e = enquiries[idx];
      await local.upsertEnquiry(e.copyWith(
        status: EnquiryStatus.quoted,
        quoteCount: e.quoteCount + 1,
      ));
    }
    return saved;
  }

  Future<Order> acceptQuote({
    required Quote quote,
    required Enquiry enquiry,
  }) async {
    final order = Order(
      id: 'ORD${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      enquiryId: enquiry.id,
      quoteId: quote.id,
      buyerId: enquiry.buyerId,
      manufacturerId: quote.manufacturerId,
      buyerName: enquiry.buyerName,
      manufacturerName: quote.manufacturerName,
      totalAmount: quote.totalApprox,
      status: OrderStatus.confirmed,
      createdAt: DateTime.now(),
    );

    await local.upsertOrder(order);
    await local.upsertQuote(quote.copyWith(status: QuoteStatus.accepted));
    await local.upsertEnquiry(enquiry.copyWith(status: EnquiryStatus.closed));

    // Reject other quotes
    final quotes = await local.getQuotes();
    for (final q in quotes.where((q) => q.enquiryId == enquiry.id && q.id != quote.id)) {
      await local.upsertQuote(q.copyWith(status: QuoteStatus.rejected));
    }

    if (_db != null) {
      final map = order.toMap();
      map['createdAt'] = encodeAppDate(order.createdAt, forFirestore: true);
      await _db!.collection('orders').doc(order.id).set(map);
      await _db!.collection('quotes').doc(quote.id).update({'status': QuoteStatus.accepted.name});
      await _db!.collection('enquiries').doc(enquiry.id).update({'status': EnquiryStatus.closed.name});

      final others = await _db!
          .collection('quotes')
          .where('enquiryId', isEqualTo: enquiry.id)
          .get();
      for (final doc in others.docs) {
        if (doc.id == quote.id) continue;
        await doc.reference.update({'status': QuoteStatus.rejected.name});
      }

      await NotificationService.instance.createNotification(
        userId: quote.manufacturerId,
        title: 'Quote accepted',
        body: '${enquiry.buyerName} accepted your quote. Order ${order.id} confirmed.',
        type: 'order',
        refId: order.id,
      );
    }

    return order;
  }

  // ─── Orders ─────────────────────────────────────────────

  Future<List<Order>> fetchOrders({String? buyerId, String? manufacturerId}) async {
    if (_db != null) {
      Query q = _db!.collection('orders');
      if (buyerId != null) {
        q = q.where('buyerId', isEqualTo: buyerId).orderBy('createdAt', descending: true);
      } else if (manufacturerId != null) {
        q = q.where('manufacturerId', isEqualTo: manufacturerId).orderBy('createdAt', descending: true);
      } else {
        // Rules require ownership filter — avoid unfiltered list.
        return local.getOrders();
      }
      final snap = await q.get();
      return snap.docs
          .map((d) => Order.fromMap(d.data() as Map<String, dynamic>, d.id))
          .toList();
    }
    var all = await local.getOrders();
    if (buyerId != null) all = all.where((o) => o.buyerId == buyerId).toList();
    if (manufacturerId != null) all = all.where((o) => o.manufacturerId == manufacturerId).toList();
    return all;
  }

  Future<void> updateOrderStatus(Order order, OrderStatus status) async {
    final updated = order.copyWith(status: status);
    await local.upsertOrder(updated);
    if (_db != null) {
      await _db!.collection('orders').doc(order.id).update({'status': status.name});
    }
  }

  // ─── Market / Rates / Manufacturers ─────────────────────

  Future<List<MarketplaceItem>> fetchMarket() async {
    if (_db != null) {
      final snap = await _db!.collection('marketplace').orderBy('createdAt', descending: true).get();
      return snap.docs.map((d) => MarketplaceItem.fromMap(d.data(), d.id)).toList();
    }
    return local.getMarket();
  }

  Future<MarketplaceItem> createMarketListing(MarketplaceItem item) async {
    var id = item.id.isEmpty ? _uuid.v4() : item.id;
    if (_db != null) {
      final map = item.toMap();
      map['createdAt'] = encodeAppDate(item.createdAt, forFirestore: true);
      final doc = await _db!.collection('marketplace').add(map);
      id = doc.id;
    }
    final saved = MarketplaceItem(
      id: id,
      sellerId: item.sellerId,
      sellerName: item.sellerName,
      category: item.category,
      title: item.title,
      description: item.description,
      price: item.price,
      unit: item.unit,
      quantity: item.quantity,
      location: item.location,
      createdAt: item.createdAt,
    );
    await local.upsertMarketItem(saved);
    return saved;
  }

  Future<List<PPRate>> fetchRates() async {
    if (_db != null) {
      final snap = await _db!.collection('pp_rates').get();
      if (snap.docs.isNotEmpty) {
        return snap.docs.map((d) => PPRate.fromMap(d.data(), d.id)).toList();
      }
    }
    return local.getRates();
  }

  Future<List<Manufacturer>> fetchManufacturers() async {
    if (_db != null) {
      final snap = await _db!.collection('users').where('role', isEqualTo: 'manufacturer').get();
      return snap.docs.map((d) {
        final u = AppUser.fromMap(d.data(), d.id);
        return Manufacturer(
          id: u.id,
          name: u.businessName ?? u.name ?? 'Manufacturer',
          location: publicCityState(
            city: u.city,
            state: u.state,
            fallbackLocation: u.location,
          ),
          products: u.products,
          isVerified: u.isVerified,
        );
      }).toList();
    }
    return local.getManufacturers();
  }
}
