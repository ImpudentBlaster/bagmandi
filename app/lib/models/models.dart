import '../core/utils/date_parse.dart';

enum UserRole { buyer, manufacturer, admin, guest }

enum EnquiryStatus { open, quoted, closed }

enum QuoteStatus { pending, accepted, rejected }

enum OrderStatus { confirmed, ongoing, completed, cancelled }

class AppUser {
  final String id;
  final String phone;
  final String? name;
  final String? email;
  final UserRole role;
  final String? businessName;
  final String? businessType;
  final String? location;
  final String? city;
  final String? state;
  final String? profileImage;
  final String? aboutUs;
  final List<String> products;
  final String? gsmRange;
  final int? minOrderKg;
  final bool isVerified;
  final String? fcmToken;
  final double? latitude;
  final double? longitude;
  final String? gstNumber;
  final DateTime? gstRegistrationDate;
  final String? gstType;
  final String? addressLine1;
  final String? addressLine2;
  final String? pincode;
  final String? country;
  final String? contactNumber;
  final String? website;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.phone,
    this.name,
    this.email,
    this.role = UserRole.guest,
    this.businessName,
    this.businessType,
    this.location,
    this.city,
    this.state,
    this.profileImage,
    this.aboutUs,
    this.products = const [],
    this.gsmRange,
    this.minOrderKg,
    this.isVerified = false,
    this.fcmToken,
    this.latitude,
    this.longitude,
    this.gstNumber,
    this.gstRegistrationDate,
    this.gstType,
    this.addressLine1,
    this.addressLine2,
    this.pincode,
    this.country,
    this.contactNumber,
    this.website,
    required this.createdAt,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, String id) {
    return AppUser(
      id: id,
      phone: map['phone'] ?? '',
      name: map['name'],
      email: map['email'],
      role: UserRole.values.firstWhere(
        (r) => r.name == map['role'],
        orElse: () => UserRole.guest,
      ),
      businessName: map['businessName'],
      businessType: map['businessType'],
      location: map['location'],
      city: map['city'],
      state: map['state'],
      profileImage: map['profileImage'],
      aboutUs: map['aboutUs'],
      products: List<String>.from(map['products'] ?? []),
      gsmRange: map['gsmRange'],
      minOrderKg: map['minOrderKg'],
      isVerified: map['isVerified'] ?? false,
      fcmToken: map['fcmToken'],
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      gstNumber: map['gstNumber'],
      gstRegistrationDate: map['gstRegistrationDate'] != null
          ? parseAppDate(map['gstRegistrationDate'])
          : null,
      gstType: map['gstType'],
      addressLine1: map['addressLine1'],
      addressLine2: map['addressLine2'],
      pincode: map['pincode'],
      country: map['country'],
      contactNumber: map['contactNumber'],
      website: map['website'],
      createdAt: parseAppDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'phone': phone,
        'name': name,
        'email': email,
        'role': role.name,
        'businessName': businessName,
        'businessType': businessType,
        'location': location,
        'city': city,
        'state': state,
        'profileImage': profileImage,
        'aboutUs': aboutUs,
        'products': products,
        'gsmRange': gsmRange,
        'minOrderKg': minOrderKg,
        'isVerified': isVerified,
        'fcmToken': fcmToken,
        'latitude': latitude,
        'longitude': longitude,
        'gstNumber': gstNumber,
        'gstRegistrationDate': gstRegistrationDate?.toIso8601String(),
        'gstType': gstType,
        'addressLine1': addressLine1,
        'addressLine2': addressLine2,
        'pincode': pincode,
        'country': country,
        'contactNumber': contactNumber,
        'website': website,
        'createdAt': createdAt.toIso8601String(),
      };

  AppUser copyWith({
    String? name,
    String? phone,
    String? email,
    UserRole? role,
    String? businessName,
    String? businessType,
    String? location,
    String? city,
    String? state,
    String? profileImage,
    String? aboutUs,
    List<String>? products,
    String? gsmRange,
    int? minOrderKg,
    bool? isVerified,
    String? fcmToken,
    double? latitude,
    double? longitude,
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
  }) {
    return AppUser(
      id: id,
      phone: phone ?? this.phone,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      location: location ?? this.location,
      city: city ?? this.city,
      state: state ?? this.state,
      profileImage: profileImage ?? this.profileImage,
      aboutUs: aboutUs ?? this.aboutUs,
      products: products ?? this.products,
      gsmRange: gsmRange ?? this.gsmRange,
      minOrderKg: minOrderKg ?? this.minOrderKg,
      isVerified: isVerified ?? this.isVerified,
      fcmToken: fcmToken ?? this.fcmToken,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gstNumber: gstNumber != null ? (gstNumber.isEmpty ? null : gstNumber) : this.gstNumber,
      gstRegistrationDate: clearGstRegistrationDate
          ? null
          : (gstRegistrationDate ?? this.gstRegistrationDate),
      gstType: gstType ?? this.gstType,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      pincode: pincode ?? this.pincode,
      country: country ?? this.country,
      contactNumber: contactNumber ?? this.contactNumber,
      website: website ?? this.website,
      createdAt: createdAt,
    );
  }
}

