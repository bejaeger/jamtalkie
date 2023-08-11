import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:jamtalkie/app/app.locator.dart';
import 'package:jamtalkie/services/firebase_service.dart';
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
  // final audioplayers.AudioPlayer __audioPlayer = audioplayers.AudioPlayer();
  final log = getLogger("JamtalkieHomeViewModel");
  late AudioSession session;

  Stream<PlayerState> get playerState => _audioPlayer.playerStateStream;
  int get userId => _firebaseService.userIdPublic;

  List<String> audioList = [];
  bool debugMode = false;
  final AudioEncoder _audioEncoder =
      Platform.isIOS ? AudioEncoder.flac : AudioEncoder.aacLc;
  final String fileExtension = Platform.isIOS ? "flac" : "m4a";

  int isPlayingAudioWithIndex = -1;
  bool isRecording = false;
  bool receivingAudio = false;
  bool playingAudio = false;

  Future<void> init() async {
    session = await AudioSession.instance;

    playerState.listen((event) async {
      if ((event.processingState == ProcessingState.loading ||
              event.processingState == ProcessingState.buffering ||
              event.playing) &&
          event.processingState != ProcessingState.completed) {
        playingAudio = true;
        notifyListeners();
      }
      if (event.processingState == ProcessingState.completed) {
        log.i("Completed playing audio");
        bool ok = await session.setActive(false);
        if (!ok) {
          log.wtf("Could not deactivate audio session");
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

    _firebaseService.listenToRoomMessages(
        roomId: "1234", playFileCallback: playAudioUrl);
  }

  Future recordAudio() async {
    String filename =
        "Audio-${DateTime.now().microsecondsSinceEpoch}.$fileExtension";
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

  Future stopRecording() async {
    String? path = await recorder.stop();
    if (path != null) {
      audioList.add(path);
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
    await file.delete();
    audioList.removeAt(index);
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
        description: ksJamTalkieHomeTutorialDialogDescription,
        barrierDismissible: true);
  }

  void setUserId(int userId) {
    _firebaseService.setUserId(userId);
    notifyListeners();
  }

  void switchDebugMode(bool value) {
    debugMode = value;
    notifyListeners();
  }

  @override
  void dispose() async {
    super.dispose();
    await _audioPlayer.dispose();
  }
}
