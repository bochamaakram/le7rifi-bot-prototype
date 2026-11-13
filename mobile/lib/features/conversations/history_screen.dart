import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../chat/chat_controller.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('المحادثات ديالك')),
    body: FutureBuilder(
      future: items,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: refresh,
              child: Text(friendlyError(snapshot.error!)),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final data = snapshot.data as List;
        if (data.isEmpty)
          return const Center(
            child: Text('ما عندك حتى محادثة دابا. بدا بالميكروفون!'),
          );
        return RefreshIndicator(
          onRefresh: () async {
            refresh();
            await items;
          },
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, index) {
              final item = data[index];
              return ListTile(
                leading: const Icon(Icons.chat_bubble_outline),
                title: Text(item['title']),
                subtitle: Text(item['created_at'].toString().split('T').first),
                onTap: () async {
                  try {
                    await ref.read(chatProvider.notifier).open(item['id']);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted)
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                  }
                },
                trailing: IconButton(
                  tooltip: 'حيد المحادثة',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('نحيدو هاد المحادثة؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('رجع'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('حيد'),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    try {
                      await ref
                          .read(apiProvider)
                          .delete('/conversations/${item['id']}');
                      if (ref.read(chatProvider).conversationId == item['id'])
                        ref.read(chatProvider.notifier).fresh();
                      refresh();
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyError(e))),
                        );
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    ),
  );
}
