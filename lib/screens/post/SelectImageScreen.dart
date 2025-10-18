import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class SelectImageScreen extends StatefulWidget {
  const SelectImageScreen({super.key});

  @override
  State<SelectImageScreen> createState() => _SelectImageScreenState();
}

class _SelectImageScreenState extends State<SelectImageScreen> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  int _selectedCameraIndex = 0;
  XFile? _imageFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera([int cameraIndex = 0]) async {
    try {
      cameras = await availableCameras();
      if (cameras!.isNotEmpty) {
        _cameraController = CameraController(
          cameras![cameraIndex],
          ResolutionPreset.max,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error al inicializar cámara: $e");
    }
  }

  Future<void> _switchCamera() async {
    if (cameras == null || cameras!.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % cameras!.length;
    await _cameraController?.dispose();
    await _initCamera(_selectedCameraIndex);
  }

  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final photo = await _cameraController!.takePicture();
      setState(() => _imageFile = photo);
    } catch (e) {
      debugPrint("Error al tomar foto: $e");
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = pickedFile);
  }

  Future<void> _fetchUnsplashImage() async {
    final unsplashKey = dotenv.env['UNSPLASH_KEY'];
    if (unsplashKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se encontró la API key de Unsplash")));
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse("https://api.unsplash.com/photos/random?client_id=$unsplashKey"),
      );

      if (res.statusCode != 200) throw Exception("Error Unsplash ${res.statusCode}");
      final data = jsonDecode(res.body);
      final imageUrl = data["urls"]["regular"];
      final response = await http.get(Uri.parse(imageUrl));
      final tempDir = Directory.systemTemp;
      final file = File("${tempDir.path}/unsplash_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await file.writeAsBytes(response.bodyBytes);

      setState(() => _imageFile = XFile(file.path));
    } catch (e) {
      debugPrint("Error al obtener imagen de Unsplash: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error al obtener imagen")));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isImageSelected = _imageFile != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 🔹 Fondo: cámara o imagen
            Positioned.fill(
              child: isImageSelected
                  ? Image.file(
                      File(_imageFile!.path),
                      fit: BoxFit.cover,
                    )
                  : (_cameraController != null &&
                          _cameraController!.value.isInitialized)
                      ? CameraPreview(_cameraController!)
                      : const Center(child: CircularProgressIndicator()),
            ),

            // 🔹 Controles
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: Colors.white),
                    ),

                  // 📸 Botones principales
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _cameraButton(
                        icon: Icons.switch_camera,
                        label: "Cambiar cámara",
                        onPressed: _switchCamera,
                      ),
                      _cameraButton(
                        icon: Icons.camera_alt,
                        label: "Tomar foto",
                        onPressed: _takePhoto,
                      ),
                      _cameraButton(
                        icon: Icons.photo_library,
                        label: "Galería",
                        onPressed: _pickFromGallery,
                      ),
                      _cameraButton(
                        icon: Icons.image_search,
                        label: "Unsplash",
                        onPressed: _fetchUnsplashImage,
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ✅ Botón continuar
                  if (isImageSelected)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 30, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20)),
                      ),
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/addDescription',
                          arguments: _imageFile,
                        );
                      },
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text(
                        "Continuar con esta imagen",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        IconButton(
          icon: Icon(icon, size: 36, color: Colors.white),
          onPressed: onPressed,
        ),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}
