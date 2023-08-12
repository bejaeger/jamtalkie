import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:jamtalkie/app/app.locator.dart';
import 'package:jamtalkie/constants/constants.dart';
import 'package:jamtalkie/services/firebase_service.dart';
import 'package:jamtalkie/services/porcupine_service.dart';
import 'package:jamtalkie/ui/common/app_strings.dart';
import 'package:path_provider/path_provider.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:record/record.dart';
import 'package:jamtalkie/app/app.logger.dart';
import 'package:just_audio/just_audio.dart';

class JamtalkieHomeViewModel extends BaseViewModel {
  final FirebaseService _firebaseService = locator<FirebaseService>();
  final SnackbarService _snackbarService = locator<SnackbarService>();
  final DialogService _dialogService = locator<DialogService>();
  final recorder = Record();
  final AudioPlayer _audioPlayer =
      AudioPlayer(handleAudioSessionActivation: false);

  final PorcupineService _porcupineService = locator<PorcupineService>();
  // final audioplayers.AudioPlayer __audioPlayer = audioplayers.AudioPlayer();
  final log = getLogger("JamtalkieHomeViewModel");
  late AudioSession session;
  late AudioSession recordingSession;

  Stream<PlayerState> get playerState => _audioPlayer.playerStateStream;
  int get userId => _firebaseService.userIdPublic;

  bool get isListeningToKeyword => _porcupineService.isProcessing;
  bool get isUserRecordingAudioPico => _porcupineService.isUserRecordingAudio;

  List<String> audioList = [];
  bool debugMode = false;
  final AudioEncoder _audioEncoder =
      Platform.isIOS ? AudioEncoder.flac : AudioEncoder.aacLc;
  final String fileExtension = Platform.isIOS ? "flac" : "m4a";

  int isPlayingAudioWithIndex = -1;
  bool isRecording = false;
  bool receivingAudio = false;
  bool playingAudio = false;
  bool playingSoundEffect = false;

