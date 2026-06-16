from __future__ import annotations

from pathlib import Path


BASE_DIR = Path(__file__).resolve().parent.parent
FLUTTER_DIR = BASE_DIR / "academia_app"
DIAG_PATH = FLUTTER_DIR / "lib" / "features" / "debug" / "network_diagnostic_screen.dart"
LANDING_PATH = FLUTTER_DIR / "lib" / "features" / "auth" / "auth_landing_screen.dart"


NETWORK_DIAG_CONTENT = '''import 'dart:async';

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
'''


def patch_network_screen() -> None:
  """Create or update the NetworkDiagnosticScreen file."""
  if DIAG_PATH.exists():
    text = DIAG_PATH.read_text(encoding="utf-8")
    if "class NetworkDiagnosticScreen" in text:
      print("NetworkDiagnosticScreen already present, skipping file write")
      return

  DIAG_PATH.parent.mkdir(parents=True, exist_ok=True)
  DIAG_PATH.write_text(NETWORK_DIAG_CONTENT, encoding="utf-8")
  print("Wrote NetworkDiagnosticScreen to", DIAG_PATH)


def patch_auth_landing_screen() -> None:
  """Wire the diagnostic screen into AuthLandingScreen with a long-press on the title."""
  text = LANDING_PATH.read_text(encoding="utf-8")

  if "NetworkDiagnosticScreen" in text:
    print("AuthLandingScreen already references NetworkDiagnosticScreen")
    return

  # 1) Add import
  import_anchor = "import '../../providers/student_offers_provider.dart';\n"
  if "../debug/network_diagnostic_screen.dart" not in text:
    if import_anchor not in text:
      raise SystemExit("StudentOffersProvider import anchor not found in auth_landing_screen.dart")
    replacement = (
      import_anchor
      + "import '../debug/network_diagnostic_screen.dart';\n"
    )
    text = text.replace(import_anchor, replacement)

  # 2) Replace title widget with GestureDetector long-press
  old_title = """        title: const Text('Academia'),\n"""
  new_title = """        title: GestureDetector(\n          onLongPress: () {\n            Navigator.of(context).push(\n              MaterialPageRoute(\n                builder: (_) => const NetworkDiagnosticScreen(),\n              ),\n            );\n          },\n          child: const Text('Academia'),\n        ),\n"""

  if old_title not in text and new_title not in text:
    raise SystemExit("AppBar title anchor not found in auth_landing_screen.dart")

  if new_title not in text:
    text = text.replace(old_title, new_title)

  LANDING_PATH.write_text(text, encoding="utf-8")
  print("Patched AuthLandingScreen with NetworkDiagnosticScreen access")


def main() -> int:
  patch_network_screen()
  patch_auth_landing_screen()
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
