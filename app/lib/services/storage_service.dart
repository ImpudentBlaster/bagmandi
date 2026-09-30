import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_backend.dart';

class StorageService {
  final _picker = ImagePicker();
  final _uuid = const Uuid();

  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
  }

  Future<String> uploadProfileImage({
    required String userId,
    required XFile file,
  }) async {
    if (!AppBackend.firebaseReady || FirebaseAuth.instance.currentUser == null) {
      throw Exception('Sign in with Firebase to upload images');
    }

    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = ['jpg', 'jpeg', 'png', 'webp'].contains(ext) ? ext : 'jpg';
    final ref = FirebaseStorage.instance
        .ref()
        .child('profiles')
        .child(userId)
        .child('${_uuid.v4()}.$safeExt');

    final metadata = SettableMetadata(
      contentType: 'image/$safeExt'.replaceAll('image/jpg', 'image/jpeg'),
    );

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, metadata);
    } else {
      await ref.putFile(File(file.path), metadata);
    }

    return ref.getDownloadURL();
  }
}
