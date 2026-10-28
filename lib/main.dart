import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/providers.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'screens/household_setup_screen.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: BubuDuduApp()));
}

class BubuDuduApp extends StatelessWidget {
  const BubuDuduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bubu & Dudu',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

// Unsere Lieblingsfarbe: Dunkelgrün.
const _darkGreen = Color(0xFF1B5E20);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _darkGreen,
    brightness: brightness,
    dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
  );
  return ThemeData(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light ? _darkGreen : null,
      foregroundColor: brightness == Brightness.light ? Colors.white : null,
    ),
  );
}

/// Entscheidet, welcher Bildschirm gezeigt wird:
/// nicht angemeldet → Login, ohne Haushalt → Einrichtung, sonst → Start.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final profile = ref.watch(userProfileProvider);

    if (auth.isLoading || profile.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.value == null) return const LoginScreen();

    final householdId = profile.value?.householdId;
    if (householdId == null) return const HouseholdSetupScreen();
    return HomeScreen(householdId: householdId);
  }
}
