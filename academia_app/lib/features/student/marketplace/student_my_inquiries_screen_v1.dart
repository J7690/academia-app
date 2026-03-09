import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/student_marketplace_inquiries_provider_v1.dart';
import 'student_inquiry_chat_screen_v1.dart';

class StudentMyInquiriesScreenV1 extends StatefulWidget {
  const StudentMyInquiriesScreenV1({super.key});

  @override
  State<StudentMyInquiriesScreenV1> createState() =>
      _StudentMyInquiriesScreenV1State();
}

class _StudentMyInquiriesScreenV1State extends State<StudentMyInquiriesScreenV1> {
  late final StudentMarketplaceInquiriesProviderV1 _provider;

  @override
  void initState() {
    super.initState();
    _provider = StudentMarketplaceInquiriesProviderV1();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider.loadMyInquiries();
    });
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<StudentMarketplaceInquiriesProviderV1>(
        builder: (context, provider, child) {
          final items = provider.inquiries;
          return Scaffold(
            backgroundColor: const Color(0xFFF3F4F6),
            appBar: AppBar(
              title: const Text('Mes demandes'),
              actions: [
                IconButton(
                  onPressed: provider.isLoading ? null : provider.loadMyInquiries,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: Column(
              children: [
                if (provider.error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.withOpacity(0.08),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
                Expanded(
                  child: provider.isLoading && items.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : items.isEmpty
                          ? RefreshIndicator(
                              onRefresh: () => provider.loadMyInquiries(),
                              child: ListView(
                                children: const [
                                  SizedBox(height: 80),
                                  Center(child: Text('Aucune demande.')),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => provider.loadMyInquiries(),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(12),
                                itemCount: items.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final i = items[index];
                                  final id = i['id']?.toString() ?? '';
                                  final status = i['status']?.toString() ?? '';
                                  final msg = i['message']?.toString() ?? '';
                                  final opportunityId =
                                      i['opportunity_id']?.toString() ?? '';
                                  final merchantId =
                                      i['merchant_id']?.toString() ?? '';

                                  return Card(
                                    child: InkWell(
                                      onTap: id.isEmpty
                                          ? null
                                          : () {
                                              Navigator.of(context).push(
                                                MaterialPageRoute(
                                                  builder: (_) =>
                                                      StudentInquiryChatScreenV1(
                                                    inquiryId: id,
                                                  ),
                                                ),
                                              );
                                            },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Statut: $status',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text('Annonce: $opportunityId'),
                                            const SizedBox(height: 6),
                                            Text('Marchand: $merchantId'),
                                            const SizedBox(height: 10),
                                            Text(msg),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
