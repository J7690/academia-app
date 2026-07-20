class UrlNormalizer {
  // Backend proxy host. Railway a été retiré du dispositif : la production
  // bascule sur Kamatera Cloud. Configurable au build sans toucher au code :
  //   --dart-define=BACKEND_PROXY_HOST=api.academiea.com
  //   --dart-define=BACKEND_PROXY_HOST=185.167.97.144:8001
  // Défaut = VPS Kamatera actif (LiveKit/Nginx), backend expose sur :8001.
  static const String _backendProxyHost = String.fromEnvironment(
    'BACKEND_PROXY_HOST',
    defaultValue: '185.167.97.144:8001',
  );

  // Anciens hôtes proxy encore présents dans des URLs stockées en base.
  // Conservés en "legacy" pour que ces URLs héritées restent normalisées.
  static const Set<String> _legacyProxyHosts = {
    'academia-app-production.up.railway.app',
  };

  static const String _supabaseHost = 'thevdfcwlcqzdoybfvgs.supabase.co';

  static String _authority(Uri uri) =>
      uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;

  static bool _isProxyHost(Uri uri) {
    if (_legacyProxyHosts.contains(uri.host)) return true;
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
