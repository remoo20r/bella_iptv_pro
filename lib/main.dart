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
const String APP_NAME = "IPTV PRO";

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
        scaffoldBackgroundColor: Colors.black,
        primaryColor: Colors.redAccent,
        colorScheme: const ColorScheme.dark(
          primary: Colors.redAccent,
          secondary: Colors.blueAccent,
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// --- 🎨 خلفية التطبيق المخصصة المطابقة للصور ---
Widget buildCustomBackground(Widget child) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.1, 0.4, 0.7, 1.0],
        colors: [
          Color(0xFF2B0054), // بنفسجي غامق
          Color(0xFF000000), // أسود
          Color(0xFF5E0000), // أحمر غامق
          Color(0xFF000000), // أسود
        ],
      ),
    ),
    child: Stack(
      children: [
        // تأثير خطوط الإضاءة المائلة
        Positioned.fill(
          child: CustomPaint(
            painter: DiagonalLinesPainter(),
          ),
        ),
        SafeArea(child: child),
      ],
    ),
  );
}

class DiagonalLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintRed = Paint()
      ..color = Colors.red.withOpacity(0.15)
      ..strokeWidth = 40
      ..style = PaintingStyle.stroke;

    final paintBlue = Paint()
      ..color = Colors.blueAccent.withOpacity(0.1)
      ..strokeWidth = 60
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(-100, 100), Offset(size.width + 100, size.height + 100), paintRed);
    canvas.drawLine(const Offset(-50, -50), Offset(size.width + 100, size.height - 100), paintBlue);
    canvas.drawLine(Offset(size.width * 0.5, -100), Offset(size.width + 100, size.height * 0.5), paintRed);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 1. شاشة تسجيل الدخول الجديدة (متطابقة مع صورة 26) ---
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
      setState(() => _errorMessage = "يرجى إدخال البيانات");
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
        headers: const {"User-Agent": "IPTVSmarters/1.0"},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('user_info')) {
          final userInfo = data['user_info'];
          if (userInfo['status'] == 'Active' || userInfo['status'] == 'active' || userInfo['status'] == '1') {
            if (!mounted) return;
            String expFormatted = 'Unlimited';
            if (userInfo['exp_date'] != null) {
              try {
                final dt = DateTime.fromMillisecondsSinceEpoch(int.parse(userInfo['exp_date'].toString()) * 1000);
                expFormatted = "${dt.day}/${dt.month}/${dt.year}";
              } catch (_) {}
            }
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => HomeScreen(username: username, password: password, expDateStr: expFormatted),
              ),
            );
            return;
          } else {
            setState(() => _errorMessage = "الحساب غير نشط");
            return;
          }
        }
      }
      setState(() => _errorMessage = "البيانات غير صحيحة");
    } catch (e) {
      setState(() => _errorMessage = "تعذر الاتصال بالسيرفر");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildCustomBackground(
        Center(
          child: SizedBox(
            width: 350,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // اللوجو
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 2),
                    color: Colors.black54,
                  ),
                  child: const Text(
                    "IPTV\nPRO",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 40),
                // حقل اليوزر
                Container(
                  color: Colors.white.withOpacity(0.8),
                  child: TextField(
                    controller: _usernameController,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Username',
                      hintStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // حقل الباسورد
                Container(
                  color: Colors.lightBlue.withOpacity(0.9),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.black),
                    decoration: const InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.black54),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.black54),
                      suffixIcon: Icon(Icons.remove_red_eye, color: Colors.black54),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // زر الدخول
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('SIGN IN', style: TextStyle(fontSize: 16, color: Colors.white, letterSpacing: 1.5)),
                  ),
                ),
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 15),
                  Text(_errorMessage, style: const TextStyle(color: Colors.yellowAccent, fontWeight: FontWeight.bold)),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 2. الشاشة الرئيسية الجديدة (متطابقة مع صورة 24) ---
class HomeScreen extends StatelessWidget {
  final String username;
  final String password;
  final String expDateStr;

