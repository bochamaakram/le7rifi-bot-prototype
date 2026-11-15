import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/atmospheric_background.dart';
import '../chat/widgets/luminous_orb.dart';

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
    if (await ref.read(sessionProvider).read() != null && mounted) {
      await connect(resuming: true);
    }
  }

  Future<void> connect({bool resuming = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!resuming) {
        await ref.read(sessionProvider).save(token.text.trim());
      }
      await ref.read(apiProvider).get('/me');
      if (mounted) {
        context.go('/chat');
      }
    } catch (e) {
      await ref.read(sessionProvider).clear();
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  void dispose() {
    token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark ? AppColors.borderDark : const Color(0xFFEDE8F6),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
                        blurRadius: 32,
                        spreadRadius: 2,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Luminous Orb Centerpiece
                      const Center(
                        child: LuminousOrb(size: 88),
                      ),
                      const SizedBox(height: 20),

                      // Title & Subtitle
                      const Text(
                        'الحريفي AI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'المعاون ديالك بالدارجة\nأفكار ومحتوى باش تكبر خدمتك',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sandbox / Mock Banner (labels test data cleanly)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF221F33)
                              : const Color(0xFFF7F4FD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF38324E)
                                : const Color(0xFFE8DEF8),
                          ),
                        ),
                        child: const Text(
                          'نسخة تجريبية • الربط بالمنصة مازال\nدخل رمز التطوير من إعدادات الخادم. بيانات الحرفة تجريبية.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Color(0xFF6E5F8C),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Token Input Field
                      TextField(
                        controller: token,
                        obscureText: true,
                        autocorrect: false,
                        enableSuggestions: false,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          labelText: 'رمز الدخول',
                          prefixIcon: Icon(Icons.key_rounded, size: 20),
                        ),
                      ),

                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(
                          error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 24),

                      // High Contrast Entry Pill Button
                      Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.primary : AppColors.darkPill,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: busy ? null : () => connect(),
                            child: Center(
                              child: busy
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'دخول للخدمة',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
