import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/atmospheric_background.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  bool enabled = false, busy = true;
  String script = 'arabic';
  String? error;
  Map<String, dynamic> existing = {};

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await ref.read(apiProvider).get('/memory/preferences');
      if (mounted) {
        setState(() {
          existing = Map<String, dynamic>.from(data);
          enabled = data['enabled'] ?? false;
          script = data['script'] ?? ref.read(scriptProvider);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  Future<void> action(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) {
        setState(() => error = friendlyError(e));
      }
    }
    if (mounted) {
      setState(() => busy = false);
    }
  }

  Future<void> save() => action(() async {
        ref.read(scriptProvider.notifier).select(script);
        await ref.read(apiProvider).put('/memory/preferences', {
          'enabled': enabled,
          'script': script,
          'response_length': existing['response_length'] ?? 'short',
          'business_goals': existing['business_goals'] ?? '',
          'content_preferences': existing['content_preferences'] ?? '',
          'approved': true,
        });
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تسجلات الإعدادات. افتح محادثة جديدة باش تتطبق.'),
          ),
        );
      });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات والخصوصية')),
      body: AtmosphericBackground(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (busy) const LinearProgressIndicator(color: AppColors.primary),
                  if (error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),

                  // Business profile link card
                  Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF2C2544)
                              : AppColors.primaryTint,
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primary,
                        ),
                      ),
                      title: const Text(
                        'معلومات الحرفة',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text('عرض خدمات الحرفة وبيانات النشاط'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onTap: () => context.push('/business'),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Preferences Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'حفظ التفضيلات بموافقتي',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: const Text(
                              'إلا طفيتيها كيتحيدو التفضيلات المحفوظة. المحادثات كتتحفظ 30 يوم.',
                              style: TextStyle(fontSize: 12),
                            ),
                            value: enabled,
                            activeThumbColor: AppColors.primary,
                            onChanged: busy
                                ? null
                                : (value) => setState(() => enabled = value),
                          ),
                          const Divider(height: 24),
                          DropdownButtonFormField<String>(
                            initialValue: script,
                            decoration: const InputDecoration(
                              labelText: 'طريقة كتابة الدارجة',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'arabic',
                                child: Text('بالحروف العربية (العربية)'),
                              ),
                              DropdownMenuItem(
                                value: 'latin',
                                child: Text('B l7orof latinia (العرنسية)'),
                              ),
                            ],
                            onChanged: busy
                                ? null
                                : (value) => setState(() => script = value!),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: busy ? null : save,
                            child: const Text(
                              'وافق وحفظ التفضيلات',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Actions Group
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => action(() async {
                                      await ref
                                          .read(apiProvider)
                                          .delete('/memory/preferences');
                                      await load();
                                    }),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('حيد التفضيلات المحفوظة'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => action(() async {
                                      final data = await ref
                                          .read(apiProvider)
                                          .get('/memory/export');
                                      if (!mounted) {
                                        return;
                                      }
                                      final text =
                                          const JsonEncoder.withIndent('  ')
                                              .convert(data);
                                      if (!context.mounted) {
                                        return;
                                      }
                                      await showDialog<void>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          title: const Text('تصدير المعلومات ديالك'),
                                          content: SingleChildScrollView(
                                            child: SelectableText(text),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () async {
                                                await Clipboard.setData(
                                                  ClipboardData(text: text),
                                                );
                                                if (dialogCtx.mounted) {
                                                  Navigator.pop(dialogCtx);
                                                }
                                              },
                                              child: const Text('نسخ'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogCtx),
                                              child: const Text('إغلاق'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                            icon: const Icon(Icons.file_download_outlined, size: 18),
                            label: const Text('صدّر معلوماتي'),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : () => action(() async {
                                      final data = await ref
                                          .read(apiProvider)
                                          .get('/usage');
                                      if (!context.mounted) {
                                        return;
                                      }
                                      await showDialog<void>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          title: const Text('الاستعمال هاد الشهر'),
                                          content: Text(
                                            '${data['user_units']} / ${data['user_limit']} وحدة\n'
                                            'الوحدات حدود الاستعمال، ماشي ثمن بالدرهم.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogCtx),
                                              child: const Text('إغلاق'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                            icon: const Icon(Icons.speed_rounded, size: 18),
                            label: const Text('شوف الاستعمال'),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18, horizontal: 4),
                    child: Text(
                      'الصوت كيتحيد من بعد المعالجة. النص والصوت كيمشيو لمزود الذكاء الاصطناعي وقد يتعالجو خارج المغرب. '
                      'ما تصيفطش معلومات حساسة ديال الزبناء. تقدر تحيد المحادثات من لائحة المحادثات.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: busy
                        ? null
                        : () => action(() async {
                              await ref.read(sessionProvider).clear();
                              ref.read(chatProvider.notifier).fresh();
                              if (context.mounted) {
                                context.go('/');
                              }
                            }),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('تسجيل الخروج من الحساب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
