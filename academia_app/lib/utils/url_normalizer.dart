class UrlNormalizer {
  static const String _proxyHost = 'academia-app-production.up.railway.app';
  static const String _supabaseHost = 'thevdfcwlcqzdoybfvgs.supabase.co';

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

    if (uri.host != _proxyHost) {
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