  const HomeScreen({super.key, required this.username, required this.password, required this.expDateStr});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: buildCustomBackground(
        Column(
          children: [
            // الشريط العلوي (اللوجو والأيقونات)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.redAccent, width: 2), color: Colors.black),
                    child: const Text("IPTV\nPRO", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.search, size: 28),
                      const SizedBox(width: 15),
                      const Icon(Icons.sports_soccer, size: 28),
                      const SizedBox(width: 15),
                      const Icon(Icons.notifications_active, size: 28, color: Colors.amber),
                    ],
                  )
                ],
              ),
            ),
            const Spacer(),
            // الأقسام الرئيسية (دوائر كبيرة)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMainCircleIcon(context, title: "LIVE TV", icon: Icons.tv, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LiveChannelsScreen(username: username, password: password)));
                }),
                _buildMainCircleIcon(context, title: "TV GUIDE", icon: Icons.menu_book, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("جاري تجهيز قسم دليل القنوات")));
                }),
                _buildMainCircleIcon(context, title: "MOVIES", icon: Icons.movie_creation, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VODCategoryScreen(username: username, password: password, type: "movie", title: "MOVIES")));
                }),
                _buildMainCircleIcon(context, title: "TV SERIES", icon: Icons.video_library, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => VODCategoryScreen(username: username, password: password, type: "series", title: "TV SERIES")));
                }),
              ],
            ),
            const SizedBox(height: 30),
            // الأقسام الفرعية (أيقونات صغيرة تحت)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSubIcon(context, title: "FAVORITES", icon: Icons.favorite, color: Colors.red),
                _buildSubIcon(context, title: "MULTI", icon: Icons.grid_view, color: Colors.brown),
                _buildSubIcon(context, title: "CATCH UP", icon: Icons.replay, color: Colors.blue),
                _buildSubIcon(context, title: "RADIO", icon: Icons.radio, color: Colors.grey),
                _buildSubIcon(context, title: "ACCOUNT", icon: Icons.person, color: Colors.redAccent),
                _buildSubIcon(context, title: "SETTINGS", icon: Icons.settings, color: Colors.amber, onTap: () {
                  showDialog(context: context, builder: (c) => AlertDialog(
                    title: const Text("Settings"),
                    content: const Text("قائمة الإعدادات تعمل الآن! سيتم ربطها قريباً بالخيارات المتقدمة."),
                    actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("OK"))],
                  ));
                }),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text("Expire: $expDateStr", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMainCircleIcon(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1), border: Border.all(color: Colors.white38, width: 2)),
              child: Icon(icon, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5)),
              child: Text(title, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14)),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSubIcon(BuildContext context, {required String title, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap ?? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("تم الضغط على $title")));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          children: [
            Icon(icon, size: 35, color: color),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(3)),
              child: Text(title, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// --- 3. شاشة البث المباشر ---
class LiveChannelsScreen extends StatefulWidget {
  final String username;
  final String password;

  const LiveChannelsScreen({super.key, required this.username, required this.password});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _allChannels = [];
  List<dynamic> _filteredChannels = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'all';
  String _selectedChannelTitle = '';
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final catUrl = Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_categories");
    final chUrl = Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_streams");

    try {
      final catRes = await http.get(catUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});
      final chRes = await http.get(chUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});

      if (catRes.statusCode == 200 && chRes.statusCode == 200) {
        setState(() {
          _categories = json.decode(catRes.body) as List;
          _allChannels = json.decode(chRes.body) as List;
          _filteredChannels = _allChannels;
          _isLoading = false;
        });
        if (_filteredChannels.isNotEmpty) _playChannel(_filteredChannels[0]);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCategory(String catId) {
    setState(() {
      _selectedCategoryId = catId;
      _filteredChannels = catId == 'all' ? _allChannels : _allChannels.where((c) => c['category_id'].toString() == catId).toList();
    });
    if (_filteredChannels.isNotEmpty) _playChannel(_filteredChannels[0]);
  }

  void _playChannel(dynamic channel) async {
    final streamId = channel['stream_id'];
    final url = "$SERVER_URL/live/${widget.username}/${widget.password}/$streamId.ts";

    if (_videoController != null) await _videoController!.dispose();
    setState(() => _selectedChannelTitle = channel['name'] ?? '');

    _videoController = VideoPlayerController.networkUrl(Uri.parse(url), httpHeaders: const {"User-Agent": "IPTVSmarters/1.0"});
    await _videoController!.initialize();
    setState(() {});
    _videoController!.play();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_selectedChannelTitle.isEmpty ? "Live TV" : _selectedChannelTitle), backgroundColor: Colors.black),
      body: buildCustomBackground(
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Container(
                      color: Colors.black54,
                      child: ListView.builder(
                        itemCount: _categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              tileColor: _selectedCategoryId == 'all' ? Colors.redAccent.withOpacity(0.5) : null,
                              title: const Text("الكل", style: TextStyle(fontWeight: FontWeight.bold)),
                              onTap: () => _filterCategory('all'),
                            );
                          }
                          final cat = _categories[index - 1];
                          final catId = cat['category_id'].toString();
                          return ListTile(
                            tileColor: _selectedCategoryId == catId ? Colors.redAccent.withOpacity(0.5) : null,
                            title: Text(cat['category_name'] ?? '', style: const TextStyle(fontSize: 13)),
                            onTap: () => _filterCategory(catId),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 250,
                    child: Container(
                      color: Colors.black87,
                      child: ListView.builder(
                        itemCount: _filteredChannels.length,
                        itemBuilder: (context, index) {
                          final ch = _filteredChannels[index];
                          return ListTile(
                            tileColor: ch['name'] == _selectedChannelTitle ? Colors.redAccent.withOpacity(0.3) : null,
                            leading: const Icon(Icons.tv, color: Colors.white70, size: 20),
                            title: Text(ch['name'] ?? '', style: const TextStyle(fontSize: 12)),
                            onTap: () => _playChannel(ch),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: Colors.black,
                      child: _videoController != null && _videoController!.value.isInitialized
                          ? AspectRatio(aspectRatio: _videoController!.value.aspectRatio, child: VideoPlayer(_videoController!))
                          : const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// --- 4. شاشة عرض قوائم الأفلام والمسلسلات ---
class VODCategoryScreen extends StatefulWidget {
  final String username;
  final String password;
  final String type;
  final String title;

  const VODCategoryScreen({super.key, required this.username, required this.password, required this.type, required this.title});

  @override
  State<VODCategoryScreen> createState() => _VODCategoryScreenState();
}

class _VODCategoryScreenState extends State<VODCategoryScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _allItems = [];
  List<dynamic> _filteredItems = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'all';

  @override
  void initState() {
    super.initState();
    _loadVODData();
  }

  Future<void> _loadVODData() async {
    final catAction = widget.type == "movie" ? "get_vod_categories" : "get_series_categories";
    final itemAction = widget.type == "movie" ? "get_vod_streams" : "get_series";

    try {
      final catRes = await http.get(Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$catAction"));
      final itemRes = await http.get(Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$itemAction"));

      if (catRes.statusCode == 200 && itemRes.statusCode == 200) {
        setState(() {
          _categories = json.decode(catRes.body) as List;
          _allItems = json.decode(itemRes.body) as List;
          _filteredItems = _allItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCategory(String catId) {
    setState(() {
      _selectedCategoryId = catId;
      _filteredItems = catId == 'all' ? _allItems : _allItems.where((i) => i['category_id'].toString() == catId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.black),
      body: buildCustomBackground(
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Row(
                children: [
                  SizedBox(
                    width: 220,
                    child: Container(
                      color: Colors.black54,
                      child: ListView.builder(
                        itemCount: _categories.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return ListTile(
                              tileColor: _selectedCategoryId == 'all' ? Colors.redAccent.withOpacity(0.5) : null,
                              title: const Text("الكل", style: TextStyle(fontWeight: FontWeight.bold)),
                              onTap: () => _filterCategory('all'),
                            );
                          }
                          final cat = _categories[index - 1];
                          final catId = cat['category_id'].toString();
                          return ListTile(
                            tileColor: _selectedCategoryId == catId ? Colors.redAccent.withOpacity(0.5) : null,
                            title: Text(cat['category_name'] ?? '', style: const TextStyle(fontSize: 13)),
                            onTap: () => _filterCategory(catId),
                          );
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filteredItems.isEmpty
                        ? const Center(child: Text("لا يوجـد محتوى"))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              childAspectRatio: 0.7,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: _filteredItems.length,
                            itemBuilder: (context, index) {
                              final item = _filteredItems[index];
                              final cover = item['stream_icon'] ?? item['cover'] ?? '';
                              final name = item['name'] ?? '';

                              return GestureDetector(
                                onTap: () {
                                  // حل مشكلة عدم فتح الأفلام!
                                  if (widget.type == "movie") {
                                    final streamId = item['stream_id'];
                                    final ext = item['container_extension'] ?? 'mp4';
                                    final url = "$SERVER_URL/movie/${widget.username}/${widget.password}/$streamId.$ext";
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPlayer(url: url, title: name)));
                                  } else {
                                     // للمسلسلات
                                     ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("اخترت المسلسل: $name")));
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(8),
                                    image: cover.isNotEmpty ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover) : null,
                                  ),
                                  child: Container(
                                    alignment: Alignment.bottomCenter,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      gradient: const LinearGradient(colors: [Colors.black, Colors.transparent], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                                    ),
                                    child: Text(name, maxLines: 2, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }
}

// --- 5. شاشة مشغل الفيديو الجديد للأفلام ---
class FullScreenPlayer extends StatefulWidget {
  final String url;
  final String title;

  const FullScreenPlayer({super.key, required this.url, required this.title});

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {"User-Agent": "IPTVSmarters/1.0"},
    )..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.transparent, elevation: 0),
      body: Center(
        child: _isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller),
                    VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.redAccent)),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.redAccent),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.redAccent,
        onPressed: () {
          setState(() {
            _controller.value.isPlaying ? _controller.pause() : _controller.play();
          });
        },
        child: Icon(_controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}
