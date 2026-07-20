import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:better_player/better_player.dart';

// تجاوز قيود الأمان لروابط HTTP وجميع الشهادات
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

    // طريقة طلب API المعتمدة لـ Xtream Codes
    final authUrl = Uri.parse("$SERVER_URL/player_api.php?username=$username&password=$password");

    try {
      final response = await http.get(
        authUrl,
        headers: {
          "User-Agent": "IPTVSmarters/1.0",
          "Accept": "*/*",
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // التحقق من صحة الاشتراك
        if (data is Map && data.containsKey('user_info')) {
          final authStatus = data['user_info']['status'];
          if (authStatus == 'Active' || authStatus == 'active' || authStatus == '1') {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ChannelListPage(
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
        } else if (data is Map && data.containsKey('user_info') == false) {
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
      // تجربة طريقة ثانية مبسطة في حالة وجود مشكلة في فك الـ JSON
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

// --- شاشة عرض القنوات ---
class ChannelListPage extends StatefulWidget {
  final String username;
  final String password;

  const ChannelListPage({super.key, required this.username, required this.password});

  @override
  State<ChannelListPage> createState() => _ChannelListPageState();
}

class _ChannelListPageState extends State<ChannelListPage> {
  List<dynamic> _channels = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchChannels();
  }

  Future<void> _fetchChannels() async {
    final url = Uri.parse(
        "$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_live_streams");
    try {
      final response = await http.get(url, headers: {"User-Agent": "IPTVSmarters/1.0"});
      if (response.statusCode == 200) {
        setState(() {
          _channels = json.decode(response.body);
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _channels.isEmpty
              ? const Center(child: Text("لا توجد قنوات متاحة"))
              : ListView.builder(
                  itemCount: _channels.length,
                  itemBuilder: (context, index) {
                    final channel = _channels[index];
                    final streamId = channel['stream_id'];
                    final streamUrl =
                        "$SERVER_URL/live/${widget.username}/${widget.password}/$streamId.m3u8";

                    return ListTile(
                      leading: channel['stream_icon'] != null &&
                              channel['stream_icon'].toString().isNotEmpty
                          ? Image.network(
                              channel['stream_icon'],
                              width: 40,
                              height: 40,
                              errorBuilder: (c, e, s) => const Icon(Icons.live_tv),
                            )
                          : const Icon(Icons.live_tv),
                      title: Text(channel['name'] ?? 'قناة بدون اسم'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VideoPlayerPage(
                              streamUrl: streamUrl,
                              channelName: channel['name'] ?? 'بث مباشر',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
}

// --- مشغل الفيديو ---
class VideoPlayerPage extends StatefulWidget {
  final String streamUrl;
  final String channelName;

  const VideoPlayerPage({super.key, required this.streamUrl, required this.channelName});

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late BetterPlayerController _controller;

  @override
  void initState() {
    super.initState();
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.streamUrl,
      liveStream: true,
    );
    _controller = BetterPlayerController(
      const BetterPlayerConfiguration(
        autoPlay: true,
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
      ),
      betterPlayerDataSource: dataSource,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.channelName)),
      body: Center(
        child: BetterPlayer(controller: _controller),
      ),
    );
  }
}
