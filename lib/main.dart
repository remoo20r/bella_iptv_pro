import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

const String SERVER_URL = "http://arabesktv.com:2095";
const String APP_NAME = "Bella IPTV Pro";

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const BellaIPTVApp());
}

class BellaIPTVApp extends StatelessWidget {
  const BellaIPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        primaryColor: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Colors.deepPurpleAccent,
          secondary: Colors.amberAccent,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// --- شاشة تسجيل الدخول ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      setState(() {
        _errorMessage = "يرجى إدخال اسم المستخدم وكلمة السر";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final authUrl = Uri.parse("$SERVER_URL/player_api.php?username=$username&password=$password");

    try {
      final response = await http.get(
        authUrl,
        headers: {"User-Agent": "IPTVSmarters/1.0", "Accept": "*/*"},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('user_info')) {
          final authStatus = data['user_info']['status'];
          if (authStatus == 'Active' || authStatus == 'active' || authStatus == '1') {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => DashboardPage(
                  username: username,
                  password: password,
                ),
              ),
            );
            return;
          } else {
            setState(() {
              _errorMessage = "الحساب غير نشط أو الاشتراك منتهي";
            });
            return;
          }
        } else {
          setState(() {
            _errorMessage = "اسم المستخدم أو كلمة السر غير صحيحة";
          });
          return;
        }
      }
      setState(() {
        _errorMessage = "فشل الاتصال: السيرفر رد بكود (${response.statusCode})";
      });
    } catch (e) {
      setState(() {
        _errorMessage = "تعذر الاتصال بالسيرفر. تحقق من البيانات أو حالة الاشتراك";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.tv_rounded, size: 90, color: Colors.deepPurpleAccent),
              const SizedBox(height: 10),
              const Text(
                APP_NAME,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: 'اسم المستخدم (Username)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'كلمة السر (Password)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurpleAccent,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('تسجيل الدخول', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- الشاشة الرئيسية (3 أقسام: Live / Movies / Series) ---
class DashboardPage extends StatelessWidget {
  final String username;
  final String password;

  const DashboardPage({super.key, required this.username, required this.password});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(APP_NAME),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: GridView.count(
          crossAxisCount: MediaQuery.of(context).orientation == Orientation.landscape ? 3 : 1,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          children: [
            _buildCategoryCard(
              context,
              title: "LIVE TV\nبث مباشر",
              icon: Icons.live_tv_rounded,
              color: Colors.redAccent,
              action: "get_live_streams",
              type: "live",
            ),
            _buildCategoryCard(
              context,
              title: "MOVIES\nأفلام",
              icon: Icons.movie_rounded,
              color: Colors.blueAccent,
              action: "get_vod_streams",
              type: "movie",
            ),
            _buildCategoryCard(
              context,
              title: "SERIES\nمسلسلات",
              icon: Icons.tv_sharp,
              color: Colors.greenAccent,
              action: "get_series",
              type: "series",
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String action,
    required String type,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ContentListPage(
              username: username,
              password: password,
              action: action,
              title: title.replaceAll('\n', ' - '),
              type: type,
            ),
          ),
        );
      },
      child: Card(
        color: const Color(0xFF1E1E2C),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 70, color: color),
            const SizedBox(height: 15),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// --- شاشة عرض القنوات / الأفلام / المسلسلات ---
class ContentListPage extends StatefulWidget {
  final String username;
  final String password;
  final String action;
  final String title;
  final String type;

  const ContentListPage({
    super.key,
    required this.username,
    required this.password,
    required this.action,
    required String title,
    required this.type,
  }) : title = title;

  @override
  State<ContentListPage> createState() => _ContentListPageState();
}

class _ContentListPageState extends State<ContentListPage> {
  List<dynamic> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final url = Uri.parse(
        "$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=${widget.action}");
    try {
      final response = await http.get(url, headers: {"User-Agent": "IPTVSmarters/1.0"});
      if (response.statusCode == 200) {
        setState(() {
          _items = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text("لا توجد عناصر متاحة في هذا القسم"))
              : ListView.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final streamId = item['stream_id'] ?? item['series_id'];
                    final name = item['name'] ?? 'بدون عنوان';
                    final iconUrl = item['stream_icon'] ?? item['cover'] ?? '';

                    String streamUrl = "";
                    if (widget.type == "live") {
                      streamUrl = "$SERVER_URL/live/${widget.username}/${widget.password}/$streamId.ts";
                    } else if (widget.type == "movie") {
                      final ext = item['container_extension'] ?? 'mp4';
                      streamUrl = "$SERVER_URL/movie/${widget.username}/${widget.password}/$streamId.$ext";
                    }

                    return ListTile(
                      leading: iconUrl.isNotEmpty
                          ? Image.network(
                              iconUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(Icons.play_circle_outline, size: 40),
                            )
                          : const Icon(Icons.play_circle_outline, size: 40),
                      title: Text(name),
                      subtitle: widget.type == "movie" ? Text("فلم / VOD") : null,
                      onTap: () {
                        if (widget.type != "series" && streamUrl.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerScreen(
                                streamUrl: streamUrl,
                                title: name,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
    );
  }
}

// --- مشغل الفيديو المطور بدعم الـ Headers لفك الحظر ---
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const PlayerScreen({super.key, required this.streamUrl, required this.title});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.streamUrl),
      httpHeaders: {
        "User-Agent": "IPTVSmarters/1.0",
        "Accept": "*/*",
      },
    );

    try {
      await _controller.initialize();
      setState(() {
        _isInitialized = true;
      });
      _controller.play();
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      backgroundColor: Colors.black,
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 60, color: Colors.red),
                  const SizedBox(height: 10),
                  const Text("تعذر تشغيل هذا البث، قد يكون السيرفر أو القناة متوقفة حالياً"),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                      });
                      _initPlayer();
                    },
                    child: const Text("إعادة المحاولة"),
                  )
                ],
              )
            : _isInitialized
                ? AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_controller),
                        VideoProgressIndicator(_controller, allowScrubbing: true),
                      ],
                    ),
                  )
                : const CircularProgressIndicator(),
      ),
    );
  }
}
