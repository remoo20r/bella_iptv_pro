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
        scaffoldBackgroundColor: const Color(0xFF14141E),
        primaryColor: const Color(0xFF8B5CF6),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFFA78BFA),
          surface: Color(0xFF1E1E2D),
        ),
      ),
      home: const LoginPage(),
    );
  }
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
      setState(() => _errorMessage = "يرجى إدخال اسم المستخدم وكلمة السر");
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
          final userInfo = data['user_info'];
          final authStatus = userInfo['status'];
          if (authStatus == 'Active' || authStatus == 'active' || authStatus == '1') {
            if (!mounted) return;
            
            String expFormatted = 'Unlimited';
            if (userInfo['exp_date'] != null && userInfo['exp_date'].toString().isNotEmpty) {
              try {
                final dt = DateTime.fromMillisecondsSinceEpoch(int.parse(userInfo['exp_date'].toString()) * 1000);
                expFormatted = "${dt.day}/${dt.month}/${dt.year}";
              } catch (_) {}
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  username: username,
                  password: password,
                  expDateStr: expFormatted,
                ),
              ),
            );
            return;
          } else {
            setState(() => _errorMessage = "الحساب غير نشط أو الاشتراك منتهي");
            return;
          }
        }
      }
      setState(() => _errorMessage = "بيانات الدخول غير صحيحة");
    } catch (e) {
      setState(() => _errorMessage = "تعذر الاتصال بالسيرفر، تأكد من الشبكة");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E2D),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.tv, size: 60, color: Color(0xFF8B5CF6)),
              ),
              const SizedBox(height: 16),
              const Text(
                APP_NAME,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  filled: true,
                  fillColor: const Color(0xFF14141E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  filled: true,
                  fillColor: const Color(0xFF14141E),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF8B5CF6)),
                ),
              ),
              const SizedBox(height: 20),
              if (_errorMessage.isNotEmpty)
                Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('LOG IN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- 2. الشاشة الرئيسية (HOME SCREEN) ---
class HomeScreen extends StatelessWidget {
  final String username;
  final String password;
  final String expDateStr;

  const HomeScreen({
    super.key,
    required this.username,
    required this.password,
    required this.expDateStr,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final nowStr = "${now.day}/${now.month}/${now.year}";

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.tv, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      APP_NAME,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAlignment.end,
                  children: [
                    Text(nowStr, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text("Expiration: $expDateStr", style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildMainCategoryCard(
                            context,
                            title: "LIVE TV",
                            icon: Icons.sensors,
                            color: const Color(0xFF8B5CF6),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => LiveChannelsScreen(username: username, password: password),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMainCategoryCard(
                            context,
                            title: "Movies",
                            icon: Icons.movie_filter,
                            color: const Color(0xFF1E1E2D),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VODCategoryScreen(
                                  username: username,
                                  password: password,
                                  type: "movie",
                                  title: "MOVIES",
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMainCategoryCard(
                            context,
                            title: "Series",
                            icon: Icons.video_library,
                            color: const Color(0xFF1E1E2D),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VODCategoryScreen(
                                  username: username,
                                  password: password,
                                  type: "series",
                                  title: "SERIES",
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  SizedBox(
                    width: 160,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSideMenuItem(Icons.replay, "Catch up"),
                        const SizedBox(height: 12),
                        _buildSideMenuItem(Icons.grid_view, "Multi-Screen"),
                        const SizedBox(height: 12),
                        _buildSideMenuItem(Icons.settings, "Settings"),
                      ],
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

  Widget _buildMainCategoryCard(BuildContext context,
      {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.white),
            const SizedBox(height: 16),
            Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildSideMenuItem(IconData icon, String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 20),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ],
      ),
    );
  }
}

// --- 3. شاشة البث المباشر الموزعة بالـ Categories ---
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
    final catUrl = Uri.parse(
        "$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_categories");
    final chUrl = Uri.parse(
        "$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_streams");

    try {
      final catRes = await http.get(catUrl, headers: {"User-Agent": "IPTVSmarters/1.0"});
      final chRes = await http.get(chUrl, headers: {"User-Agent": "IPTVSmarters/1.0"});

      if (catRes.statusCode == 200 && chRes.statusCode == 200) {
        final cats = json.decode(catRes.body);
        final chs = json.decode(chRes.body);

        setState(() {
          _categories = cats is List ? cats : [];
          _allChannels = chs is List ? chs : [];
          _filteredChannels = _allChannels;
          _isLoading = false;
        });

        if (_filteredChannels.isNotEmpty) {
          _playChannel(_filteredChannels[0]);
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterCategory(String catId) {
    setState(() {
      _selectedCategoryId = catId;
      if (catId == 'all') {
        _filteredChannels = _allChannels;
      } else {
        _filteredChannels = _allChannels.where((c) => c['category_id'].toString() == catId).toList();
      }
    });
    if (_filteredChannels.isNotEmpty) {
      _playChannel(_filteredChannels[0]);
    }
  }

  void _playChannel(dynamic channel) async {
    final streamId = channel['stream_id'];
    final url = "$SERVER_URL/live/${widget.username}/${widget.password}/$streamId.ts";

    if (_videoController != null) {
      await _videoController!.dispose();
    }

    setState(() {
      _selectedChannelTitle = channel['name'] ?? '';
    });

    _videoController = VideoPlayerController.network(
      url,
      httpHeaders: {"User-Agent": "IPTVSmarters/1.0"},
    );

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
      appBar: AppBar(title: Text(_selectedChannelTitle.isEmpty ? "Live TV" : _selectedChannelTitle)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 220,
                  child: Container(
                    color: const Color(0xFF1E1E2D),
                    child: ListView.builder(
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSel = _selectedCategoryId == 'all';
                          return ListTile(
                            tileColor: isSel ? const Color(0xFF8B5CF6) : null,
                            title: const Text("كل المجموعات (ALL)", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            onTap: () => _filterCategory('all'),
                          );
                        }
                        final cat = _categories[index - 1];
                        final catId = cat['category_id'].toString();
                        final isSel = _selectedCategoryId == catId;
                        return ListTile(
                          tileColor: isSel ? const Color(0xFF8B5CF6) : null,
                          title: Text(cat['category_name'] ?? '', style: const TextStyle(fontSize: 13)),
                          onTap: () => _filterCategory(catId),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: ListView.builder(
                    itemCount: _filteredChannels.length,
                    itemBuilder: (context, index) {
                      final ch = _filteredChannels[index];
                      final isSelected = ch['name'] == _selectedChannelTitle;
                      return ListTile(
                        tileColor: isSelected ? const Color(0xFF8B5CF6).withOpacity(0.3) : null,
                        leading: const Icon(Icons.live_tv, color: Colors.white70, size: 20),
                        title: Text(ch['name'] ?? '', style: const TextStyle(fontSize: 12)),
                        onTap: () => _playChannel(ch),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Colors.black,
                    child: _videoController != null && _videoController!.value.isInitialized
                        ? AspectRatio(
                            aspectRatio: _videoController!.value.aspectRatio,
                            child: VideoPlayer(_videoController!),
                          )
                        : const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Color(0xFF8B5CF6)),
                                SizedBox(height: 12),
                                Text("جاري تحميل البث...", style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

// --- 4. شاشة الأفلام والمسلسلات مع المجموعات ---
class VODCategoryScreen extends StatefulWidget {
  final String username;
  final String password;
  final String type;
  final String title;

  const VODCategoryScreen({
    super.key,
    required this.username,
    required this.password,
    required this.type,
    required this.title,
  });

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

    final catUrl = Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$catAction");
    final itemUrl = Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$itemAction");

    try {
      final catRes = await http.get(catUrl, headers: {"User-Agent": "IPTVSmarters/1.0"});
      final itemRes = await http.get(itemUrl, headers: {"User-Agent": "IPTVSmarters/1.0"});

      if (catRes.statusCode == 200 && itemRes.statusCode == 200) {
        final cats = json.decode(catRes.body);
        final items = json.decode(itemRes.body);

        setState(() {
          _categories = cats is List ? cats : [];
          _allItems = items is List ? items : [];
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
      if (catId == 'all') {
        _filteredItems = _allItems;
      } else {
        _filteredItems = _allItems.where((i) => i['category_id'].toString() == catId).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              children: [
                SizedBox(
                  width: 240,
                  child: Container(
                    color: const Color(0xFF1E1E2D),
                    child: ListView.builder(
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSel = _selectedCategoryId == 'all';
                          return ListTile(
                            tileColor: isSel ? const Color(0xFF8B5CF6) : null,
                            title: const Text("الكل (ALL)", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            onTap: () => _filterCategory('all'),
                          );
                        }
                        final cat = _categories[index - 1];
                        final catId = cat['category_id'].toString();
                        final isSel = _selectedCategoryId == catId;
                        return ListTile(
                          tileColor: isSel ? const Color(0xFF8B5CF6) : null,
                          title: Text(cat['category_name'] ?? '', style: const TextStyle(fontSize: 13)),
                          onTap: () => _filterCategory(catId),
                        );
                      },
                    ),
                  ),
                ),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(child: Text("لا يوجـد محتوى داخل هذه المجموعة"))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final cover = item['stream_icon'] ?? item['cover'] ?? '';
                            final name = item['name'] ?? '';

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E2D),
                                borderRadius: BorderRadius.circular(12),
                                image: cover.isNotEmpty
                                    ? DecorationImage(image: NetworkImage(cover), fit: BoxFit.cover)
                                    : null,
                              ),
                              child: Container(
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withOpacity(0.85), Colors.transparent],
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                  ),
                                ),
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
