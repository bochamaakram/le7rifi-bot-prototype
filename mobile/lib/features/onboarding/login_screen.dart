import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../chat/chat_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final token = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    resume();
  }

  Future<void> resume() async {
    if (await ref.read(sessionProvider).read() != null && mounted)
      await connect(resuming: true);
  }

  Future<void> connect({bool resuming = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!resuming) await ref.read(sessionProvider).save(token.text.trim());
      await ref.read(apiProvider).get('/me');
      if (mounted) context.go('/chat');
    } catch (e) {
      await ref.read(sessionProvider).clear();
      if (mounted) setState(() => error = friendlyError(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.graphic_eq_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'الحريفي AI',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'المعاون ديالك، بالدارجة\nأفكار ومحتوى باش تكبر خدمتك',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'نسخة تجريبية • الربط بالمنصة مازال\nدخل رمز التطوير من إعدادات الخادم. بيانات الحرفة تجريبية.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: token,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(labelText: 'رمز الدخول'),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(error!),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: busy ? null : () => connect(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(busy ? 'كنربطو…' : 'نبداو'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'التسجيل الصوتي كيتحيد من بعد المعالجة. الصوت والنص كيتصيفطو لمزود AI. الأجوبة اقتراحات وما كتبدل والو فالمنصة.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
