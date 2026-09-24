import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'backend_client.dart';

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) {
  return FirebaseStorage.instance;
});

final resourceStorageProvider = Provider<ResourceStorage>((ref) {
  return FirebaseResourceStorage(ref.watch(firebaseStorageProvider), ref.watch(collaborationGatewayProvider));
});

abstract interface class ResourceStorage {
  Future<String> upload({
    required String channelId,
    required String userId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  });

  Future<Uint8List> download(String storagePath);

  Future<void> delete(String storagePath);
}

class FirebaseResourceStorage implements ResourceStorage {
  const FirebaseResourceStorage(this._storage, this._gateway);

  final FirebaseStorage _storage;
  final CollaborationGateway _gateway;

  @override
  Future<String> upload({
    required String channelId,
    required String userId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final reservation = await _gateway.call({
      'action': 'reserveUpload',
      'channelId': channelId,
      'size': bytes.length,
      'contentType': contentType,
    });
    final path = reservation['path'] as String;
    final reference = _storage.ref(path);
    await reference.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {'channelId': channelId, 'uploadedBy': userId, 'originalName': fileName},
      ),
    );
    return reference.fullPath;
  }

  @override
  Future<Uint8List> download(String storagePath) async {
    final bytes = await _storage.ref(storagePath).getData(50 * 1024 * 1024);
    if (bytes == null) throw StateError('The file is unavailable.');
    return bytes;
  }

  @override
  Future<void> delete(String storagePath) {
    return _gateway.call({'action': 'deleteUpload', 'path': storagePath}).then((_) {});
  }
}
