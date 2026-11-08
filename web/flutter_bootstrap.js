{{flutter_js}}
{{flutter_build_config}}

// Boot without a service worker: its install raced with engine startup on
// Cloudflare Pages and left first-time visitors on a blank page. Assets are
// still cached by the browser via normal HTTP caching.
_flutter.loader.load();
