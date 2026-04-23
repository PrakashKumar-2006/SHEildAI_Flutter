import 'dart:async';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class VideoRecordingService {
  static final VideoRecordingService _instance = VideoRecordingService._internal();
  factory VideoRecordingService() => _instance;

  VideoRecordingService._internal();

  CameraController? _controller;
  String? _videoPath;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _remainingSeconds = 120; // 2 minutes max
  final StreamController<String> _recordingStatusController = StreamController<String>.broadcast();
  final StreamController<int> _remainingTimeController = StreamController<int>.broadcast();

  Stream<String> get recordingStatusStream => _recordingStatusController.stream;
  Stream<int> get remainingTimeStream => _remainingTimeController.stream;
  bool get isRecording => _isRecording;
  String? get videoPath => _videoPath;
  int get remainingSeconds => _remainingSeconds;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      _recordingStatusController.addError('No cameras available');
      return;
    }

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: true,
    );

    try {
      await _controller!.initialize();
      _recordingStatusController.add('camera_ready');
    } catch (e) {
      _recordingStatusController.addError('Failed to initialize camera: $e');
    }
  }

  Future<void> startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      await initializeCamera();
    }

    if (_controller == null) {
      _recordingStatusController.addError('Camera not available');
      return;
    }

    try {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/sos_video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      await _controller!.startVideoRecording();
      _videoPath = path;
      _isRecording = true;
      _remainingSeconds = 120;

      _recordingStatusController.add('recording');
      _remainingTimeController.add(_remainingSeconds);

      // Start countdown timer
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _remainingSeconds--;
        _remainingTimeController.add(_remainingSeconds);

        if (_remainingSeconds <= 0) {
          stopRecording();
        }
      });
    } catch (e) {
      _recordingStatusController.addError('Failed to start recording: $e');
    }
  }

  Future<void> stopRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      final video = await _controller!.stopVideoRecording();
      _videoPath = video.path;
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;

      _recordingStatusController.add('stopped');
    } catch (e) {
      _recordingStatusController.addError('Failed to stop recording: $e');
    }
  }

  Future<void> cancelRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) {
      return;
    }

    try {
      await _controller!.stopVideoRecording();
      _isRecording = false;
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _videoPath = null;

      _recordingStatusController.add('cancelled');
    } catch (e) {
      _recordingStatusController.addError('Failed to cancel recording: $e');
    }
  }

  void dispose() {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _controller?.dispose();
    _controller = null;
    _recordingStatusController.close();
    _remainingTimeController.close();
  }

  Future<File?> getVideoFile() async {
    if (_videoPath == null) return null;
    return File(_videoPath!);
  }

  Future<void> deleteVideo() async {
    if (_videoPath != null) {
      final file = File(_videoPath!);
      if (await file.exists()) {
        await file.delete();
      }
      _videoPath = null;
    }
  }
}
