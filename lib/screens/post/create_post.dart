import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class CreatePost extends StatefulWidget {
  const CreatePost({super.key});

  @override
  State<CreatePost> createState() => _CreatePostState();
}

class _CreatePostState extends State<CreatePost> {
  CameraController? _cameraController;
  List<CameraDescription>? cameras;
  XFile? _imageFile;
  bool _loading = false;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      cameras = await availableCameras();
      if (cameras!.isNotEmpty) {
        _cameraController = CameraController(
          cameras!.first,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint("Error al inicializar cámara: $e");
    }
  }

  // 📸 Tomar foto con cámara
  Future<void> _takePhoto() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      final photo = await _cameraController!.takePicture();
      setState(() => _imageFile = photo);
    } catch (e) {
      debugPrint("Error al tomar foto: $e");
    }
  }

  // 🖼 Seleccionar imagen desde galería
  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() => _imageFile = pickedFile);
  }

  // 🌄 Obtener imagen aleatoria de Unsplash
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

      if (res.statusCode != 200) {
        debugPrint("Error Unsplash ${res.statusCode}: ${res.body}");
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error al obtener imagen: ${res.statusCode}")));
        return;
      }

      final data = jsonDecode(res.body);
      final imageUrl = data["urls"]["small"];
      final response = await http.get(Uri.parse(imageUrl));
      final tempDir = Directory.systemTemp;
      final file = File("${tempDir.path}/unsplash_${DateTime.now().millisecondsSinceEpoch}.jpg");
      await file.writeAsBytes(response.bodyBytes);

      setState(() => _imageFile = XFile(file.path));
    } catch (e) {
      debugPrint("Error al obtener imagen de Unsplash: $e");
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error al obtener imagen de Unsplash")));
    } finally {
      setState(() => _loading = false);
    }
  }

  // 💬 Generar descripción usando GMeni (OpenAI)
  // 💬 Generar caption + hashtags usando GMeni (OpenAI)
Future<void> _generateDescription() async {
  final openaiKey = dotenv.env['OPENAI_KEY'];
  if (openaiKey == null) return;

  setState(() => _loading = true);

  try {
    final userCaption = _captionController.text.trim();

    final prompt = userCaption.isEmpty
        ? "Crea una descripción breve y atractiva para una foto de Instagram, con 5-10 hashtags relevantes."
        : "Mejora esta descripción para Instagram haciéndola más atractiva y añade 5-10 hashtags relevantes:\n$userCaption";

    final res = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $openaiKey",
      },
      body: jsonEncode({
        "model": "gpt-4o-mini",  // ChatGPT
        "messages": [
          {
            "role": "system",
            "content": "Eres un asistente creativo que mejora descripciones para Instagram."
          },
          {"role": "user", "content": prompt},
        ],
      }),
    );

    final data = jsonDecode(res.body);
    final description = data["choices"]?[0]?["message"]?["content"];
    if (description != null) {
      setState(() => _captionController.text = description);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No se pudo generar la descripción")));
    }
  } catch (e) {
    debugPrint("Error al mejorar descripción: $e");
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Error al generar descripción")));
  } finally {
    setState(() => _loading = false);
  }
}




  // 🚀 Enviar publicación
  Future<void> _handleSubmit() async {
    if (_imageFile == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Selecciona una imagen")));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final apiUrl = dotenv.env['API_URL'];

    if (token == null || apiUrl == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text("Error: token o API_URL no encontrados")));
      return;
    }

    final request = http.MultipartRequest("POST", Uri.parse("$apiUrl/api/create"));
    request.headers["Authorization"] = "Bearer $token";
    request.files.add(await http.MultipartFile.fromPath(
      "image",
      _imageFile!.path,
      filename: "photo.jpg",
      contentType: MediaType('image', 'jpeg'),
    ));
    request.fields["caption"] = _captionController.text;

    try {
      setState(() => _loading = true);
      final res = await request.send();
      final response = await http.Response.fromStream(res);

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("✅ Publicación creada correctamente")));
        Navigator.pushNamed(context, '/feed');
      } else {
        debugPrint("Error: ${response.body}");
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Error: ${response.body}")));
      }
    } catch (e) {
      debugPrint("Error al enviar publicación: $e");
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = isDark
        ? {
            "bg": const Color(0xFF121212),
            "text": Colors.white,
            "icon": const Color(0xFF1E90FF),
            "card": const Color(0xFF1E1E1E),
          }
        : {
            "bg": const Color(0xFFF2F2F7),
            "text": const Color(0xFF111111),
            "icon": const Color(0xFF007BFF),
            "card": Colors.white,
          };

    return Scaffold(
      backgroundColor: theme["bg"] as Color,
      body: SafeArea(
        child: Column(
          children: [
            // 📸 Cámara en pantalla superior
            if (_cameraController != null && _cameraController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _cameraController!.value.aspectRatio,
                child: CameraPreview(_cameraController!),
              )
            else
              const SizedBox(height: 250, child: Center(child: CircularProgressIndicator())),

            if (_imageFile != null)
              Container(
                margin: const EdgeInsets.all(10),
                child: Image.file(File(_imageFile!.path),
                    width: 200, height: 200, fit: BoxFit.cover),
              ),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // 📝 Caption
                    Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme["card"] as Color,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: TextField(
                        controller: _captionController,
                        maxLines: null,
                        decoration: InputDecoration(
                          hintText: "Escribe una descripción...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: (theme["text"] as Color).withOpacity(0.6)),
                        ),
                        style: TextStyle(color: theme["text"] as Color),
                      ),
                    ),

                    // 🔘 Barra de iconos: Cámara, Galería, Unsplash, GMeni
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        IconButton(
                          icon: Icon(Icons.camera_alt_outlined,
                              color: theme["icon"] as Color, size: 40),
                          onPressed: _takePhoto,
                        ),
                        IconButton(
                          icon: Icon(Icons.photo_library_outlined,
                              color: theme["icon"] as Color, size: 40),
                          onPressed: _pickFromGallery,
                        ),
                        IconButton(
                          icon: Icon(Icons.image_outlined,
                              color: theme["icon"] as Color, size: 40),
                          onPressed: _fetchUnsplashImage,
                        ),
                        IconButton(
                          icon: Icon(Icons.auto_awesome_outlined,
                              color: theme["icon"] as Color, size: 40),
                          onPressed: _generateDescription,
                        ),
                      ],
                    ),

                    // 🚀 Botón publicar
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme["icon"] as Color,
                          padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _handleSubmit,
                        child: _loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text("Publicar",
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
