import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../config/supabase_config.dart';

class NetworkDiagnosticScreen extends StatefulWidget {
  const NetworkDiagnosticScreen({super.key});

  @override
  State<NetworkDiagnosticScreen> createState() => _NetworkDiagnosticScreenState();
}

class _NetworkTestResult {
  final String name;
  final String url;
  final bool success;
  final int? statusCode;
  final String message;

  const _NetworkTestResult({
    required this.name,
    required this.url,
    required this.success,
    required this.statusCode,
    required this.message,
  });
}

class _NetworkDiagnosticScreenState extends State<NetworkDiagnosticScreen> {
  bool _running = false;
  final List<_NetworkTestResult> _results = <_NetworkTestResult>[];

  @override
  void initState() {
    super.initState();
    unawaited(_runTests());
  }

  Future<void> _runTests() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    await _runOne(
      name: 'Proxy Supabase auth health',
      url: '${SupabaseConfig.url}/auth/v1/health',
    );

    await _runOne(
      name: 'Google',
      url: 'https://www.google.com',
    );

    setState(() {
      _running = false;
    });
  }

  Future<void> _runOne({required String name, required String url}) async {
    final DateTime startedAt = DateTime.now();
    try {
      final Uri uri = Uri.parse(url);
      final http.Response response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));
      final int durationMs = DateTime.now().difference(startedAt).inMilliseconds;
      final String body = response.body;

      setState(() {
        _results.add(
          _NetworkTestResult(
            name: name,
            url: url,
            success: true,
            statusCode: response.statusCode,
            message: 'HTTP ${response.statusCode} in ${durationMs}ms; body=${_shorten(body)}',
          ),
        );
      });
    } on TimeoutException catch (e) {
      setState(() {
        _results.add(
          _NetworkTestResult(
            name: name,
            url: url,
            success: false,
            statusCode: null,
            message: 'Timeout: ${e.message ?? ''}',
          ),
        );
      });
    } catch (e) {
      setState(() {
        _results.add(
          _NetworkTestResult(
            name: name,
            url: url,
            success: false,
            statusCode: null,
            message: e.toString(),
          ),
        );
      });
    }
  }

  static String _shorten(String body) {
    const int max = 160;
    if (body.length <= max) {
      return body;
    }
    return body.substring(0, max) + '...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic réseau'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Supabase URL: ${SupabaseConfig.url}',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _running ? null : _runTests,
              child: Text(_running ? 'Tests en cours...' : 'Relancer les tests'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                itemCount: _results.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int index) {
                  final _NetworkTestResult r = _results[index];
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color:
                          r.success ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          r.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          r.url,
                          style: const TextStyle(fontSize: 12, color: Colors.black87),
                        ),
                        if (r.statusCode != null) ...<Widget>[
                          const SizedBox(height: 4),
                          Text(
                            'Status: ${r.statusCode}',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          r.message,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
