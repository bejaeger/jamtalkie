import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:jamtalkie/app/app.logger.dart';
import 'package:path_provider/path_provider.dart';

class FirebaseService {
  final log = getLogger("FirebaseService");

  final firestoreInstance = FirebaseFirestore.instance;
  final CollectionReference roomsCollection =
      FirebaseFirestore.instance.collection('rooms');
  final CollectionReference messagesCollection =
      FirebaseFirestore.instance.collection('messages');
  final kDefaultRoomId = '1234';
  Directory? _applicationDir;

  int get userIdPublic => _userId;

  StreamSubscription? roomListenerSubscription;
  int _userId = 1;
  bool isBusyListening = false;
  bool firstTimeListening = true;

  Future listenToRoomMessages(
      {required String roomId,
      required Function(String) playFileCallback}) async {
    roomListenerSubscription ??= messagesCollection
        .where('roomId', isEqualTo: kDefaultRoomId)
        .orderBy('createdAt')
        .snapshots()
        .listen(
      (event) async {
        log.v("Listened to new audio message");
        if (!isBusyListening && event.docs.isNotEmpty && !firstTimeListening) {
          isBusyListening = true;
          final userId = event.docs.last.get('userId');
          final ref = event.docs.last.get('ref');
          if (userId != _userId) {
            log.i("playing audio from ref: $ref");
            await playFileCallback(ref);
          }
          isBusyListening = false;
        }
        firstTimeListening = false;
      },
    );
  }

  Future<File> writeToFile(String ref) async {
    _applicationDir ??= await getApplicationDocumentsDirectory();
    String fileExtension = ref.split('.').last;
    File file = File("${_applicationDir!.path}/audio.$fileExtension");
    await FirebaseStorage.instance.ref(ref).writeToFile(file);
    return file;
  }

  Future<Uint8List?> downloadFile(String ref) async {
    return await FirebaseStorage.instance.ref(ref).getData();
  }

  Future<bool> uploadFile(
      {required String path, required String filename}) async {
    File file = File(path);
    Reference ref = FirebaseStorage.instance.ref().child(filename);
    UploadTask uploadTask =
        ref.putFile(file, SettableMetadata(contentType: "video/mp4"));
    TaskSnapshot taskSnapshot = await uploadTask;
    log.i("Uploaded ${taskSnapshot.bytesTransferred} bytes.");

    var downloadUrl = await taskSnapshot.ref.getDownloadURL();
    var url = downloadUrl.toString();

    await messagesCollection.add({
      'roomId': kDefaultRoomId,
      'url': url,
      'userId': _userId,
      'ref': ref.fullPath,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return true;
  }

  void setUserId(int userId) {
    log.i("Setting user id to $userId");
    _userId = userId;
  }
}
