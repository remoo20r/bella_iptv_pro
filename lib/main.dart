import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

const String SERVER_URL = "http://arabesktv.com:2095";
const String APP_NAME = "Bella IPTV Pro";
const String CONTACT_PHONE_DISPLAY = "+1 (682) 597-5255";
const String CONTACT_PHONE_DIAL = "+16825975255";
const String CONTACT_WHATSAPP_NUMBER = "16825975255";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  await FavoritesStore.preload();
  runApp(const BellaIPTVApp());
}

// --- الألوان الأساسية للتطبيق ---
class AppColors {
  static const Color black = Color(0xFF0A0A0A);
  static const Color panel = Color(0xFF160B0B);
  static const Color red = Color(0xFFB31F1F);
  static const Color redDark = Color(0xFF6B1010);
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldBright = Color(0xFFF5C542);
}

// --- تخزين المفضلة (يبقى محفوظ بعد إغلاق التطبيق) ---
class FavoritesStore {
  static const _key = 'bella_favorite_ids';
  static final Set<String> _cache = {};
  static bool _loaded = false;

  static Future<void> preload() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _cache.addAll(prefs.getStringList(_key) ?? []);
    _loaded = true;
  }

  static bool isFavorite(String id) => _cache.contains(id);

  static Future<void> toggle(String id) async {
    if (!_loaded) await preload();
    if (_cache.contains(id)) {
      _cache.remove(id);
    } else {
      _cache.add(id);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _cache.toList());
  }
}

// --- روابط الاتصال وواتساب ---
Future<void> launchPhoneCall() async {
  final uri = Uri.parse("tel:$CONTACT_PHONE_DIAL");
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

Future<void> launchWhatsApp() async {
  final uri = Uri.parse("https://wa.me/$CONTACT_WHATSAPP_NUMBER");
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

PreferredSizeWidget buildAppBar(String title) {
  return AppBar(
    backgroundColor: AppColors.black,
    elevation: 0,
    title: Text(title, style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 18)),
    iconTheme: const IconThemeData(color: AppColors.gold),
  );
}

// --- مؤقت الاختفاء التلقائي للتحكم (٣ ثوان) يُستخدم في شاشات التشغيل ---
mixin AutoHideControls<T extends StatefulWidget> on State<T> {
  bool controlsVisible = true;
  Timer? _hideTimer;

  void showControlsTemporarily() {
    if (mounted) setState(() => controlsVisible = true);
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => controlsVisible = false);
    });
  }

  void startAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => controlsVisible = false);
    });
  }

  void toggleControls() {
    if (controlsVisible) {
      _hideTimer?.cancel();
      setState(() => controlsVisible = false);
    } else {
      showControlsTemporarily();
    }
  }

  void disposeAutoHide() {
    _hideTimer?.cancel();
  }
}

// --- خلفية متدرجة أسود/أحمر تستخدمها كل الشاشات ---
class GradientScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;

  const GradientScaffold({super.key, this.appBar, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0A0A0A), Color(0xFF260909), Color(0xFF5C1414)],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(child: body),
      ),
    );
  }
}

// --- عنصر قابل للتفعيل باللمس أو بريموت التي في، بتأثير ثلاثي الأبعاد ذهبي عند التركيز ---
class RemoteFocusable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final BorderRadius? borderRadius;
  final bool autofocus;

  const RemoteFocusable({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.autofocus = false,
  });

  @override
  State<RemoteFocusable> createState() => _RemoteFocusableState();
}

class _RemoteFocusableState extends State<RemoteFocusable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(14);
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (show) {
        if (mounted) setState(() => _focused = show);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: _focused ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          builder: (context, t, child) {
            return Transform.scale(
              scale: 1.0 + (0.09 * t),
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0016)
                  ..rotateX(-0.07 * t),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: t == 0
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.gold.withOpacity(0.6 * t),
                              blurRadius: 24 * t,
                              spreadRadius: 2 * t,
                            ),
                          ],
                    border: t == 0 ? null : Border.all(color: AppColors.gold, width: 2.5 * t),
                  ),
                  child: widget.child,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- صف قائمة قابل للتركيز (تصنيفات، قنوات، مواسم...) ---
