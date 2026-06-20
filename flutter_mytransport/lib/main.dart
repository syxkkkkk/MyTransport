import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/location_selection_screen.dart';
import 'screens/route_details_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/trip_summary_screen.dart';
import 'screens/live_train_notifications_screen.dart';
import 'screens/ar_navigation_screen.dart';
import 'screens/nearby_bus_screen.dart';
import 'screens/live_bus_screen.dart';
import 'screens/all_bus_stops_screen.dart';
import 'screens/transit_map_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyTransportApp());
}

// ─── iPhone 16 dimensions ────────────────────────────────────────────────────
// Screen:        390 × 844 pt  (logical)
// Outer shell:   +12pt padding on each side  →  414 × 896
// Corner radius (screen): 47 pt
// Corner radius (shell):  55 pt
// Dynamic Island: 126 × 37 pt pill, centred, 12 pt from top of screen
// Side button:   right side, 3 separate raised shapes
// Volume/Action: left side
const double _screenW = 390;
const double _screenH = 844;
const double _bezel = 11.0;          // frame thickness around screen
const double _shellW = _screenW + _bezel * 2;
const double _shellH = _screenH + _bezel * 2;
const double _screenRadius = 47.0;
const double _shellRadius = 55.0;

class _IPhone16Frame extends StatelessWidget {
  final Widget child;
  const _IPhone16Frame({required this.child});

  bool get _needsFrame =>
      kIsWeb || Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    if (!_needsFrame) return child;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: SizedBox(
          width: _shellW,
          height: _shellH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Outer titanium shell ─────────────────────────────────────
              Positioned.fill(
                child: CustomPaint(painter: _IPhoneShellPainter()),
              ),

              // ── Left-side buttons (Volume Down, Volume Up, Action) ────────
              ..._leftButtons(),

              // ── Right-side button (Sleep/Wake) ────────────────────────────
              ..._rightButtons(),

              // ── Screen area ───────────────────────────────────────────────
              Positioned(
                left: _bezel,
                top: _bezel,
                width: _screenW,
                height: _screenH,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_screenRadius),
                  child: Stack(
                    children: [
                      // App content
                      Positioned.fill(child: child),

                      // iOS status bar (above Dynamic Island area)
                      Positioned(
                        top: 0, left: 0, right: 0,
                        child: const _IOSStatusBar(),
                      ),

                      // Dynamic Island
                      Positioned(
                        top: 12,
                        left: 0, right: 0,
                        child: Center(child: const _DynamicIsland()),
                      ),

                      // Home indicator
                      Positioned(
                        bottom: 8, left: 0, right: 0,
                        child: const _HomeIndicator(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _leftButtons() {
    // Action button (top), Volume Up, Volume Down
    final buttonDefs = [
      (top: 88.0,  height: 32.0),  // Action button
      (top: 138.0, height: 58.0),  // Volume Up
      (top: 206.0, height: 58.0),  // Volume Down
    ];
    return buttonDefs.map((b) => Positioned(
      left: -4,
      top: b.top,
      child: Container(
        width: 5,
        height: b.height,
        decoration: BoxDecoration(
          color: const Color(0xFF3A3A3C),
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.6),
              blurRadius: 3,
              offset: const Offset(-1, 1),
            ),
          ],
        ),
      ),
    )).toList();
  }

  List<Widget> _rightButtons() {
    return [
      Positioned(
        right: -4,
        top: 160.0,
        child: Container(
          width: 5,
          height: 72.0,
          decoration: BoxDecoration(
            color: const Color(0xFF3A3A3C),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 3,
                offset: const Offset(1, 1),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

/// Paints the titanium shell with gradient and subtle inner shadow.
class _IPhoneShellPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(_shellRadius),
    );

    // Outer glow / shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.7)
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 18);
    canvas.drawRRect(rr, shadowPaint);

    // Titanium body gradient (Black Titanium colorway)
    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF4A4A4E),
          const Color(0xFF2C2C2E),
          const Color(0xFF1C1C1E),
          const Color(0xFF2C2C2E),
          const Color(0xFF3A3A3C),
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRRect(rr, bodyPaint);

    // Subtle specular highlight on top edge
    final highlightPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.15));
    final highlightRR = RRect.fromRectAndCorners(
      Rect.fromLTWH(1, 1, size.width - 2, size.height * 0.15),
      topLeft: const Radius.circular(_shellRadius - 1),
      topRight: const Radius.circular(_shellRadius - 1),
    );
    canvas.drawRRect(highlightRR, highlightPaint);

    // Inner screen cutout — slightly inset
    final cutoutRR = RRect.fromRectAndRadius(
      Rect.fromLTWH(_bezel, _bezel, _screenW, _screenH),
      const Radius.circular(_screenRadius),
    );
    canvas.drawRRect(cutoutRR, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Dynamic Island — black pill with inner glow.
class _DynamicIsland extends StatelessWidget {
  const _DynamicIsland();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 126,
      height: 37,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.8),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      // Front camera + Face ID sensors as tiny circles
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF2D2D2D), width: 1),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS 18 status bar — time left, icons right, Dynamic Island gap in the middle.
class _IOSStatusBar extends StatelessWidget {
  const _IOSStatusBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Padding(
        padding: const EdgeInsets.only(top: 14, left: 22, right: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Time
            const Text(
              '9:41',
              style: TextStyle(
                color: Colors.black,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.3,
              ),
            ),
            // Right icons
            Row(
              children: [
                _SignalBars(),
                const SizedBox(width: 6),
                const Icon(Icons.wifi, color: Colors.black, size: 15),
                const SizedBox(width: 6),
                _BatteryIcon(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final h = 4.0 + i * 2.5;
        return Padding(
          padding: const EdgeInsets.only(right: 1.5),
          child: Container(
            width: 3.5,
            height: h,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      }),
    );
  }
}

class _BatteryIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 13,
      child: Stack(
        children: [
          Container(
            width: 23,
            height: 13,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: BorderRadius.circular(3),
            ),
            padding: const EdgeInsets.all(1.5),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 4,
            child: Container(
              width: 3,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// iOS home indicator — short rounded pill at the bottom.
class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 134,
        height: 5,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}

class MyTransportApp extends StatelessWidget {
  const MyTransportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyTransport Malaysia',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/welcome',
      builder: (context, child) => _IPhone16Frame(child: child!),
      onGenerateRoute: (settings) {
        Widget screen;
        switch (settings.name) {
          case '/welcome':
            screen = const WelcomeScreen();
          case '/home':
            screen = const HomeScreen();
          case '/location-selection':
            screen = const LocationSelectionScreen();
          case '/route-details':
            screen = const RouteDetailsScreen();
          case '/chatbot':
            screen = const ChatbotScreen();
          case '/trip-summary':
            screen = const TripSummaryScreen();
          case '/live-train':
            screen = const LiveTrainNotificationsScreen();
          case '/ar-navigation':
            screen = const ARNavigationScreen(); // args: {latitude, longitude, stationName}
          case '/nearby-bus':
            screen = const NearbyBusScreen();
          case '/live-bus':
            screen = const LiveBusScreen();
          case '/all-bus-stops':
            screen = const AllBusStopsScreen();
          case '/transit-map':
            screen = const TransitMapScreen();
          case '/profile':
            screen = const ProfileScreen();
          default:
            screen = const WelcomeScreen();
        }
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (_, __, ___) => screen,
          transitionsBuilder: (_, animation, __, child) {
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end)
                .chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
      },
    );
  }
}
