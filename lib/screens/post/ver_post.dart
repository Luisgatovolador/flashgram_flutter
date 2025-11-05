import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FeedPage extends StatefulWidget {
  const FeedPage({Key? key}) : super(key: key);

  @override
  _FeedPageState createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  List<dynamic> posts = [];
  Map<String, List<dynamic>> groupedPosts = {};
  Map<String, List<dynamic>> filteredGroupedPosts = {};
  bool isLoading = true;
  String search = "";
  String? errorMessage;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    fetchPosts();
  }

  Future<void> fetchPosts() async {
    try {
      final apiUrl = dotenv.env['API_URL'];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final res = await http.get(
        Uri.parse('$apiUrl/api/feed'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body) as List<dynamic>;
        final grouped = _groupByUser(data);

        setState(() {
          posts = data;
          groupedPosts = grouped;
          filteredGroupedPosts = grouped;
          isLoading = false;
          errorMessage = null;
        });
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Error al cargar el feed (${res.statusCode})';
        });
      }
    } catch (e) {
      debugPrint('❌ Error: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'No se pudo conectar con el servidor.';
      });
    }
  }

  Map<String, List<dynamic>> _groupByUser(List<dynamic> data) {
    final Map<String, List<dynamic>> grouped = {};
    for (var post in data) {
      final username = post['author']?['displayName'] ?? 'Anónimo';
      grouped.putIfAbsent(username, () => []);
      grouped[username]!.add(post);
    }
    return grouped;
  }

  void filterPosts(String query) {
    if (query.isEmpty) {
      setState(() {
        search = "";
        filteredGroupedPosts = groupedPosts;
      });
      return;
    }

    final filtered = <String, List<dynamic>>{};
    groupedPosts.forEach((username, userPosts) {
      if (username.toLowerCase().contains(query.toLowerCase())) {
        filtered[username] = userPosts;
      }
    });

    setState(() {
      search = query;
      filteredGroupedPosts = filtered;
    });
  }

  void onTabTapped(int index) async {
    setState(() => currentIndex = index);
    switch (index) {
      case 0:
        fetchPosts();
        break;
      case 1:
        Navigator.pushNamed(context, '/selectImage');
        break;
      case 2:
        await logout();
        break;
    }
  }

  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';
      final apiUrl = dotenv.env['API_URL'];

      final res = await http.post(
        Uri.parse('$apiUrl/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        await prefs.remove('token');
        Navigator.pushReplacementNamed(context, '/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al cerrar sesión')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo conectar con el servidor')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = Theme.of(context).colorScheme.background;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).colorScheme.onBackground;
    final captionColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text('Feed'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 🔍 Barra de búsqueda
                Container(
                  margin: const EdgeInsets.all(12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          style: TextStyle(color: textColor),
                          decoration: const InputDecoration(
                            hintText: 'Buscar por usuario...',
                            border: InputBorder.none,
                          ),
                          onChanged: (value) => filterPosts(value),
                        ),
                      ),
                      if (search.isNotEmpty)
                        GestureDetector(
                          onTap: () => filterPosts(''),
                          child: const Icon(Icons.clear),
                        ),
                    ],
                  ),
                ),

                // 📸 Feed agrupado por usuario con scroll horizontal
                Expanded(
                  child: filteredGroupedPosts.isEmpty
                      ? Center(
                          child: Text(
                            search.isEmpty
                                ? 'No hay publicaciones aún 😢'
                                : 'No se encontraron usuarios con "$search"',
                            style: TextStyle(
                              fontSize: 16,
                              color: captionColor,
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: fetchPosts,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: filteredGroupedPosts.entries.map((entry) {
                              final username = entry.key;
                              final userPosts = entry.value;
                              final apiUrl = dotenv.env['API_URL'];

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // 👤 Encabezado del usuario
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    child: Text(
                                      '@$username',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),

                                  // 🖼️ Scroll horizontal de publicaciones
                                  SizedBox(
                                    height: 280,
                                    child: ListView.builder(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: userPosts.length,
                                      itemBuilder: (context, index) {
                                        final post = userPosts[index];
                                        final caption =
                                            post['caption'] ?? 'Sin descripción';
                                        final imageUrl =
                                            '$apiUrl${post['image']}';

                                        return GestureDetector(
                                          onTap: () {
                                            // 👇 Al tocar, abrir detalle
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => PostDetailPage(
                                                  username: username,
                                                  imageUrl: imageUrl,
                                                  caption: caption,
                                                ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 220,
                                            margin: const EdgeInsets.symmetric(
                                                horizontal: 10),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.05),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 5),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                    top: Radius.circular(16),
                                                  ),
                                                  child: Image.network(
                                                    imageUrl,
                                                    width: double.infinity,
                                                    height: 180,
                                                    fit: BoxFit.cover,
                                                    loadingBuilder: (context,
                                                        child, loadingProgress) {
                                                      if (loadingProgress ==
                                                          null) return child;
                                                      return Container(
                                                        height: 180,
                                                        color:
                                                            Colors.grey.shade300,
                                                        child: const Center(
                                                          child:
                                                              CircularProgressIndicator(),
                                                        ),
                                                      );
                                                    },
                                                    errorBuilder:
                                                        (context, error, stack) =>
                                                            Container(
                                                      height: 180,
                                                      color:
                                                          Colors.grey.shade300,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_outlined,
                                                        size: 50,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(10),
                                                  child: Text(
                                                    caption,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: captionColor,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: onTabTapped,
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor:
            Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        showSelectedLabels: false,
        showUnselectedLabels: false,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 30), label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline, size: 40), label: 'Crear'),
          BottomNavigationBarItem(
              icon: Icon(Icons.logout_outlined, size: 30), label: 'Logout'),
        ],
      ),
    );
  }
}

/// 🌟 Nueva pantalla para mostrar el post en grande
class PostDetailPage extends StatelessWidget {
  final String username;
  final String imageUrl;
  final String caption;

  const PostDetailPage({
    Key? key,
    required this.username,
    required this.imageUrl,
    required this.caption,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        title: Text('@$username'),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.broken_image, size: 80),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              caption,
              style: TextStyle(fontSize: 16, color: textColor),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
