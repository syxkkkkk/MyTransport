import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/location_selection_screen.dart';
import 'screens/route_details_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/trip_summary_screen.dart';
import 'screens/live_train_notifications_screen.dart';
import 'screens/ar_navigation_screen.dart';

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

// On web, wraps the app in a centered 393×852 phone frame so it renders
// at mobile proportions regardless of browser window size.
class _MobileFrame extends StatelessWidget {
  final Widget child;
  const _MobileFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 393,
          height: 852,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(44),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 60,
                spreadRadius: 4,
              ),
            ],
          ),
          child: child,
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
      builder: (context, child) => _MobileFrame(child: child!),
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
            screen = const ARNavigationScreen();
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
