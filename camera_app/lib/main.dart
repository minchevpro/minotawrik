import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

late List<CameraDescription> _cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    _cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error in fetching the cameras: $e');
    _cameras = [];
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    if (_cameras.isEmpty) {
      debugPrint('No cameras found');
      return;
    }

    final controller = CameraController(
      _cameras[0],
      ResolutionPreset.max,
      enableAudio: true,
    );

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _controller = controller;
      });
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (_isRecording) {
      try {
        final file = await controller.stopVideoRecording();
        setState(() {
          _isRecording = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Video saved to ${file.path}')),
          );
        }
      } catch (e) {
        debugPrint('Error stopping video recording: $e');
      }
    } else {
      try {
        await controller.startVideoRecording();
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        debugPrint('Error starting video recording: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: Text('No Camera Available or Initializing...')),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_controller!),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: _toggleRecording,
                backgroundColor: _isRecording ? Colors.red : Colors.white,
                child: Icon(
                  _isRecording ? Icons.stop : Icons.videocam,
                  color: _isRecording ? Colors.white : Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
