import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class AddDescriptionScreen extends StatefulWidget {
  final XFile imageFile;
  const AddDescriptionScreen({super.key, required this.imageFile});

  @override
  State<AddDescriptionScreen> createState() => _AddDescriptionScreenState();
}

class _AddDescriptionScreenState extends State<AddDescriptionScreen> {
  final TextEditingController _captionController = TextEditingController();
  bool _loading = false;
  String? _errorMessage;

  // 🔹 Genera descripción con Gemini usando texto + imagen
Future<void> _generateDescription() async {
  setState(() {
    _loading = true;
    _errorMessage = null;
  });

  try {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      setState(() => _errorMessage = "⚠️ No se encontró la clave GEMINI_API_KEY");
      return;
    }

    final prompt = _captionController.text.trim().isEmpty
        ? "Crea una descripción breve, atractiva y con hashtags para Instagram. que sea super corta y que solo mandame el texto mejorado sin nada mas y se brebe entre 2 a 3 lineas"
        : "Mejora esta descripción para Instagram Crea una descripción breve, atractiva y con hashtags para Instagram. que sea super corta y que solo mandame el texto mejorado sin nada mas y se brebe entre 2 a 3 lineas: ${_captionController.text}. Hazla atractiva, natural y con hashtags adecuados.";

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=$apiKey',
    );

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "role": "user",
            "parts": [
              {"text": prompt}
            ]
          }
        ]
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

      if (text != null && text.isNotEmpty) {
        setState(() => _captionController.text = text);
      } else {
        setState(() => _errorMessage =
            "⚠️ Gemini respondió sin contenido, intenta nuevamente.");
      }
    } else {
      final err = jsonDecode(response.body);
      setState(() => _errorMessage =
          "❌ Error Gemini: ${err['error']?['message'] ?? response.body}");
    }
  } catch (e, stack) {
    debugPrint("❌ Excepción: $e");
    debugPrint("📜 StackTrace: $stack");
    setState(() => _errorMessage = "❌ Error inesperado: $e");
  } finally {
    setState(() => _loading = false);
  }
}


  // 🔹 Permite listar los modelos disponibles (debug)
  Future<void> listAvailableModels() async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final res = await http.get(
      Uri.parse('https://generativelanguage.googleapis.com/v1/models?key=$apiKey'),
    );
    debugPrint(res.body);
  }

  // 🔹 Envía publicación al backend
  Future<void> _handleSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString("token");
    final apiUrl = dotenv.env['API_URL'];

    if (token == null || apiUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: token o API_URL no encontrados")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final request =
          http.MultipartRequest("POST", Uri.parse("$apiUrl/api/create"));
      request.headers["Authorization"] = "Bearer $token";
      request.files.add(await http.MultipartFile.fromPath(
        "image",
        widget.imageFile.path,
        filename: "photo.jpg",
        contentType: MediaType('image', 'jpeg'),
      ));
      request.fields["caption"] = _captionController.text;

      final res = await request.send();
      final response = await http.Response.fromStream(res);

      if (res.statusCode == 200 || res.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Publicación creada correctamente")),
        );
        Navigator.pushNamed(context, '/verpost');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${response.body}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error al publicar: $e")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("Agregar descripción"),
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _loading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 100),
                    child: CircularProgressIndicator(color: Colors.pinkAccent),
                  ),
                )
              : Column(
                  children: [
                    // Imagen principal
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(widget.imageFile.path),
                        width: double.infinity,
                        height: 350,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Campo de texto
                    TextField(
                      controller: _captionController,
                      maxLines: 5,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: "✨ Escribe o mejora tu descripción aquí...",
                        hintStyle:
                            TextStyle(color: Colors.white.withOpacity(0.6)),
                        filled: true,
                        fillColor: Colors.grey.shade900,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Botones
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateDescription,
                            icon: const Icon(Icons.auto_awesome, color: Colors.white),
                            label: const Text("Mejorar con IA"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _handleSubmit,
                            icon: const Icon(Icons.send, color: Colors.white),
                            label: const Text("Publicar"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              textStyle: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
