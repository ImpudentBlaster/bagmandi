import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> sendOtp(String phoneNumber) async {
    // Configure RecaptchaVerifier for web if needed
    await _auth.verifyPhoneNumber(
      phoneNumber: '+91$phoneNumber',
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (e) {
        throw Exception(e.message ?? 'Verification failed');
      },
      codeSent: (verificationId, resendToken) {
        // Store verificationId for OTP screen
      },
      codeAutoRetrievalTimeout: (verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential> verifyOtp(String verificationId, String otp) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: otp,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<AppUser?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!, doc.id);
  }

  Future<void> saveUserProfile(AppUser user) async {
    await _firestore.collection('users').doc(user.id).set(user.toMap());
  }

  Future<void> signOut() => _auth.signOut();
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // PP Rates
  Stream<List<PPRate>> watchPPRates() {
    return _db.collection('pp_rates').orderBy('updatedAt', descending: true).snapshots().map(
          (snap) => snap.docs.map((d) => PPRate.fromMap(d.data(), d.id)).toList(),
        );
  }

  Future<void> updatePPRate(String id, double rate) async {
    final doc = await _db.collection('pp_rates').doc(id).get();
    final current = (doc.data()?['currentRate'] ?? 0).toDouble();
    await _db.collection('pp_rates').doc(id).update({
      'currentRate': rate,
      'changePercent': current > 0 ? ((rate - current) / current * 100) : 0,
      'updatedAt': FieldValue.serverTimestamp(),
      'history': FieldValue.arrayUnion([
        {'rate': rate, 'date': Timestamp.now()}
      ]),
    });
  }

  // Enquiries
  Stream<List<Enquiry>> watchEnquiries({String? buyerId, EnquiryStatus? status}) {
    Query query = _db.collection('enquiries').orderBy('createdAt', descending: true);
    if (buyerId != null) query = query.where('buyerId', isEqualTo: buyerId);
    if (status != null) query = query.where('status', isEqualTo: status.name);
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => Enquiry.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
        );
  }

  Future<String> createEnquiry(Enquiry enquiry) async {
    final doc = await _db.collection('enquiries').add(enquiry.toMap());
    return doc.id;
  }

  // Quotes
  Stream<List<Quote>> watchQuotes(String enquiryId) {
    return _db
        .collection('quotes')
        .where('enquiryId', isEqualTo: enquiryId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Quote.fromMap(d.data(), d.id)).toList());
  }

  Future<String> submitQuote(Quote quote) async {
    final doc = await _db.collection('quotes').add(quote.toMap());
    await _db.collection('enquiries').doc(quote.enquiryId).update({
      'quoteCount': FieldValue.increment(1),
      'status': EnquiryStatus.quoted.name,
    });
    return doc.id;
  }

  // Users
  Stream<List<AppUser>> watchUsers({UserRole? role}) {
    Query query = _db.collection('users').orderBy('createdAt', descending: true);
    if (role != null) query = query.where('role', isEqualTo: role.name);
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => AppUser.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
        );
  }

  Future<void> toggleUserStatus(String uid, bool isActive) async {
    await _db.collection('users').doc(uid).update({'isActive': isActive});
  }

  // Orders
  Stream<List<Order>> watchOrders({String? userId, UserRole? role}) {
    Query query = _db.collection('orders').orderBy('createdAt', descending: true);
    if (userId != null && role == UserRole.buyer) {
      query = query.where('buyerId', isEqualTo: userId);
    } else if (userId != null && role == UserRole.manufacturer) {
      query = query.where('manufacturerId', isEqualTo: userId);
    }
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => Order.fromMap(d.data() as Map<String, dynamic>, d.id)).toList(),
        );
  }

  // Admin stats
  Future<Map<String, int>> getAdminStats() async {
    final users = await _db.collection('users').count().get();
    final manufacturers = await _db.collection('users').where('role', isEqualTo: 'manufacturer').count().get();
    final buyers = await _db.collection('users').where('role', isEqualTo: 'buyer').count().get();
    final enquiries = await _db.collection('enquiries').count().get();
    return {
      'totalUsers': users.count ?? 0,
      'manufacturers': manufacturers.count ?? 0,
      'buyers': buyers.count ?? 0,
      'enquiries': enquiries.count ?? 0,
    };
  }
}
