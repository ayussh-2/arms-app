import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

class StudentCameraScreen extends StatefulWidget {
  const StudentCameraScreen({super.key});

  @override
  State<StudentCameraScreen> createState() => _StudentCameraScreenState();
}

class _StudentCameraScreenState extends State<StudentCameraScreen> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitialized = false;
  int _selectedCameraIndex = 0;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setupController();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No cameras available on this device.')),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      // Default to the BACK camera first, fallback to front.
      _selectedCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = _cameras.indexWhere(
          (camera) => camera.lensDirection == CameraLensDirection.front,
        );
      }
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0;
      }

      await _setupController();
    } catch (e) {
      _showError('Error accessing cameras: $e');
    }
  }

  Future<void> _setupController() async {
    if (_cameras.isEmpty) return;

    if (_controller != null) {
      await _controller!.dispose();
    }

    final controller = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    _controller = controller;

    try {
      await controller.initialize();
      await controller.setFlashMode(_flashMode);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      _showError('Camera initialization failed: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _toggleCamera() async {
    if (_cameras.length < 2) return;
    setState(() {
      _isInitialized = false;
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    });
    await _setupController();
  }

  Future<void> _cycleFlashMode() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
        nextMode = FlashMode.always;
        break;
      case FlashMode.always:
        nextMode = FlashMode.off;
        break;
      default:
        nextMode = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _flashMode = nextMode;
      });
    } catch (e) {
      _showError('Failed to change flash mode: $e');
    }
  }

  Future<void> _capturePhoto(double viewportSize) async {
    if (_controller == null || !_controller!.value.isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      // 1. Capture full photo
      final XFile rawFile = await _controller!.takePicture();
      final File file = File(rawFile.path);

      // 2. Decode the raw photo in memory
      final bytes = await file.readAsBytes();
      final rawImage = img.decodeImage(bytes);
      if (rawImage == null) throw Exception('Failed to decode captured image.');

      final image = img.bakeOrientation(rawImage);

      // 3. Center crop to 1:1 square
      final int width = image.width;
      final int height = image.height;
      final int size = width < height ? width : height;

      final int x = (width - size) ~/ 2;
      final int y = (height - size) ~/ 2;

      final croppedImage = img.copyCrop(
        image,
        x: x,
        y: y,
        width: size,
        height: size,
      );

      // 4. Encode as Jpeg and save back to temp file
      final croppedBytes = img.encodeJpg(croppedImage, quality: 85);
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File('${tempDir.path}/cam_crop_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await croppedFile.writeAsBytes(croppedBytes);

      // Clean up raw image file
      try {
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      _showError('Failed to capture photo: $e');
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double viewportSize = screenWidth - 32;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Capture Student Photo',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isInitialized)
            IconButton(
              icon: Icon(
                _flashMode == FlashMode.off
                    ? Icons.flash_off_rounded
                    : _flashMode == FlashMode.auto
                        ? Icons.flash_auto_rounded
                        : Icons.flash_on_rounded,
                color: _flashMode == FlashMode.off ? Colors.white54 : Colors.yellowAccent,
              ),
              onPressed: _cycleFlashMode,
            ),
        ],
      ),
      body: !_isInitialized
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final double widthLimit = constraints.maxWidth;
                final double heightLimit = constraints.maxHeight;

                // rawRatio of the camera is width / height in landscape (usually 4/3 or 16/9, i.e. > 1.0)
                final double cameraRatio = _controller!.value.aspectRatio;
                // For portrait rendering, the aspect ratio of the widget should be inverted (i.e. < 1.0)
                final double previewRatio = 1 / cameraRatio;

                // Scale the preview size so it fills the available screen space without squishing
                double previewWidth = widthLimit;
                double previewHeight = widthLimit / previewRatio;

                if (previewHeight < heightLimit) {
                  previewHeight = heightLimit;
                  previewWidth = heightLimit * previewRatio;
                }

                final double leftOffset = (widthLimit - previewWidth) / 2;
                final double topOffset = (heightLimit - previewHeight) / 2;

                return Stack(
                  children: [
                    // 1. Center cropped full-screen/full-body camera feed
                    Positioned(
                      left: leftOffset,
                      top: topOffset,
                      width: previewWidth,
                      height: previewHeight,
                      child: CameraPreview(_controller!),
                    ),

                    // 2. Dark overlay with transparent center cutout hole
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: HolePainter(holeSize: viewportSize),
                        ),
                      ),
                    ),

                    // 3. Grid overlay inside the active crop viewport
                    Center(
                      child: IgnorePointer(
                        child: Container(
                          width: viewportSize,
                          height: viewportSize,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: CustomPaint(
                            size: Size(viewportSize, viewportSize),
                            painter: GridPainter(),
                          ),
                        ),
                      ),
                    ),

                    // 4. Instructional Text Overlay at top
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 20,
                      child: IgnorePointer(
                        child: Text(
                          'Align student\'s face in the center of the grid',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ),

                    // 5. Shutter and control buttons overlay at bottom
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 48,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Switch Camera Button
                          IconButton(
                            icon: const Icon(
                              Icons.flip_camera_ios_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: _cameras.length < 2 ? null : _toggleCamera,
                          ),
                          // Capture Shutter Button
                          GestureDetector(
                            onTap: () => _capturePhoto(viewportSize),
                            child: Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 4),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: Container(
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: _isCapturing
                                    ? const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          color: Colors.black,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                          // Balanced UI placeholder
                          const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.0;

    // Draw vertical lines
    canvas.drawLine(Offset(size.width / 3, 0), Offset(size.width / 3, size.height), paint);
    canvas.drawLine(Offset(size.width * 2 / 3, 0), Offset(size.width * 2 / 3, size.height), paint);

    // Draw horizontal lines
    canvas.drawLine(Offset(0, size.height / 3), Offset(size.width, size.height / 3), paint);
    canvas.drawLine(Offset(0, size.height * 2 / 3), Offset(size.width, size.height * 2 / 3), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HolePainter extends CustomPainter {
  HolePainter({required this.holeSize});
  final double holeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = (size.width - holeSize) / 2;
    final double top = (size.height - holeSize) / 2;

    // Draw dark transparent overlay with cutout using PathFillType.evenOdd
    final Path path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(Rect.fromLTWH(left, top, holeSize, holeSize));

    path.fillType = PathFillType.evenOdd;

    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.7)
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant HolePainter oldDelegate) => oldDelegate.holeSize != holeSize;
}