class Enquiry {
  final String id;
  final String buyerId;
  final String buyerName;
  final String bagType;
  final String size;
  final String color;
  final int gsm;
  final String printing;
  final double quantityKg;
  final String deliveryLocation;
  final DateTime requiredBy;
  final String? additionalNotes;
  final EnquiryStatus status;
  final int quoteCount;
  final DateTime createdAt;

  Enquiry({
    required this.id,
    required this.buyerId,
    required this.buyerName,
    required this.bagType,
    required this.size,
    required this.color,
    required this.gsm,
    required this.printing,
    required this.quantityKg,
    required this.deliveryLocation,
    required this.requiredBy,
    this.additionalNotes,
    this.status = EnquiryStatus.open,
    this.quoteCount = 0,
    required this.createdAt,
  });

  factory Enquiry.fromMap(Map<String, dynamic> map, String id) {
    return Enquiry(
      id: id,
      buyerId: map['buyerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      bagType: map['bagType'] ?? '',
      size: map['size'] ?? '',
      color: map['color'] ?? '',
      gsm: map['gsm'] ?? 0,
      printing: map['printing'] ?? '',
      quantityKg: (map['quantityKg'] ?? 0).toDouble(),
      deliveryLocation: map['deliveryLocation'] ?? '',
      requiredBy: parseAppDate(map['requiredBy']),
      additionalNotes: map['additionalNotes'],
      status: EnquiryStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => EnquiryStatus.open,
      ),
      quoteCount: map['quoteCount'] ?? 0,
      createdAt: parseAppDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'buyerId': buyerId,
        'buyerName': buyerName,
        'bagType': bagType,
        'size': size,
        'color': color,
        'gsm': gsm,
        'printing': printing,
        'quantityKg': quantityKg,
        'deliveryLocation': deliveryLocation,
        'requiredBy': requiredBy.toIso8601String(),
        'additionalNotes': additionalNotes,
        'status': status.name,
        'quoteCount': quoteCount,
        'createdAt': createdAt.toIso8601String(),
      };

  Enquiry copyWith({
    EnquiryStatus? status,
    int? quoteCount,
  }) {
    return Enquiry(
      id: id,
      buyerId: buyerId,
      buyerName: buyerName,
      bagType: bagType,
      size: size,
      color: color,
      gsm: gsm,
      printing: printing,
      quantityKg: quantityKg,
      deliveryLocation: deliveryLocation,
      requiredBy: requiredBy,
      additionalNotes: additionalNotes,
      status: status ?? this.status,
      quoteCount: quoteCount ?? this.quoteCount,
      createdAt: createdAt,
    );
  }
}

class Quote {
  final String id;
  final String enquiryId;
  final String manufacturerId;
  final String manufacturerName;
  final double bagPricePerKg;
  final double printingPricePerKg;
  final double gstPercent;
  final double transportCharges;
  final double otherCharges;
  final double totalApprox;
  final int deliveryDays;
  final String validity;
  final String paymentTerms;
  final QuoteStatus status;
  final DateTime createdAt;

