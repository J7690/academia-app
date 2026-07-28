import '../config/backend_hosts.dart';

class UrlNormalizer {
  // Hôte du proxy backend. L'IP n'est plus codée ici : elle vient du point unique
  // `BackendHosts` (lib/config/backend_hosts.dart), surchargeable au build :
  //   --dart-define=VPS_HOST=31.207.38.60
  static String get _backendProxyHost => BackendHosts.backendProxyAuthority;

  // Anciens hôtes proxy encore présents dans des URLs stockées en base.
  // Conservés en "legacy" pour que ces URLs héritées restent normalisées, y
  // compris après un changement d'hébergeur (Railway -> Kamatera -> LWS).
  static Set<String> get _legacyProxyHosts => BackendHosts.legacyProxyHosts;

  static const String _supabaseHost = 'thevdfcwlcqzdoybfvgs.supabase.co';

  static String _authority(Uri uri) =>
      uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

  static bool _isProxyHost(Uri uri) {
    if (_legacyProxyHosts.contains(uri.host)) return true;
    if (_legacyProxyHosts.contains(_authority(uri))) return true;
    if (_backendProxyHost.isEmpty) return false;
    // Match exact sur host (domaine) ou host:port (IP directe), afin de ne
    // pas capturer par erreur d'autres services du même IP (ex. LiveKit :7880).
    return uri.host == _backendProxyHost || _authority(uri) == _backendProxyHost;
  }

  static String normalize(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }

    Uri uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      return trimmed;
    }

    if (!_isProxyHost(uri)) {
      return trimmed;
    }

    var path = uri.path;
    const proxyPrefix = '/supabase';
    if (path.startsWith(proxyPrefix)) {
      path = path.substring(proxyPrefix.length);
      if (path.isEmpty) {
        path = '/';
      }
    }

    final normalized = uri.replace(
      host: _supabaseHost,
      port: null,
      path: path,
    );

    return normalized.toString();
  }
}
