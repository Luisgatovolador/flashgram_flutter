import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController displayNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isLoading = false;

  Future<void> handleRegister() async {
    final displayName = displayNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (displayName.isEmpty || email.isEmpty || password.isEmpty) {
      _showAlert("Error", "Todos los campos son obligatorios");
      return;
    }

    try {
      setState(() => isLoading = true);

      final apiUrl = dotenv.env['API_URL'] ?? '';
      final response = await http.post(
        Uri.parse("$apiUrl/auth/register"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "displayName": displayName,
          "email": email,
          "password": password,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _showAlert("✅ Cuenta creada", "Ya puedes iniciar sesión");
        Navigator.pushReplacementNamed(context, '/');
      } else {
        _showAlert("Advertencia", data["message"] ?? "No se pudo registrar");
        Navigator.pushReplacementNamed(context, '/');
      }
    } catch (e) {
      _showAlert("Error", "No se pudo conectar con el servidor");
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = brightness == Brightness.dark;

    final colors = isDark
        ? {
            "background": const Color(0xFF121212),
            "text": Colors.white,
            "button": const Color(0xFF1e7e34),
            "link": const Color(0xFF1e90ff),
            "inputBackground": const Color(0xFF1e1e1e),
          }
        : {
            "background": const Color(0xFFF2F2F7),
            "text": Colors.black,
            "button": const Color(0xFF28A745),
            "link": const Color(0xFF007BFF),
            "inputBackground": Colors.white,
          };

    return Scaffold(
      backgroundColor: colors["background"],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 🔵 Logo circular
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  image: DecorationImage(
                    image: AssetImage("assets/logo2.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Text(
                "Crear Cuenta",
                style: TextStyle(
                  color: colors["text"],
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              // 📝 Inputs
              _buildInput("Nombre de usuario", displayNameController, colors),
              _buildInput("Correo electrónico", emailController, colors,
                  keyboardType: TextInputType.emailAddress),
              _buildInput("Contraseña", passwordController, colors,
                  obscureText: true),

              const SizedBox(height: 10),

              // 🔘 Botón registrar
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors["button"] as Color,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 3,
                ),
                onPressed: isLoading ? null : handleRegister,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Registrarse",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
              ),

              const SizedBox(height: 20),

              // 🔗 Link
              GestureDetector(
                onTap: () => Navigator.pushReplacementNamed(context, '/'),
                child: Text(
                  "¿Ya tienes cuenta? Inicia sesión",
                  style: TextStyle(
                    color: colors["link"],
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController controller, Map colors,
      {bool obscureText = false, TextInputType keyboardType = TextInputType.text}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: TextStyle(color: colors["text"]),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: (colors["text"] as Color).withOpacity(0.6)),
          filled: true,
          fillColor: colors["inputBackground"],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
        ),
      ),
    );
  }
}