  Quote({
    required this.id,
    required this.enquiryId,
    required this.manufacturerId,
    required this.manufacturerName,
    required this.bagPricePerKg,
    required this.printingPricePerKg,
    required this.gstPercent,
    required this.transportCharges,
    required this.otherCharges,
    required this.totalApprox,
    required this.deliveryDays,
    required this.validity,
    required this.paymentTerms,
    this.status = QuoteStatus.pending,
    required this.createdAt,
  });

  factory Quote.fromMap(Map<String, dynamic> map, String id) {
    return Quote(
      id: id,
      enquiryId: map['enquiryId'] ?? '',
      manufacturerId: map['manufacturerId'] ?? '',
      manufacturerName: map['manufacturerName'] ?? '',
      bagPricePerKg: (map['bagPricePerKg'] ?? 0).toDouble(),
      printingPricePerKg: (map['printingPricePerKg'] ?? 0).toDouble(),
      gstPercent: (map['gstPercent'] ?? 0).toDouble(),
      transportCharges: (map['transportCharges'] ?? 0).toDouble(),
      otherCharges: (map['otherCharges'] ?? 0).toDouble(),
      totalApprox: (map['totalApprox'] ?? 0).toDouble(),
      deliveryDays: map['deliveryDays'] ?? 0,
      validity: map['validity'] ?? '',
      paymentTerms: map['paymentTerms'] ?? '',
      status: QuoteStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => QuoteStatus.pending,
      ),
      createdAt: parseAppDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'enquiryId': enquiryId,
        'manufacturerId': manufacturerId,
        'manufacturerName': manufacturerName,
        'bagPricePerKg': bagPricePerKg,
        'printingPricePerKg': printingPricePerKg,
        'gstPercent': gstPercent,
        'transportCharges': transportCharges,
        'otherCharges': otherCharges,
        'totalApprox': totalApprox,
        'deliveryDays': deliveryDays,
        'validity': validity,
        'paymentTerms': paymentTerms,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  Quote copyWith({QuoteStatus? status}) {
    return Quote(
      id: id,
      enquiryId: enquiryId,
      manufacturerId: manufacturerId,
      manufacturerName: manufacturerName,
      bagPricePerKg: bagPricePerKg,
      printingPricePerKg: printingPricePerKg,
      gstPercent: gstPercent,
      transportCharges: transportCharges,
      otherCharges: otherCharges,
      totalApprox: totalApprox,
      deliveryDays: deliveryDays,
      validity: validity,
      paymentTerms: paymentTerms,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class Order {
  final String id;
  final String enquiryId;
  final String quoteId;
  final String buyerId;
  final String manufacturerId;
  final String buyerName;
  final String manufacturerName;
  final double totalAmount;
  final OrderStatus status;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.enquiryId,
    required this.quoteId,
    required this.buyerId,
    required this.manufacturerId,
    required this.buyerName,
    required this.manufacturerName,
    required this.totalAmount,
    this.status = OrderStatus.confirmed,
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> map, String id) {
    return Order(
      id: id,
      enquiryId: map['enquiryId'] ?? '',
      quoteId: map['quoteId'] ?? '',
      buyerId: map['buyerId'] ?? '',
      manufacturerId: map['manufacturerId'] ?? '',
      buyerName: map['buyerName'] ?? '',
      manufacturerName: map['manufacturerName'] ?? '',
      totalAmount: (map['totalAmount'] ?? 0).toDouble(),
      status: OrderStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => OrderStatus.confirmed,
      ),
      createdAt: parseAppDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'enquiryId': enquiryId,
        'quoteId': quoteId,
        'buyerId': buyerId,
        'manufacturerId': manufacturerId,
        'buyerName': buyerName,
        'manufacturerName': manufacturerName,
        'totalAmount': totalAmount,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  Order copyWith({OrderStatus? status}) {
    return Order(
      id: id,
      enquiryId: enquiryId,
      quoteId: quoteId,
      buyerId: buyerId,
      manufacturerId: manufacturerId,
      buyerName: buyerName,
      manufacturerName: manufacturerName,
      totalAmount: totalAmount,
      status: status ?? this.status,
      createdAt: createdAt,
    );
  }
}

class PPRate {
  final String id;
  final String materialType;
  final double currentRate;
  final double changePercent;
  final List<RateHistory> history;
  final DateTime updatedAt;

  PPRate({
    required this.id,
    required this.materialType,
    required this.currentRate,
    this.changePercent = 0,
    this.history = const [],
    required this.updatedAt,
  });

  factory PPRate.fromMap(Map<String, dynamic> map, String id) {
    return PPRate(
      id: id,
      materialType: map['materialType'] ?? '',
      currentRate: (map['currentRate'] ?? 0).toDouble(),
      changePercent: (map['changePercent'] ?? 0).toDouble(),
      history: (map['history'] as List<dynamic>?)
              ?.map((h) => RateHistory.fromMap(Map<String, dynamic>.from(h as Map)))
              .toList() ??
          [],
      updatedAt: parseAppDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'materialType': materialType,
        'currentRate': currentRate,
        'changePercent': changePercent,
        'history': history.map((h) => h.toMap()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class RateHistory {
  final double rate;
  final DateTime date;

  RateHistory({required this.rate, required this.date});

  factory RateHistory.fromMap(Map<String, dynamic> map) {
    return RateHistory(
      rate: (map['rate'] ?? 0).toDouble(),
      date: parseAppDate(map['date']),
    );
  }

  Map<String, dynamic> toMap() => {
        'rate': rate,
        'date': date.toIso8601String(),
      };
}

class MarketplaceItem {
  final String id;
  final String sellerId;
  final String sellerName;
  final String category;
  final String title;
  final String description;
  final double price;
  final String unit;
  final double quantity;
  final String location;
  final DateTime createdAt;

  MarketplaceItem({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.category,
    required this.title,
    required this.description,
    required this.price,
    required this.unit,
    required this.quantity,
    required this.location,
    required this.createdAt,
  });

  factory MarketplaceItem.fromMap(Map<String, dynamic> map, String id) {
    return MarketplaceItem(
      id: id,
      sellerId: map['sellerId'] ?? '',
      sellerName: map['sellerName'] ?? '',
      category: map['category'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toDouble(),
      unit: map['unit'] ?? 'KG',
      quantity: (map['quantity'] ?? 0).toDouble(),
      location: map['location'] ?? '',
      createdAt: parseAppDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'category': category,
        'title': title,
        'description': description,
        'price': price,
        'unit': unit,
        'quantity': quantity,
        'location': location,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Manufacturer {
  final String id;
  final String name;
  final String location;
  final double rating;
  final int reviewCount;
  final String? logoUrl;
  final List<String> products;
  final bool isVerified;

  Manufacturer({
    required this.id,
    required this.name,
    required this.location,
    this.rating = 4.5,
    this.reviewCount = 0,
    this.logoUrl,
    this.products = const [],
    this.isVerified = false,
  });

  factory Manufacturer.fromMap(Map<String, dynamic> map, String id) {
    return Manufacturer(
      id: id,
      name: map['name'] ?? '',
      location: map['location'] ?? '',
      rating: (map['rating'] ?? 4.5).toDouble(),
      reviewCount: map['reviewCount'] ?? 0,
      logoUrl: map['logoUrl'],
      products: List<String>.from(map['products'] ?? []),
      isVerified: map['isVerified'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'location': location,
        'rating': rating,
        'reviewCount': reviewCount,
        'logoUrl': logoUrl,
        'products': products,
        'isVerified': isVerified,
      };
}
