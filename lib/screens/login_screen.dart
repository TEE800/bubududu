import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final auth = FirebaseAuth.instance;
    try {
      if (_register) {
        final name = _name.text.trim();
        if (name.isEmpty) throw StateError('Bitte gib deinen Namen ein.');
        final cred = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await cred.user!.updateDisplayName(name);
        await ref
            .read(householdRepositoryProvider)
            .createProfile(cred.user!.uid, name);
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _message(e.code));
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _message(String code) => switch (code) {
    'invalid-email' => 'Die E-Mail-Adresse ist ungültig.',
    'email-already-in-use' => 'Mit dieser E-Mail gibt es schon ein Konto.',
    'weak-password' => 'Das Passwort braucht mindestens 6 Zeichen.',
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' => 'E-Mail oder Passwort stimmen nicht.',
    _ => 'Das hat nicht geklappt ($code).',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bubu & Dudu',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Euer gemeinsamer Alltag in einer App',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_register) ...[
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Dein Name'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: 'E-Mail'),
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: 'Passwort'),
                  obscureText: true,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_register ? 'Konto erstellen' : 'Anmelden'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _register = !_register),
                  child: Text(
                    _register
                        ? 'Ich habe schon ein Konto'
                        : 'Neu hier? Konto erstellen',
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
