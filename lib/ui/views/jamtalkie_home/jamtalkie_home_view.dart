import 'package:flutter/material.dart';
import 'package:jamtalkie/ui/common/ui_helpers.dart';
import 'package:jamtalkie/ui/widgets/custom_safe_area.dart';
import 'package:jamtalkie/ui/widgets/microphone_button.dart';
import 'package:stacked/stacked.dart';

import 'jamtalkie_home_viewmodel.dart';

class JamtalkieHomeView extends StackedView<JamtalkieHomeViewModel> {
  const JamtalkieHomeView({Key? key}) : super(key: key);

  @override
  void onViewModelReady(JamtalkieHomeViewModel viewModel) {
    super.onViewModelReady(viewModel);
    viewModel.init();
  }

  @override
  Widget builder(
    BuildContext context,
    JamtalkieHomeViewModel viewModel,
    Widget? child,
  ) {
    return CustomSafeArea(
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: Container(
          height: screenHeight(context),
          padding: const EdgeInsets.only(left: 25.0, right: 25.0),
          child: Column(
            children: [
              verticalSpaceMedium,
              verticalSpaceSmall,
              const Center(
                child: Text(
                  'WELCOME to JamTalkie!',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                  // textAlign: TextAlign.center,
                ),
              ),
              verticalSpaceLarge,
              GestureDetector(
                onTap: viewModel.showTutorialDialog,
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded),
                    horizontalSpaceSmall,
                    Text("How it works?"),
                  ],
                ),
              ),
              verticalSpaceSmall,
              Row(
                children: [
                  const Icon(Icons.person_2_outlined),
                  horizontalSpaceSmall,
                  const Text("Choose user"),
                  horizontalSpaceSmall,
                  MaterialButton(
                    onPressed: () => viewModel.setUserId(1),
                    color: viewModel.userId == 1
                        ? Colors.blue
                        : Theme.of(context).colorScheme.background,
                    child: const Text('User 1'),
                  ),
                  MaterialButton(
                    onPressed: () => viewModel.setUserId(2),
                    color: viewModel.userId == 2
                        ? Colors.blue
                        : Theme.of(context).colorScheme.background,
                    child: const Text('User 2'),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.list_alt_rounded),
                  horizontalSpaceSmall,
                  const Text("Show audio list"),
                  Switch(
                      value: viewModel.debugMode,
                      onChanged: (value) => viewModel.switchDebugMode(value)),
                ],
              ),
              const Spacer(flex: 1),
              SizedBox(
                height: 25,
                child: viewModel.receivingAudio
                    ? const Text("Receiving audio...")
                    : viewModel.playingAudio
                        ? const Text("Playing audio...")
                        : const Text(""),
              ),
              MicrophoneButton(
                onRecordStart: viewModel.recordAudio,
                onRecordStop: viewModel.stopRecording,
              ),
              verticalSpaceSmall,
              const Text("Hold to record audio",
                  style: TextStyle(
                      fontSize: 14,
                      color: Color.fromARGB(255, 0, 77, 140),
                      fontWeight: FontWeight.w800)),
              verticalSpaceMedium,
              if (viewModel.debugMode)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  padding: const EdgeInsets.all(5),
                  child: ListView.builder(
                    itemCount: viewModel.audioList.length,
                    itemBuilder: (BuildContext context, int index) {
                      return ListTile(
                        title: Text(viewModel.audioList[index].split("/").last),
                        trailing: SizedBox(
                          width: 100,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () =>
                                    viewModel.deleteAudio(index: index),
                                icon: const Icon(Icons.delete),
                              ),
                              IconButton(
                                  onPressed:
                                      viewModel.isPlayingAudioWithIndex == index
                                          ? viewModel.showNotImplementedDialog
                                          : () => viewModel.playAudioLocal(
                                              index: index),
                                  icon:
                                      viewModel.isPlayingAudioWithIndex == index
                                          ? const Icon(Icons.pause)
                                          : const Icon(Icons.play_arrow)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              // AudioPlayer(
              //     source: audioPath!,
              //     onDelete: () {
              //       setState(() => showPlayer = false);
              //     },
              //   ),
              if (!viewModel.debugMode) const Spacer(flex: 1),
              if (viewModel.debugMode) verticalSpaceSmall
            ],
          ),
        ),
      ),
    );
  }

  @override
  JamtalkieHomeViewModel viewModelBuilder(
    BuildContext context,
  ) =>
      JamtalkieHomeViewModel();
}
