import 'package:flutter/material.dart';
import 'package:jamtalkie/ui/common/ui_helpers.dart';

class MicrophoneButton extends StatefulWidget {
  final Function onRecordStart;
  final Function onRecordStop;

  const MicrophoneButton({
    Key? key,
    required this.onRecordStart,
    required this.onRecordStop,
  }) : super(key: key);

  @override
  _MicrophoneButtonState createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends State<MicrophoneButton> {
  bool _isRecording = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() {
          _isRecording = true;
        });
        widget.onRecordStart();
      },
      onTapUp: (_) {
        setState(() {
          _isRecording = false;
        });
        widget.onRecordStop();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: screenWidth(context) * 0.55,
            height: screenWidth(context) * 0.55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue[400],
            ),
          ),
          if (_isRecording)
            Container(
              width: screenWidth(context) * 0.55 - 20,
              height: screenWidth(context) * 0.55 - 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.7),
              ),
              child: const Icon(
                Icons.mic,
                color: Colors.white,
                size: 80,
              ),
            ),
          if (!_isRecording)
            const Icon(
              Icons.mic,
              color: Color.fromARGB(255, 0, 77, 140),
              size: 80,
            ),
        ],
      ),
    );
  }
}
