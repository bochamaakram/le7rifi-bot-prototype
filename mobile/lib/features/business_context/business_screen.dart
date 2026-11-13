import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../chat/chat_controller.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('معلومات الحرفة')),
    body: FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Center(
            child: TextButton(
              onPressed: load,
              child: Text(friendlyError(snapshot.error!)),
            ),
          );
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        final profile = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(profile['notice']),
              ),
            ),
            ListTile(
              title: Text(profile['business_name']),
              subtitle: Text('${profile['profession']} • ${profile['city']}'),
            ),
            for (final service in profile['services'])
              ListTile(
                leading: const Icon(Icons.handyman_outlined),
                title: Text(service),
              ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'هاد التطبيق كيقرا المعلومات فقط. ما كيبدل حتى حاجة فالمنصة.',
              ),
            ),
          ],
        );
      },
    ),
  );
}
