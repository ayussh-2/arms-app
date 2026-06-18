import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class StudentCropScreen extends StatefulWidget {
  const StudentCropScreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  State<StudentCropScreen> createState() => _StudentCropScreenState();
}

class _StudentCropScreenState extends State<StudentCropScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _isProcessing = false;
  bool _isImageLoaded = false;
  double _origWidth = 0;
  double _origHeight = 0;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final ui.Image uiImage = await decodeImageFromList(bytes);
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
          _origWidth = uiImage.width.toDouble();
          _origHeight = uiImage.height.toDouble();
          _isImageLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load image: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _cropImage(double viewportSize) async {
    if (_imageBytes == null || _origWidth == 0 || _origHeight == 0) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      // 1. Get transformation matrix values
      final Matrix4 matrix = _transformationController.value;
      final double scale = matrix.row0.r0; // zoom scale factor
      final double tx = matrix.row0.r3;    // translation x (usually negative)
      final double ty = matrix.row1.r3;    // translation y (usually negative)

      // 2. Calculate aspect ratios and initial display sizes
      final double imageAspectRatio = _origWidth / _origHeight;
      double initialDisplayWidth;
      double initialDisplayHeight;

      if (imageAspectRatio >= 1.0) {
        // Landscape or square: initial height fits viewport height
        initialDisplayHeight = viewportSize;
        initialDisplayWidth = viewportSize * imageAspectRatio;
      } else {
        // Portrait: initial width fits viewport width
        initialDisplayWidth = viewportSize;
        initialDisplayHeight = viewportSize / imageAspectRatio;
      }

      // Total scale factor from original file to currently displayed zoom level
      final double totalScale = scale * (initialDisplayWidth / _origWidth);

      // 3. Compute crop boundaries in original image coordinates
      final double xCrop = -tx / totalScale;
      final double yCrop = -ty / totalScale;
      final double cropSize = viewportSize / totalScale;

      // Ensure boundaries are clamped within original image bounds
      final int x = xCrop.round().clamp(0, (_origWidth - cropSize).round());
      final int y = yCrop.round().clamp(0, (_origHeight - cropSize).round());
      final int size = cropSize.round().clamp(10, (_origWidth < _origHeight ? _origWidth : _origHeight).round());

      // 4. Crop image in background / synchronously
      final srcImage = img.decodeImage(_imageBytes!);
      if (srcImage == null) throw Exception('Failed to parse image for cropping.');

      final croppedImage = img.copyCrop(
        srcImage,
        x: x,
        y: y,
        width: size,
        height: size,
      );

      final croppedBytes = img.encodeJpg(croppedImage, quality: 85);

      // 5. Save to temp folder and return
      final tempDir = await getTemporaryDirectory();
      final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await croppedFile.writeAsBytes(croppedBytes);

      if (mounted) {
        Navigator.pop(context, croppedFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error cropping image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
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
          'Crop Portrait to Square',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_isImageLoaded && !_isProcessing)
            IconButton(
              icon: const Icon(Icons.check_rounded, color: AppColors.successText, size: 28),
              onPressed: () => _cropImage(viewportSize),
            ),
        ],
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text(
                    'Cropping image...',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            )
          : !_isImageLoaded
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                      child: Text(
                        'Pinch to Zoom • Drag to Pan • Align face inside the box',
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Container(
                          width: viewportSize,
                          height: viewportSize,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          child: Stack(
                            children: [
                              // Interactive Viewer
                              ClipRect(
                                child: InteractiveViewer(
                                  transformationController: _transformationController,
                                  boundaryMargin: EdgeInsets.zero,
                                  minScale: 1.0,
                                  maxScale: 5.0,
                                  child: _buildImageContainer(viewportSize),
                                ),
                              ),
                              // 3x3 Grid Overlay
                              IgnorePointer(
                                child: CustomPaint(
                                  size: Size(viewportSize, viewportSize),
                                  painter: GridPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('Cancel', style: TextStyle(color: Colors.white)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _cropImage(viewportSize),
                            icon: const Icon(Icons.crop, color: Colors.black),
                            label: const Text('Crop Image', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildImageContainer(double viewportSize) {
    if (_imageBytes == null) return const SizedBox.shrink();

    final double imageAspectRatio = _origWidth / _origHeight;
    double displayWidth;
    double displayHeight;

    if (imageAspectRatio >= 1.0) {
      // Landscape: fit height to viewport, width overflows
      displayHeight = viewportSize;
      displayWidth = viewportSize * imageAspectRatio;
    } else {
      // Portrait: fit width to viewport, height overflows
      displayWidth = viewportSize;
      displayHeight = viewportSize / imageAspectRatio;
    }

    return Image.memory(
      _imageBytes!,
      width: displayWidth,
      height: displayHeight,
      fit: BoxFit.fill,
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
