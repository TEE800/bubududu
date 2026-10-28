import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';

/// Nach dem ersten Login: eigenen Haushalt anlegen oder per Code beitreten.
class HouseholdSetupScreen extends ConsumerStatefulWidget {
  const HouseholdSetupScreen({super.key});

  @override
  ConsumerState<HouseholdSetupScreen> createState() =>
      _HouseholdSetupScreenState();
}

class _HouseholdSetupScreenState extends ConsumerState<HouseholdSetupScreen> {
  final _name = TextEditingController(text: 'Unser Zuhause');
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(
    Future<void> Function(String uid, String displayName) action,
  ) async {
    final user = FirebaseAuth.instance.currentUser!;
    final displayName =
        ref.read(userProfileProvider).value?.displayName ??
        user.displayName ??
        'Ich';
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(user.uid, displayName);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Das hat nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(householdRepositoryProvider);
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haushalt verbinden'),
        actions: [
          IconButton(
            tooltip: 'Abmelden',
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Neuen Haushalt anlegen', style: textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Du bekommst danach einen Code, mit dem dein Schatz beitreten kann.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name des Haushalts'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (uid, displayName) => repo.createHousehold(
                      uid: uid,
                      displayName: displayName,
                      name: _name.text.trim().isEmpty
                          ? 'Unser Zuhause'
                          : _name.text.trim(),
                    ),
                  ),
            child: const Text('Haushalt anlegen'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Divider(),
          ),
          Text('Mit Code beitreten', style: textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Einladungscode'),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () => _run(
                    (uid, displayName) => repo.joinHousehold(
                      uid: uid,
                      displayName: displayName,
                      code: _code.text,
                    ),
                  ),
            child: const Text('Beitreten'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
