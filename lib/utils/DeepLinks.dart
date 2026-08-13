/// Normalizes inbound URLs (universal links, app links, shared links) into
/// go_router paths the app understands, or `null` when the link doesn't match
/// any known route. Handles full URLs, bare `host/path` strings, custom
/// schemes and query strings/fragments.
class DeepLinks {
  DeepLinks._();

  static const Map<String, String> _staticPaths = {
    '/': '/',
    '/news': '/news',
    '/magazine': '/magazine',
    '/events': '/events',
    '/info': '/info',
    '/settings': '/settings',
    '/login': '/login',
    '/profile': '/profile',
    '/favorites': '/favorites',
    '/user': '/user',
    '/game': '/game',
    '/game/results': '/game/results',
    '/game/edit': '/game/edit',
  };

  static String? normalizeDeepLink(String link) {
    final raw = link.trim();
    if (raw.isEmpty) return null;

    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return null;
    }

    var path = uri.path.isEmpty ? '/' : uri.path;

    // Custom schemes (e.g. scenickazatva://news/123) encode the first path
    // segment in the authority; for http(s) the host is irrelevant.
    final scheme = uri.scheme.toLowerCase();
    if (scheme.isNotEmpty && !scheme.startsWith('http')) {
      final authority = uri.host;
      if (authority.isNotEmpty) {
        path = authority + (uri.path.startsWith('/') ? uri.path : '/${uri.path}');
      }
    }

    // Inputs without a scheme and host, e.g. "javisko.sk/news/123", parse as
    // a relative path. Strip a leading segment that looks like a hostname.
    if (uri.host.isEmpty) {
      final firstSlash = path.indexOf('/');
      final firstSegment =
          firstSlash == -1 ? path : path.substring(0, firstSlash);
      if (firstSegment.contains('.') && firstSegment.isNotEmpty) {
        path = firstSlash == -1 ? '/' : path.substring(firstSlash);
      }
    }

    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (!path.startsWith('/')) path = '/$path';

    if (_staticPaths.containsKey(path)) return _staticPaths[path];

    final segments = path.substring(1).split('/');
    if (segments.length == 2) {
      final id = _validId(segments[1]);
      if (id != null) {
        switch (segments[0]) {
          case 'news':
          case 'magazine':
          case 'events':
          case 'info':
          case 'game':
            return '/${segments[0]}/$id';
        }
      }
    } else if (segments.length == 3) {
      if (segments[0] == 'game' && segments[1] == 'edit') {
        final id = _validId(segments[2]);
        if (id != null) return '/game/edit/$id';
      } else if (segments[2] == 'edit') {
        final id = _validId(segments[1]);
        if (id != null) {
          switch (segments[0]) {
            case 'events':
            case 'info':
              return '/${segments[0]}/$id/edit';
          }
        }
      }
    }

    return null;
  }

  static String? _validId(String raw) {
    final id = Uri.decodeComponent(raw);
    return id.isEmpty ? null : id;
  }
}