  Future<void> init() async {
    await _porcupineService.init(
      notifyViewModel: notifyListeners,
      startRecordingCallback: startRecordingAudio,
      stopRecordingCallback: stopRecordingAudio,
    );
    session = await AudioSession.instance;

    playerState.listen((event) async {
      if ((event.processingState == ProcessingState.loading ||
              event.processingState == ProcessingState.buffering ||
              event.playing) &&
          event.processingState != ProcessingState.completed) {
        if (!playingSoundEffect) {
          playingAudio = true;
          notifyListeners();
        }
      }
      if (event.processingState == ProcessingState.completed) {
        log.i("Completed playing audio");
        if (!isRecording) {
          await session.setActive(false);
        }
        isPlayingAudioWithIndex = -1;
        playingAudio = false;
        notifyListeners();
      }
    });

    Directory directory = await getApplicationDocumentsDirectory();
    directory.list().listen((file) {
      if (file.path.contains("Audio")) {
        audioList.add(file.path);
        notifyListeners();
      }
    });

    await session.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.music,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: true,
    ));

    recordingSession = await AudioSession.instance;
    await recordingSession.configure(const AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.allowBluetooth,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: AndroidAudioAttributes(
        contentType: AndroidAudioContentType.speech,
        flags: AndroidAudioFlags.none,
        usage: AndroidAudioUsage.media,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: true,
    ));
    // log.i(
    //     "Audio input devices: ${await recordingSession.getDevices(includeOutputs: false)}");

    _firebaseService.listenToRoomMessages(
        roomId: "1234", playFileCallback: playAudioUrl);
  }

  Future startRecordingAudio() async {
    String filename = "audio.$fileExtension";
    String directory = await ensureDirectory();
    String path = "$directory/$filename";
    try {
      if (await recorder.hasPermission()) {
        if (!(await recorder.isEncoderSupported(_audioEncoder))) {
          log.e("Cannot encode to AAC.");
          _snackbarService.showSnackbar(
            title: 'Error recording!',
            message:
                'It may be that we don\'t support audio codec $_audioEncoder on your phone.',
          );
          return;
        }

        playMicOnSound();
        if (await recordingSession.setActive(true)) {
          await recorder.start(
            path: path,
            encoder: _audioEncoder,
            // by default
            bitRate: 128000, // by default
            numChannels: 1,
            samplingRate: 16000, // by default
          );
          isRecording = true;
          notifyListeners();
        }
      } else {
        _snackbarService.showSnackbar(
          title: 'Permission Denied',
          message: 'The app needs permission to record audio.',
        );
      }
    } catch (e) {
      log.wtf("ERROR RECORDING: $e");
      _snackbarService.showSnackbar(
        title: 'Error recording!',
        message: 'It may be that we don\'t support your phone.',
      );
    }
  }

  Future<String> ensureDirectory() async {
    Directory directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future stopRecordingAudio() async {
    playMicOffSound();
    String? path = await recorder.stop();
    await recordingSession.setActive(false);
    if (path != null) {
      if (!audioList.contains(path)) {
        audioList.add(path);
      }
      log.i("Recorded file saved to $path");
      try {
        _firebaseService.uploadFile(
          path: path,
          filename: path.split("/").last,
        );
      } catch (e) {
        log.wtf("Error uploading file: $e");
        _snackbarService.showSnackbar(
          title: 'Error uploading file',
          message: "Error for devs: $e",
        );
      }
    } else {
      _snackbarService.showSnackbar(
        title: 'Error',
        message: 'Path is none!',
      );
    }
    isRecording = false;
    notifyListeners();
  }

  Future<bool> deleteAudio({required int index}) async {
    setBusy(true);
    File file = File(audioList[index]);
    log.i("deleting $file");
    try {
      await file.delete();
      audioList.removeAt(index);
    } catch (e) {
      log.e("Cannot delte file due to error : $e");
    }
    setBusy(false);
    return true;
  }

  Future<bool> playAudioLocal({required int index}) async {
    String path = audioList[index];
    isPlayingAudioWithIndex = index;
    notifyListeners();
    await play(path: path);
    return true;
  }

  Future playAudioUrl(String ref) async {
    log.i("download audio from ref: $ref");

    receivingAudio = true;
    notifyListeners();

    File file = await _firebaseService.writeToFile(ref);

    receivingAudio = false;
    notifyListeners();

    await play(path: file.path);
  }

  Future playMicOnSound() async {
    playingSoundEffect = true;
    try {
      await _audioPlayer.setAsset(kaSoundEffectBeepPath);
      await _audioPlayer.play();
    } catch (e) {
      log.e("Error playing on sound effect: $e");
    }
    playingSoundEffect = false;
  }

  Future playMicOffSound() async {
    playingSoundEffect = true;
    try {
      await _audioPlayer.setAsset(kaSoundEffectStopPath);
      await _audioPlayer.play();
    } catch (e) {
      log.e("Error playing off sound effect: $e");
    }
    playingSoundEffect = false;
  }

  Future play({required String path}) async {
    try {
      log.i("Play audio $path");
      await _audioPlayer.setFilePath(path);
      if (await session.setActive(true)) {
        await _audioPlayer.play();
      } else {
        log.wtf("Audio session was denied!");
      }
    } catch (e) {
      log.e("Could not play audio from local file: $e");
      _snackbarService.showSnackbar(
          message: "Error playing audio", duration: const Duration(seconds: 2));
      playingAudio = false;
      notifyListeners();
    }
  }

  Future togglePorcupine(bool value) async {
    if (value) {
      await _porcupineService.startProcessing();
    } else {
      await _porcupineService.stopProcessing();
    }
  }

  Future showNotImplementedDialog() async {
    _snackbarService.showSnackbar(
      title: 'Not Implemented',
      message: 'This feature has not yet been implemented.',
      duration: const Duration(seconds: 1),
    );
  }

  void showTutorialDialog() {
    _dialogService.showDialog(
        title: ksJamTalkieHomeTutorialDialogTitle,
        description: ksJamTalkieHomeTutorialDialogDescription +
            (Platform.isAndroid
                ? " You can also use 'Talkie on' and 'Talkie over' as voice commands once enabled."
                : ""),
        barrierDismissible: true);
  }

  void setUserId(int userId) {
    _firebaseService.setUserId(userId);
    notifyListeners();
  }

  void toggleDebugMode() {
    if (debugMode) {
      debugMode = false;
    } else {
      debugMode = true;
    }
    notifyListeners();
  }

  @override
  void dispose() async {
    super.dispose();
    await _audioPlayer.dispose();
  }
}
