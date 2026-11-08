// Shown until Flutter paints its first frame.
(function () {
  // The first web build shipped a Flutter service worker whose install
  // raced with engine startup and left the page blank. The build no
  // longer registers one; this cleanup evicts stale workers and caches
  // left behind by that release.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.getRegistrations().then(function (regs) {
      regs.forEach(function (reg) { reg.unregister(); });
    });
    if (window.caches && caches.keys) {
      caches.keys().then(function (keys) {
        keys.forEach(function (key) { caches.delete(key); });
      });
    }
  }
  window.addEventListener('flutter-first-frame', function () {
    var splash = document.getElementById('splash');
    if (splash) splash.remove();
  });
})();
