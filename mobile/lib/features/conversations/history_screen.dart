import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_controller.dart';
import '../chat/widgets/atmospheric_background.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryState();
}

class _HistoryState extends ConsumerState<HistoryScreen> {
  late Future<dynamic> items;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  void refresh() {
    setState(() => items = ref.read(apiProvider).get('/conversations'));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المحادثات'),
      ),
      body: AtmosphericBackground(
        child: SafeArea(
          child: FutureBuilder(
            future: items,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: TextButton(
                    onPressed: refresh,
                    child: Text(friendlyError(snapshot.error!)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              final data = snapshot.data as List;
              if (data.isEmpty) {
                return const Center(
                  child: Text(
                    'ما عندك حتى محادثة دابا. بدا بالميكروفون!',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  refresh();
                  await items;
                },
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      itemCount: data.length,
                      itemBuilder: (context, index) {
                        final item = data[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                            side: BorderSide(
                              color: isDark
                                  ? AppColors.borderDark
                                  : const Color(0xFFEDE8F6),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            leading: Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? const Color(0xFF2B2544)
                                    : AppColors.primaryTint,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.primary,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              item['title'] ?? 'محادثة',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              item['created_at'].toString().split('T').first,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(chatProvider.notifier)
                                    .open(item['id']);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(friendlyError(e)),
                                    ),
                                  );
                                }
                              }
                            },
                            trailing: IconButton(
                              tooltip: 'حيد المحادثة',
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (dialogContext) => AlertDialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(22),
                                    ),
                                    title: const Text('نحيدو هاد المحادثة؟'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, false),
                                        child: const Text('تراجع'),
                                      ),
                                      FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: AppColors.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(dialogContext, true),
                                        child: const Text('حذف'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm != true) {
                                  return;
                                }
                                try {
                                  await ref
                                      .read(apiProvider)
                                      .delete('/conversations/${item['id']}');
                                  if (ref.read(chatProvider).conversationId ==
                                      item['id']) {
                                    ref.read(chatProvider.notifier).fresh();
                                  }
                                  refresh();
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(friendlyError(e)),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
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
