import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class LoginScreen extends StatefulWidget {
  final Function(String)? onLoginSuccess; // callback opcional
  const LoginScreen({super.key, this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool loading = false;

  Future<void> handleLogin() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final apiUrl = dotenv.env['API_URL'];

    if (email.isEmpty || password.isEmpty) {
      _showAlert('Error', 'Todos los campos son obligatorios');
      return;
    }

    try {
      setState(() => loading = true);

      final response = await http.post(
        Uri.parse('$apiUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);

        widget.onLoginSuccess?.call(email);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/verpost', arguments: email);
        }
      } else {
        _showAlert('Error', data['message'] ?? 'Credenciales inválidas');
      }
    } catch (e) {
      _showAlert('Error', 'No se pudo conectar con el servidor');
    } finally {
      setState(() => loading = false);
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? {
            'background': const Color(0xFF121212),
            'text': Colors.white,
            'button': const Color(0xFF1E90FF),
            'input': const Color(0xFF1E1E1E),
          }
        : {
            'background': const Color(0xFFF2F2F7),
            'text': Colors.black,
            'button': const Color(0xFF007BFF),
            'input': Colors.white,
          };

    return Scaffold(
      backgroundColor: colors['background'],
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo circular
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo2.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: colors['text'],
                ),
              ),
              const SizedBox(height: 20),

              // Input correo
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Correo electrónico',
                  filled: true,
                  fillColor: colors['input'],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 15),

              // Input contraseña
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  hintText: 'Contraseña',
                  filled: true,
                  fillColor: colors['input'],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 20),

              // Botón entrar
              ElevatedButton(
                onPressed: loading ? null : handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors['button'],
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Entrar', style: TextStyle(fontSize: 18)),
              ),

              const SizedBox(height: 20),

              // Enlace registro
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  '¿No tienes cuenta? Regístrate',
                  style: TextStyle(
                    color: colors['button'],
                    fontSize: 16,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
