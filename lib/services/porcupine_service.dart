import 'dart:io';

import 'package:jamtalkie/constants/constants.dart';
import 'package:porcupine_flutter/porcupine_manager.dart';
import 'package:porcupine_flutter/porcupine_error.dart';
import 'package:jamtalkie/app/app.logger.dart';

class PorcupineService {
  final String accessKey =
      "OPpZhl8W5c9m6E/4/XbsQNSbXIWOwK92/yTlpyF0ys5nvGdxlZ+vQg==";

  final log = getLogger("PorcupineService");

  PorcupineManager? _porcupineManager;

  String currentKeyword = "Jam Talkie";
  bool isError = false;
  String errorMessage = "";

  bool isProcessing = false;

  bool isUserRecordingAudio = false;

  List<String> keywordFilePaths = (Platform.isAndroid)
      ? [kaPorcupineKeywordOnAndroidPath, kaPorcupineKeywordOverAndroidPath]
      : [];

  late Function _notifyViewModel;
  late Function _startRecordingCallback;
  late Function _stopRecordingCallback;

  Future init(
      {required Function notifyViewModel,
      required Function startRecordingCallback,
      required Function stopRecordingCallback}) async {
    _notifyViewModel = notifyViewModel;
    _startRecordingCallback = startRecordingCallback;
    _stopRecordingCallback = stopRecordingCallback;
    await initManager("Jam Talkie");
  }

  Future<void> initManager(String keyword) async {
    if (isProcessing) {
      await stopProcessing();
    }

    if (_porcupineManager != null) {
      await _porcupineManager?.delete();
      _porcupineManager = null;
    }
    try {
      _porcupineManager = await PorcupineManager.fromKeywordPaths(
          accessKey, keywordFilePaths, wakeWordCallback,
          modelPath: kaPorcupineModelPath, errorCallback: errorCallback);
      currentKeyword = keyword;
      isError = false;
    } on PorcupineInvalidArgumentException catch (ex) {
      errorCallback(PorcupineInvalidArgumentException(
          "${ex.message}\nEnsure your accessKey '$accessKey' is a valid access key."));
    } on PorcupineActivationException {
      errorCallback(
          PorcupineActivationException("AccessKey activation error."));
    } on PorcupineActivationLimitException {
      errorCallback(PorcupineActivationLimitException(
          "AccessKey reached its device limit."));
    } on PorcupineActivationRefusedException {
      errorCallback(PorcupineActivationRefusedException("AccessKey refused."));
    } on PorcupineActivationThrottledException {
      errorCallback(PorcupineActivationThrottledException(
          "AccessKey has been throttled."));
    } on PorcupineException catch (ex) {
      errorCallback(ex);
    }
  }

  void wakeWordCallback(int keywordIndex) {
    log.i("Detected keyword with index $keywordIndex");
    if (keywordIndex == 0) {
      if (!isUserRecordingAudio) {
        _startRecordingCallback();
        isUserRecordingAudio = true;
      }
    }
    if (keywordIndex == 1) {
      if (isUserRecordingAudio) {
        _stopRecordingCallback();
        isUserRecordingAudio = false;
      }
    }
    _notifyViewModel();
  }

  void errorCallback(PorcupineException error) {
    isError = true;
    errorMessage = error.message!;
  }

  Future<void> startProcessing() async {
    if (_porcupineManager == null) {
      await initManager(currentKeyword);
    }

    try {
      await _porcupineManager?.start();
      isProcessing = true;
      _notifyViewModel();
    } on PorcupineException catch (ex) {
      errorCallback(ex);
    }
  }

  Future<void> stopProcessing() async {
    await _porcupineManager?.stop();
    isProcessing = false;
    _notifyViewModel();
  }

  Future toggleProcessing() async {
    if (isProcessing) {
      await stopProcessing();
    } else {
      await startProcessing();
    }
  }
}