class FocusableRow extends StatefulWidget {
  final Widget? leading;
  final Widget title;
  final Widget? trailing;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool autofocus;

  const FocusableRow({
    super.key,
    this.leading,
    required this.title,
    this.trailing,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.autofocus = false,
  });

  @override
  State<FocusableRow> createState() => _FocusableRowState();
}

class _FocusableRowState extends State<FocusableRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = _focused || widget.selected;
    return FocusableActionDetector(
      autofocus: widget.autofocus,
      onShowFocusHighlight: (show) {
        if (mounted) setState(() => _focused = show);
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) {
          widget.onTap();
          return null;
        }),
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: EdgeInsets.symmetric(horizontal: _focused ? 2 : 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: highlighted ? AppColors.red : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _focused ? Border.all(color: AppColors.gold, width: 2) : null,
            boxShadow: _focused
                ? [BoxShadow(color: AppColors.gold.withOpacity(0.45), blurRadius: 14, spreadRadius: 1)]
                : null,
          ),
          child: Row(
            children: [
              if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 12)],
              Expanded(child: widget.title),
              if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

// --- شارة الأهرامات الذهبية (علامة المفضلة) ---
class PyramidBadge extends StatelessWidget {
  final double size;
  const PyramidBadge({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        shape: BoxShape.circle,
      ),
      child: CustomPaint(painter: _PyramidPainter()),
    );
  }
}

