import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// 🧱 Importa tus pantallas existentes
import 'screens/auth/login.dart';
import 'screens/auth/register.dart';
import 'screens/post/ver_post.dart';
import 'screens/post/create_post.dart';

// 🖼️ Nuevas pantallas separadas para crear post
import 'screens/post/SelectImageScreen.dart';
import 'screens/post/addDescriptionScreen.dart';
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Route _slideRoute(Widget page) {
    // 🎞️ Animación tipo "deslizar hacia la izquierda"
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0); // desde la derecha
        const end = Offset.zero;
        const curve = Curves.ease;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        return SlideTransition(position: animation.drive(tween), child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FlashGram Flutter',
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: ThemeMode.system,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return _slideRoute(const LoginScreen());
          case '/register':
            return _slideRoute(const RegisterScreen());
          case '/verpost':
            return _slideRoute(const FeedPage());
          case '/createPost':
            return _slideRoute(const CreatePost());
          case '/selectImage':
            return _slideRoute(const SelectImageScreen());
            
          case '/addDescription':
            final imageFile = settings.arguments as XFile;
            return _slideRoute(AddDescriptionScreen(imageFile: imageFile));
          default:
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("Ruta no encontrada")),
              ),
            );
        }
      },
    );
  }
}
