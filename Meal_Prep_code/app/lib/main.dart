import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'firebase_options.dart';
import 'screens/cook/cook_home.dart';
import 'screens/customer/customer_home.dart';
import 'screens/intro_screen.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'state/session.dart';
import 'theme/app_theme.dart';
import 'widgets/emoji_art.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (useFirebase) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(
    ChangeNotifierProvider(
      create: (_) => Session()..restore(),
      child: const MealPrepApp(),
    ),
  );
}

class MealPrepApp extends StatelessWidget {
  const MealPrepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Prep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<Session>();
    final Widget page;
    if (s.loading) {
      page = const _Splash();
    } else if (!s.introSeen) {
      page = const IntroScreen();
    } else if (s.user == null) {
      page = const LoginScreen();
    } else if (s.user!.name.isEmpty) {
      page = const OnboardingScreen();
    } else {
      page = s.user!.isCook ? const CookHome() : const CustomerHome();
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: page);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const EmojiArt('🍛', size: 120),
          const SizedBox(height: 16),
          Text('Meal Prep', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 24),
          const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ]),
      ),
    );
  }
}
