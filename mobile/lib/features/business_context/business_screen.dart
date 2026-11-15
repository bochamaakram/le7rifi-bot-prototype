import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/atmospheric_background.dart';

class BusinessScreen extends ConsumerStatefulWidget {
  const BusinessScreen({super.key});
  @override
  ConsumerState<BusinessScreen> createState() => _BusinessState();
}

class _BusinessState extends ConsumerState<BusinessScreen> {
  late Future<dynamic> data;

  @override
  void initState() {
    super.initState();
    load();
  }

  void load() =>
      setState(() => data = ref.read(apiProvider).get('/business/context'));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('معلومات الحرفة')),
      body: AtmosphericBackground(
        child: SafeArea(
          child: FutureBuilder(
            future: data,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: load,
                    child: Text(friendlyError(snapshot.error!)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final profile = snapshot.data;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Notice Card
                      Card(
                        color: isDark
                            ? const Color(0xFF221F33)
                            : const Color(0xFFF7F4FD),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isDark
                                ? const Color(0xFF38324E)
                                : const Color(0xFFE8DEF8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Text(
                            profile['notice'],
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6E5F8C),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Business Identity Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? const Color(0xFF2C2544)
                                      : AppColors.primaryTint,
                                ),
                                child: const Icon(
                                  Icons.business_center_rounded,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      profile['business_name'],
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${profile['profession']} • ${profile['city']}',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Services Card
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'الخدمات المسجلة',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              for (final service in profile['services'])
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          service,
                                          style: const TextStyle(fontSize: 13.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),

                      const Padding(
                        padding: EdgeInsets.all(18),
                        child: Text(
                          'هاد التطبيق كيقرا المعلومات فقط. ما كيبدل حتى حاجة فالمنصة.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
