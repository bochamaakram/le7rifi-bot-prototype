import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_client.dart';
import '../chat/chat_controller.dart';

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
      if (mounted)
        setState(() {
          existing = Map<String, dynamic>.from(data);
          enabled = data['enabled'] ?? false;
          script = data['script'] ?? ref.read(scriptProvider);
        });
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> action(Future<void> Function() work) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await work();
    } catch (e) {
      if (mounted) setState(() => error = friendlyError(e));
    }
    if (mounted) setState(() => busy = false);
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
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تسجلات الإعدادات. افتح محادثة جديدة باش تتطبق.'),
        ),
      );
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('الإعدادات والخصوصية')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (busy) const LinearProgressIndicator(),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ListTile(
          leading: const Icon(Icons.storefront_outlined),
          title: const Text('معلومات الحرفة'),
          onTap: () => context.push('/business'),
        ),
        SwitchListTile(
          title: const Text('حفظ التفضيلات بموافقتي'),
          value: enabled,
          subtitle: const Text(
            'إلا طفيتيها كيتحيدو التفضيلات المحفوظة. المحادثات كتتحفظ 30 يوم.',
          ),
          onChanged: busy ? null : (value) => setState(() => enabled = value),
        ),
        DropdownButtonFormField<String>(
          initialValue: script,
          decoration: const InputDecoration(labelText: 'كتابة الدارجة'),
          items: const [
            DropdownMenuItem(value: 'arabic', child: Text('بالحروف العربية')),
            DropdownMenuItem(value: 'latin', child: Text('B l7orof latinia')),
          ],
          onChanged: busy ? null : (value) => setState(() => script = value!),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy ? null : save,
          child: const Text('وافق وحفظ'),
        ),
        const SizedBox(height: 20),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  await ref.read(apiProvider).delete('/memory/preferences');
                  await load();
                }),
          child: const Text('حيد التفضيلات المحفوظة'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  final data = await ref
                      .read(apiProvider)
                      .get('/memory/export');
                  if (!mounted) return;
                  final text = const JsonEncoder.withIndent('  ').convert(data);
                  await showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('تصدير المعلومات ديالك'),
                      content: SingleChildScrollView(
                        child: SelectableText(text),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: text));
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text('نسخ'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('سد'),
                        ),
                      ],
                    ),
                  );
                }),
          child: const Text('صدّر معلوماتي'),
        ),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  final data = await ref.read(apiProvider).get('/usage');
                  if (mounted)
                    await showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('الاستعمال هاد الشهر'),
                        content: Text(
                          '${data['user_units']} / ${data['user_limit']} وحدة\n'
                          'الوحدات حدود الاستعمال، ماشي ثمن بالدرهم.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('سد'),
                          ),
                        ],
                      ),
                    );
                }),
          child: const Text('شوف الاستعمال'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'الصوت كيتحيد من بعد المعالجة. النص والصوت كيمشيو لمزود الذكاء الاصطناعي وقد يتعالجو خارج المغرب. '
            'ما تصيفطش معلومات حساسة ديال الزبناء. تقدر تحيد المحادثات من لائحة المحادثات.',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => action(() async {
                  await ref.read(sessionProvider).clear();
                  ref.read(chatProvider.notifier).fresh();
                  if (mounted) context.go('/');
                }),
          child: const Text('خرج من الحساب'),
        ),
      ],
    ),
  );
}