class _PyramidPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final ridgePaint = Paint()
      ..color = const Color(0xFF8A6A10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width * 0.4, size.height), ridgePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BellaIPTVApp extends StatelessWidget {
  const BellaIPTVApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: APP_NAME,
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: AppColors.black,
        primaryColor: AppColors.red,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.red,
          secondary: AppColors.gold,
          surface: Color(0xFF1A1010),
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
        headers: const {"User-Agent": "IPTVSmarters/1.0", "Accept": "*/*"},
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
    return GradientScaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.panel.withOpacity(0.85),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.gold.withOpacity(0.5), width: 1.2),
              boxShadow: const [BoxShadow(color: Colors.black87, blurRadius: 24)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.gold, AppColors.red]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: AppColors.gold.withOpacity(0.4), blurRadius: 20)],
                  ),
                  child: const Icon(Icons.tv, size: 56, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  APP_NAME,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.gold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: _usernameController,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Username',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
                    ),
                    prefixIcon: const Icon(Icons.person, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.white54),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.gold.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
                    ),
                    prefixIcon: const Icon(Icons.lock, color: AppColors.gold),
                  ),
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.gold, width: 1.5),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                          )
                        : const Text(
                            'LOG IN',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                Container(height: 1, color: AppColors.gold.withOpacity(0.25)),
                const SizedBox(height: 20),
                const Text(
                  "للاشتراك تواصل مع:",
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 10),
                RemoteFocusable(
                  onTap: launchPhoneCall,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.gold.withOpacity(0.6)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.phone, color: AppColors.gold, size: 18),
                        SizedBox(width: 10),
                        Text(
                          CONTACT_PHONE_DISPLAY,
                          style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
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

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 44),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.gold, AppColors.red]),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.tv, size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    const Text(APP_NAME,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gold)),
                    Text(nowStr, style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
                RemoteFocusable(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(username: username, password: password, expDateStr: expDateStr),
                    ),
                  ),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                    ),
                    child: const Icon(Icons.settings, color: AppColors.gold, size: 22),
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildRibbonButton(
                  title: "LIVE TV",
                  icon: Icons.sensors,
                  autofocus: true,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LiveChannelsScreen(username: username, password: password),
                    ),
                  ),
                ),
                _buildRibbonButton(
                  title: "MOVIES",
                  icon: Icons.movie_filter,
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
                _buildRibbonButton(
                  title: "SERIES",
                  icon: Icons.video_library,
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
              ],
            ),
            const Spacer(),
            RemoteFocusable(
              onTap: launchPhoneCall,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.panel.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                      child: const Icon(Icons.support_agent, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("خدمة العملاء", style: TextStyle(color: Colors.white70, fontSize: 12)),
                          SizedBox(height: 2),
                          Text(
                            CONTACT_PHONE_DISPLAY,
                            style: TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.call, color: AppColors.gold, size: 22),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text("Expire: $expDateStr", style: const TextStyle(color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool autofocus = false,
  }) {
    return RemoteFocusable(
      onTap: onTap,
      autofocus: autofocus,
      borderRadius: BorderRadius.circular(60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [AppColors.gold, Color(0xFF8A6A10)]),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.red, Color(0xFF5C0D0D)],
                ),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.red.withOpacity(0.5), blurRadius: 16, spreadRadius: 1)],
              ),
              child: Icon(icon, color: AppColors.gold, size: 40),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.panel,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.gold, width: 1.4),
              ),
              child: Text(
                title,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. شاشة البث المباشر: تصنيفات + قنوات + معاينة، وتكبير كامل للشاشة ---
class LiveChannelsScreen extends StatefulWidget {
  final String username;
  final String password;

  const LiveChannelsScreen({super.key, required this.username, required this.password});

  @override
  State<LiveChannelsScreen> createState() => _LiveChannelsScreenState();
}

class _LiveChannelsScreenState extends State<LiveChannelsScreen> with AutoHideControls<LiveChannelsScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _allChannels = [];
  List<dynamic> _filteredChannels = [];
  bool _isLoading = true;
  String _selectedCategoryId = 'all';
  String _selectedChannelTitle = '';
  String _selectedStreamId = '';
  VideoPlayerController? _videoController;
  bool _isFullscreen = false;

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
      final catRes = await http.get(catUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});
      final chRes = await http.get(chUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});

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
      } else if (catId == 'favorites') {
        _filteredChannels =
            _allChannels.where((c) => FavoritesStore.isFavorite('live_${c['stream_id']}')).toList();
      } else {
        _filteredChannels = _allChannels.where((c) => c['category_id'].toString() == catId).toList();
      }
    });
    if (_filteredChannels.isNotEmpty) {
      _playChannel(_filteredChannels[0]);
    }
  }

  void _playChannel(dynamic channel) async {
    final streamId = channel['stream_id'].toString();

    // نفس القناة الشغالة بالفعل: كبّر الشاشة بدل ما تعيد التشغيل
    if (streamId == _selectedStreamId && _videoController != null) {
      setState(() => _isFullscreen = true);
      showControlsTemporarily();
      return;
    }

    final url = "$SERVER_URL/live/${widget.username}/${widget.password}/$streamId.ts";

    if (_videoController != null) {
      await _videoController!.dispose();
      setState(() => _videoController = null);
    }

    setState(() {
      _selectedChannelTitle = channel['name'] ?? '';
      _selectedStreamId = streamId;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: const {"User-Agent": "IPTVSmarters/1.0"},
    );

    await controller.initialize();
    if (!mounted) return;
    setState(() => _videoController = controller);
    controller.play();
  }

  Future<void> _toggleFavorite(dynamic channel) async {
    await FavoritesStore.toggle('live_${channel['stream_id']}');
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    disposeAutoHide();
    _videoController?.dispose();
    super.dispose();
  }

  Widget _buildVideoArea() {
    final controller = _videoController;
    return Container(
      color: Colors.black,
      child: (controller == null || !controller.value.isInitialized)
          ? null
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxW = constraints.maxWidth;
                final maxH = constraints.maxHeight;
                final aspect = controller.value.aspectRatio <= 0 ? (16 / 9) : controller.value.aspectRatio;

                double w = maxW;
                double h = w / aspect;
                if (h > maxH) {
                  h = maxH;
                  w = h * aspect;
                }

                return Center(
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: VideoPlayer(controller),
                  ),
                );
              },
            ),
    );
  }

  Widget _fullscreenOverlay() {
    return AnimatedOpacity(
      opacity: controlsVisible ? 1 : 0,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !controlsVisible,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withOpacity(0.8), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.fullscreen_exit, color: AppColors.gold, size: 26),
                  onPressed: () => setState(() => _isFullscreen = false),
                ),
                Expanded(
                  child: Text(
                    _selectedChannelTitle,
                    style: const TextStyle(fontSize: 17, color: AppColors.gold, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullscreen) {
      return PopScope(
        canPop: false,
        onPopInvoked: (didPop) {
          if (didPop) return;
          setState(() => _isFullscreen = false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: GestureDetector(
            onTap: toggleControls,
            child: Stack(
              children: [
                Positioned.fill(child: _buildVideoArea()),
                _fullscreenOverlay(),
              ],
            ),
          ),
        ),
      );
    }

    return GradientScaffold(
      appBar: buildAppBar(_selectedChannelTitle.isEmpty ? "Live TV" : _selectedChannelTitle),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Row(
              children: [
                SizedBox(
                  width: 230,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4),
                    children: [
                      FocusableRow(
                        title: const Text("كل المجموعات (ALL)",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        selected: _selectedCategoryId == 'all',
                        onTap: () => _filterCategory('all'),
                      ),
                      FocusableRow(
                        leading: const Icon(Icons.star, color: AppColors.gold, size: 20),
                        title: const Text("المفضلة",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        selected: _selectedCategoryId == 'favorites',
                        onTap: () => _filterCategory('favorites'),
                      ),
                      ..._categories.map((cat) {
                        final catId = cat['category_id'].toString();
                        return FocusableRow(
                          title: Text(cat['category_name'] ?? '',
                              style: const TextStyle(fontSize: 14, color: Colors.white)),
                          selected: _selectedCategoryId == catId,
                          onTap: () => _filterCategory(catId),
                        );
                      }),
                    ],
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: _filteredChannels.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(12),
                            child: Text("لا توجد قنوات هنا", style: TextStyle(color: Colors.white54, fontSize: 13)),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredChannels.length,
                          itemBuilder: (context, index) {
                            final ch = _filteredChannels[index];
                            final chId = 'live_${ch['stream_id']}';
                            final isFav = FavoritesStore.isFavorite(chId);
                            final isSelected = ch['stream_id'].toString() == _selectedStreamId;
                            return FocusableRow(
                              leading: const Icon(Icons.live_tv, color: Colors.white70, size: 20),
                              title: Text(
                                ch['name'] ?? '',
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: isFav ? const PyramidBadge() : null,
                              selected: isSelected,
                              onTap: () => _playChannel(ch),
                              onLongPress: () => _toggleFavorite(ch),
                            );
                          },
                        ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (_selectedStreamId.isNotEmpty) {
                        setState(() => _isFullscreen = true);
                        showControlsTemporarily();
                      }
                    },
                    child: _buildVideoArea(),
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

  String get _favPrefix => widget.type == "movie" ? "movie_" : "series_";
  String get _idField => widget.type == "movie" ? "stream_id" : "series_id";

  @override
  void initState() {
    super.initState();
    _loadVODData();
  }

  Future<void> _loadVODData() async {
    final catAction = widget.type == "movie" ? "get_vod_categories" : "get_series_categories";
    final itemAction = widget.type == "movie" ? "get_vod_streams" : "get_series";

    final catUrl =
        Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$catAction");
    final itemUrl =
        Uri.parse("$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=$itemAction");

    try {
      final catRes = await http.get(catUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});
      final itemRes = await http.get(itemUrl, headers: const {"User-Agent": "IPTVSmarters/1.0"});

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
      } else if (catId == 'favorites') {
        _filteredItems =
            _allItems.where((i) => FavoritesStore.isFavorite('$_favPrefix${i[_idField]}')).toList();
      } else {
        _filteredItems = _allItems.where((i) => i['category_id'].toString() == catId).toList();
      }
    });
  }

  void _openItem(dynamic item) {
    final name = (item['name'] ?? '').toString();

    if (widget.type == "movie") {
      final streamId = item['stream_id'];
      final ext = (item['container_extension'] ?? 'mp4').toString();
      final url = "$SERVER_URL/movie/${widget.username}/${widget.password}/$streamId.$ext";
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SimpleVideoPlayerScreen(title: name, url: url)),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SeriesDetailScreen(
            username: widget.username,
            password: widget.password,
            seriesItem: item,
          ),
        ),
      );
    }
  }

  Future<void> _toggleFavorite(dynamic item) async {
    await FavoritesStore.toggle('$_favPrefix${item[_idField]}');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: buildAppBar(widget.title),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : Row(
              children: [
                SizedBox(
                  width: 240,
                  child: ListView(
                    padding: const EdgeInsets.only(top: 4),
                    children: [
                      FocusableRow(
                        title: const Text("الكل (ALL)",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        selected: _selectedCategoryId == 'all',
                        onTap: () => _filterCategory('all'),
                      ),
                      FocusableRow(
                        leading: const Icon(Icons.star, color: AppColors.gold, size: 20),
                        title: const Text("المفضلة",
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        selected: _selectedCategoryId == 'favorites',
                        onTap: () => _filterCategory('favorites'),
                      ),
                      ..._categories.map((cat) {
                        final catId = cat['category_id'].toString();
                        return FocusableRow(
                          title: Text(cat['category_name'] ?? '',
                              style: const TextStyle(fontSize: 14, color: Colors.white)),
                          selected: _selectedCategoryId == catId,
                          onTap: () => _filterCategory(catId),
                        );
                      }),
                    ],
                  ),
                ),
                Expanded(
                  child: _filteredItems.isEmpty
                      ? const Center(
                          child: Text("لا يوجـد محتوى داخل هذه المجموعة", style: TextStyle(color: Colors.white70)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            childAspectRatio: 0.68,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                          ),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final cover = item['stream_icon'] ?? item['cover'] ?? '';
                            final name = item['name'] ?? '';
                            final isFav = FavoritesStore.isFavorite('$_favPrefix${item[_idField]}');

                            return RemoteFocusable(
                              onTap: () => _openItem(item),
                              onLongPress: () => _toggleFavorite(item),
                              child: Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.panel,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.gold.withOpacity(0.25)),
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
                                          colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                                          begin: Alignment.bottomCenter,
                                          end: Alignment.topCenter,
                                        ),
                                      ),
                                      child: Text(
                                        name,
                                        maxLines: 2,
                                        textAlign: TextAlign.center,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                  if (isFav) const Positioned(top: 6, right: 6, child: PyramidBadge(size: 22)),
                                ],
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

// --- 5. شاشة تفاصيل المسلسل: المواسم على الجنب، الحلقات كأيقونات كبيرة ---
class SeriesDetailScreen extends StatefulWidget {
  final String username;
  final String password;
  final dynamic seriesItem;

  const SeriesDetailScreen({
    super.key,
    required this.username,
    required this.password,
    required this.seriesItem,
  });

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic> _episodesBySeason = {};
  List<String> _seasonKeys = [];
  String _selectedSeason = '';

  @override
  void initState() {
    super.initState();
    _loadSeriesInfo();
  }

  Future<void> _loadSeriesInfo() async {
    final seriesId = widget.seriesItem['series_id'];
    final url = Uri.parse(
        "$SERVER_URL/player_api.php?username=${widget.username}&password=${widget.password}&action=get_series_info&series_id=$seriesId");

    try {
      final res = await http.get(url, headers: const {"User-Agent": "IPTVSmarters/1.0"});
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data is Map && data['episodes'] is Map) {
          final episodesMap = Map<String, dynamic>.from(data['episodes']);
          final keys = episodesMap.keys.toList()
            ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
          setState(() {
            _episodesBySeason = episodesMap;
            _seasonKeys = keys;
            _selectedSeason = keys.isNotEmpty ? keys.first : '';
            _isLoading = false;
          });
          return;
        }
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _playEpisode(dynamic episode) {
    final episodeId = episode['id'];
    final ext = (episode['container_extension'] ?? 'mp4').toString();
    final epTitle = (episode['title'] ?? widget.seriesItem['name'] ?? '').toString();
    final url = "$SERVER_URL/series/${widget.username}/${widget.password}/$episodeId.$ext";

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SimpleVideoPlayerScreen(title: epTitle, url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final episodes = _episodesBySeason[_selectedSeason] is List
        ? List<dynamic>.from(_episodesBySeason[_selectedSeason])
        : <dynamic>[];

    return GradientScaffold(
      appBar: buildAppBar((widget.seriesItem['name'] ?? 'Series').toString()),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
          : _seasonKeys.isEmpty
              ? const Center(
                  child: Text("لا توجد حلقات متاحة لهذا المسلسل حالياً", style: TextStyle(color: Colors.white70)))
              : Row(
                  children: [
                    SizedBox(
                      width: 220,
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 4),
                        itemCount: _seasonKeys.length,
                        itemBuilder: (context, index) {
                          final season = _seasonKeys[index];
                          final isSel = season == _selectedSeason;
                          return FocusableRow(
                            leading: const Icon(Icons.video_collection, color: AppColors.gold, size: 20),
                            title: Text("الموسم $season",
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                            selected: isSel,
                            onTap: () => setState(() => _selectedSeason = season),
                          );
                        },
                      ),
                    ),
                    Expanded(
                      child: episodes.isEmpty
                          ? const Center(
                              child: Text("لا توجد حلقات في هذا الموسم", style: TextStyle(color: Colors.white70)))
                          : GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                childAspectRatio: 0.8,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: episodes.length,
                              itemBuilder: (context, index) {
                                final ep = episodes[index];
                                final epNum = (ep['episode_num'] ?? (index + 1)).toString();
                                final epTitle = (ep['title'] ?? 'الحلقة $epNum').toString();
                                final epOwnCover =
                                    ep['info'] is Map ? (ep['info']['movie_image'] ?? '').toString() : '';
                                final seriesCover =
                                    (widget.seriesItem['cover'] ?? widget.seriesItem['stream_icon'] ?? '')
                                        .toString();
                                final cover = epOwnCover.isNotEmpty ? epOwnCover : seriesCover;

                                return RemoteFocusable(
                                  onTap: () => _playEpisode(ep),
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: AppColors.panel,
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                                          image: cover.isNotEmpty
                                              ? DecorationImage(
                                                  image: NetworkImage(cover),
                                                  fit: BoxFit.cover,
                                                  colorFilter: ColorFilter.mode(
                                                      Colors.black.withOpacity(0.25), BlendMode.darken),
                                                )
                                              : null,
                                        ),
                                        child: cover.isEmpty
                                            ? Center(
                                                child: Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration:
                                                      const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
                                                  child: Center(
                                                    child: Text(
                                                      epNum,
                                                      style: const TextStyle(
                                                          fontSize: 20,
                                                          fontWeight: FontWeight.bold,
                                                          color: Colors.white),
                                                    ),
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      if (cover.isNotEmpty)
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.red,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: AppColors.gold, width: 1),
                                            ),
                                            child: Text(
                                              epNum,
                                              style: const TextStyle(
                                                  fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                                            gradient: LinearGradient(
                                              colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                                              begin: Alignment.bottomCenter,
                                              end: Alignment.topCenter,
                                            ),
                                          ),
                                          child: Text(
                                            epTitle,
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ],
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

// --- 6. شاشة تشغيل الفيديو: تختفي كل عناصر التحكم تلقائيًا وتظهر باللمس ---
class SimpleVideoPlayerScreen extends StatefulWidget {
  final String title;
  final String url;

  const SimpleVideoPlayerScreen({super.key, required this.title, required this.url});

  @override
  State<SimpleVideoPlayerScreen> createState() => _SimpleVideoPlayerScreenState();
}

class _SimpleVideoPlayerScreenState extends State<SimpleVideoPlayerScreen>
    with AutoHideControls<SimpleVideoPlayerScreen> {
  VideoPlayerController? _controller;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    startAutoHide();
  }

  Future<void> _initPlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
        httpHeaders: const {"User-Agent": "IPTVSmarters/1.0"},
      );
      await controller.initialize();
      if (!mounted) return;
      setState(() => _controller = controller);
      controller.play();
    } catch (e) {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  void _seek(int seconds) {
    final controller = _controller;
    if (controller == null) return;
    final duration = controller.value.duration;
    final target = controller.value.position + Duration(seconds: seconds);
    final clamped = target < Duration.zero ? Duration.zero : (target > duration ? duration : target);
    controller.seekTo(clamped);
  }

  @override
  void dispose() {
    disposeAutoHide();
    _controller?.dispose();
    super.dispose();
  }

  Widget _controlButton(IconData icon, VoidCallback onTap, {bool big = false}) {
    return RemoteFocusable(
      onTap: () {
        onTap();
        showControlsTemporarily();
      },
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: big ? 64 : 48,
        height: big ? 64 : 48,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: big ? AppColors.red : Colors.black.withOpacity(0.55),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.gold.withOpacity(0.7), width: 1.4),
        ),
        child: Icon(icon, color: Colors.white, size: big ? 32 : 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: toggleControls,
        child: Stack(
          children: [
            Center(
              child: _hasError
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "تعذر تشغيل هذا الفيديو، جرّب مرة أخرى لاحقاً",
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : (controller != null && controller.value.isInitialized)
                      ? ValueListenableBuilder<VideoPlayerValue>(
                          valueListenable: controller,
                          builder: (context, value, child) {
                            return AspectRatio(
                              aspectRatio: value.aspectRatio,
                              child: VideoPlayer(controller),
                            );
                          },
                        )
                      : Container(color: Colors.black),
            ),
            AnimatedOpacity(
              opacity: controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !controlsVisible,
                child: SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: AppColors.gold, size: 24),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(fontSize: 16, color: AppColors.gold, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (controller != null && controller.value.isInitialized)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: controller,
                builder: (context, value, child) {
                  return AnimatedOpacity(
                    opacity: controlsVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 250),
                    child: IgnorePointer(
                      ignoring: !controlsVisible,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _controlButton(Icons.replay_10, () => _seek(-10)),
                              _controlButton(
                                value.isPlaying ? Icons.pause : Icons.play_arrow,
                                () => value.isPlaying ? controller.pause() : controller.play(),
                                big: true,
                              ),
                              _controlButton(Icons.forward_10, () => _seek(10)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// --- 7. شاشة الإعدادات ---
class SettingsScreen extends StatefulWidget {
  final String username;
  final String password;
  final String expDateStr;

  const SettingsScreen({
    super.key,
    required this.username,
    required this.password,
    required this.expDateStr,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      appBar: buildAppBar("Settings"),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _infoTile("اسم المستخدم", widget.username, Icons.person),
          const SizedBox(height: 12),
          _infoTile(
            "كلمة السر",
            _showPassword ? widget.password : List.filled(widget.password.length, '•').join(),
            Icons.lock,
            trailing: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off : Icons.visibility,
                color: AppColors.gold,
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
          const SizedBox(height: 12),
          _infoTile("تاريخ الانتهاء", widget.expDateStr, Icons.event),
          const SizedBox(height: 28),
          const Text("تواصل معنا", style: TextStyle(color: AppColors.gold, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          FocusableRow(
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: AppColors.red, shape: BoxShape.circle),
              child: const Icon(Icons.call, color: Colors.white, size: 20),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("اتصال هاتفي", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(CONTACT_PHONE_DISPLAY, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            trailing: const Icon(Icons.chevron_left, color: AppColors.gold),
            onTap: launchPhoneCall,
          ),
          const SizedBox(height: 10),
          FocusableRow(
            leading: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
              child: const Icon(Icons.chat, color: Colors.white, size: 20),
            ),
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("واتساب", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                Text(CONTACT_PHONE_DISPLAY, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            trailing: const Icon(Icons.chevron_left, color: AppColors.gold),
            onTap: launchWhatsApp,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text("تسجيل الخروج", style: TextStyle(fontSize: 15, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7A1010),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: AppColors.gold.withOpacity(0.6), width: 1.2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.white, fontSize: 15)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
