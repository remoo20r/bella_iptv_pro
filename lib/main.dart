٩٢٢٣٣٧٢٠٣٦٨٥٤٧٧٥٨٠٧import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

// --- القائمة العامة لحفظ المفضلة في الذاكرة ---
final List<Map<String, dynamic>> globalFavorites = [];

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

// --- 🎨 خلفية التطبيق المخصصة ---
Widget buildCustomBackground(Widget child) {
  return Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: [0.1, 0.4, 0.7, 1.0],
        colors: [
          Color(0xFF2B0054),
          Color(0xFF000000),
          Color(0xFF5E0000),
          Color(0xFF000000),
        ],
      ),
    ),
    child: Stack(
      children: [
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

// --- 1. شاشة تسجيل الدخول ---
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

// --- 2. الشاشة الرئيسية ---
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
                    children: const [
                      Icon(Icons.search, size: 28),
                      SizedBox(width: 15),
                      Icon(Icons.sports_soccer, size: 28),
                      SizedBox(width: 15),
                      Icon(Icons.notifications_active, size: 28, color: Colors.amber),
                    ],
                  )
                ],
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMainCircleIcon(context, title: "LIVE TV", icon: Icons.tv, onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LiveChannelsScreen(username: username, password: password)));
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSubIcon(context, title: "FAVORITES", icon: Icons.favorite, color: Colors.red, onTap: () {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => FavoritesScreen(username: username, password: password)));
                }),
                _buildSubIcon(context, title: "ACCOUNT", icon: Icons.person, color: Colors.redAccent, onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Expiration: $expDateStr")));
                }),
                _buildSubIcon(context, title: "SETTINGS", icon: Icons.settings, color: Colors.amber, onTap: () {
                  showDialog(context: context, builder: (c) => AlertDialog(
                    backgroundColor: Colors.black87,
                    title: const Text("الإعدادات (Settings)", style: TextStyle(color: Colors.white)),
                    content: const Text("اختر الإجراء المطلوب", style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(c);
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                        },
                        child: const Text("تسجيل الخروج (Logout)", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(onPressed: () => Navigator.pop(c), child: const Text("إغلاق")),
                    ],
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
      onTap: onTap,
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

Widget buildPyramidBadge(bool isFav) {
  if (!isFav) return const SizedBox.shrink();
  return Positioned(
    top: 5, right: 5,
    child: Image.network('https://img.icons8.com/color/48/pyramids.png', width: 28, height: 28),
  );
}

bool checkIsFavorite(dynamic item) {
  final id = item['stream_id']?.toString() ?? item['series_id']?.toString();
  return globalFavorites.any((fav) => (fav['stream_id']?.toString() ?? fav['series_id']?.toString()) == id);
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

  void _toggleFav(dynamic ch) {
    setState(() {
      if (checkIsFavorite(ch)) {
        globalFavorites.removeWhere((fav) => fav['stream_id'].toString() == ch['stream_id'].toString());
      } else {
        var copy = Map<String, dynamic>.from(ch);
        copy['fav_type'] = 'live';
        globalFavorites.add(copy);
      }
    });
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
                          return Stack(
                            children: [
                              ListTile(
                                tileColor: ch['name'] == _selectedChannelTitle ? Colors.redAccent.withOpacity(0.3) : null,
                                leading: const Icon(Icons.tv, color: Colors.white70, size: 20),
                                title: Text(ch['name'] ?? '', style: const TextStyle(fontSize: 12)),
                                onTap: () {
                                  // الضغطة الأولى تشغل، الضغطة الثانية تكبر الشاشة
                                  if (ch['name'] == _selectedChannelTitle) {
                                    if (_videoController != null && _videoController!.value.isInitialized) {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => LiveFullScreenPlayer(controller: _videoController!, title: _selectedChannelTitle)));
                                    }
                                  } else {
                                    _playChannel(ch);
                                  }
                                },
                                onLongPress: () => _toggleFav(ch),
                              ),
                              buildPyramidBadge(checkIsFavorite(ch)),
                            ],
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

// --- شاشة مشغل البث المباشر الكاملة ---
class LiveFullScreenPlayer extends StatelessWidget {
  final VideoPlayerController controller;
  final String title;
  const LiveFullScreenPlayer({super.key, required this.controller, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller)),
          ),
          Positioned(
            top: 40, left: 20,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 35),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
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

  void _toggleFav(dynamic item) {
    setState(() {
      if (checkIsFavorite(item)) {
        final id = item['stream_id']?.toString() ?? item['series_id']?.toString();
        globalFavorites.removeWhere((fav) => (fav['stream_id']?.toString() ?? fav['series_id']?.toString()) == id);
      } else {
        var copy = Map<String, dynamic>.from(item);
        copy['fav_type'] = widget.type;
        globalFavorites.add(copy);
      }
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
                                onLongPress: () => _toggleFav(item),
                                onTap: () {
                                  if (widget.type == "movie") {
                                    final streamId = item['stream_id'];
                                    final ext = item['container_extension'] ?? 'mp4';
                                    final url = "$SERVER_URL/movie/${widget.username}/${widget.password}/$streamId.$ext";
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPlayer(url: url, title: name)));
                                  } else {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(
                                      username: widget.username, password: widget.password, seriesId: item['series_id'].toString(), seriesName: name, cover: cover
                                    )));
                                  }
                                },
                                child: Stack(
                                  children: [
                                    Container(
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
                                    buildPyramidBadge(checkIsFavorite(item)),
                                  ],
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

// --- شاشة تفاصيل المسلسل لاختيار الحلقات ---
class SeriesEpisodesScreen extends StatefulWidget {
  final String username, password, seriesId, seriesName, cover;
  const SeriesEpisodesScreen({super.key, required this.username, required this.password, required this.seriesId, required this.seriesName, required this.cover});

  @override
  State<SeriesEpisodesScreen> createState() => _SeriesEpisodesScreenState();
}

class _SeriesEpisodesScreenState extends State<SeriesEpisodesScreen> {
  List<dynamic> _allEpisodes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchEpisodes();
  }

  Future<void> _fetchEpisodes() async {
    final url = Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series_info&series_id=${widget.seriesId}");
    try {
      final res = await http.get(url, headers: const {"User-Agent": "IPTVSmarters/1.0"});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        final episodesMap = data['episodes'];
        if (episodesMap is Map) {
          episodesMap.forEach((season, episodesList) {
            if (episodesList is List) {
              _allEpisodes.addAll(episodesList);
            }
          });
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.seriesName), backgroundColor: Colors.black),
      body: buildCustomBackground(
        _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allEpisodes.isEmpty
            ? const Center(child: Text("لا توجد حلقات متاحة"))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allEpisodes.length,
                itemBuilder: (context, index) {
                  final ep = _allEpisodes[index];
                  final title = ep['title'] ?? "Episode ${index + 1}";
                  return Card(
                    color: Colors.black54,
                    child: ListTile(
                      leading: const Icon(Icons.play_circle_fill, color: Colors.redAccent, size: 40),
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      onTap: () {
                        final ext = ep['container_extension'] ?? 'mp4';
                        final url = "$SERVER_URL/series/${widget.username}/${widget.password}/${ep['id']}.$ext";
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPlayer(url: url, title: title)));
                      },
                    ),
                  );
                },
              )
      ),
    );
  }
}

// --- 5. شاشة مشغل الفيديو الجديد ---
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
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.url),
      httpHeaders: const {"User-Agent": "IPTVSmarters/1.0"},
    )..initialize().then((_) {
        setState(() => _isInitialized = true);
        _controller.play();
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => _showControls = false);
        });
      });
  }

  void _seek(int seconds) {
    final newPos = _controller.value.position + Duration(seconds: seconds);
    _controller.seekTo(newPos);
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
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isInitialized)
              AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller))
            else
              const CircularProgressIndicator(color: Colors.redAccent),
            
            if (_showControls && _isInitialized) ...[
              Container(color: Colors.black54),
              Positioned(
                top: 40, left: 20,
                child: Row(
                  children: [
                    IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)),
                    Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10, color: Colors.white), iconSize: 60,
                    onPressed: () => _seek(-10),
                  ),
                  IconButton(
                    icon: Icon(_controller.value.isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.redAccent), iconSize: 80,
                    onPressed: () {
                      setState(() {
                        _controller.value.isPlaying ? _controller.pause() : _controller.play();
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10, color: Colors.white), iconSize: 60,
                    onPressed: () => _seek(10),
                  ),
                ],
              ),
              Positioned(
                bottom: 30, left: 40, right: 40,
                child: VideoProgressIndicator(_controller, allowScrubbing: true, colors: const VideoProgressColors(playedColor: Colors.redAccent)),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// --- شاشة المفضلة (FAVORITES) ---
class FavoritesScreen extends StatefulWidget {
  final String username;
  final String password;
  const FavoritesScreen({super.key, required this.username, required this.password});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("المفضلة (Favorites)"), backgroundColor: Colors.black),
      body: buildCustomBackground(
        globalFavorites.isEmpty
          ? const Center(child: Text("لا توجد عناصر في المفضلة", style: TextStyle(fontSize: 18, color: Colors.white)))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, childAspectRatio: 0.7, crossAxisSpacing: 10, mainAxisSpacing: 10),
              itemCount: globalFavorites.length,
              itemBuilder: (context, index) {
                final item = globalFavorites[index];
                final type = item['fav_type'];
                final cover = item['stream_icon'] ?? item['cover'] ?? '';
                final name = item['name'] ?? '';

                return GestureDetector(
                  onLongPress: () {
                    setState(() { globalFavorites.removeAt(index); });
                  },
                  onTap: () {
                    if (type == 'movie') {
                      final url = "$SERVER_URL/movie/${widget.username}/${widget.password}/${item['stream_id']}.${item['container_extension'] ?? 'mp4'}";
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPlayer(url: url, title: name)));
                    } else if (type == 'series') {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesEpisodesScreen(
                        username: widget.username, password: widget.password, seriesId: item['series_id'].toString(), seriesName: name, cover: cover
                      )));
                    } else if (type == 'live') {
                      final url = "$SERVER_URL/live/${widget.username}/${widget.password}/${item['stream_id']}.ts";
                      Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenPlayer(url: url, title: name)));
                    }
                  },
                  child: Stack(
                    children: [
                      Container(
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
                      buildPyramidBadge(true),
                    ],
                  ),
                );
              },
            )
      ),
    );
  }
}
