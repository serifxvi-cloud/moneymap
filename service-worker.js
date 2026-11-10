const CACHE_NAME = 'moneymap-shell-v53';
const APP_SHELL = ['./', './profile.html', './manifest.webmanifest', './manifest-basic.webmanifest', './manifest-premium.webmanifest', './manifest-elite.webmanifest', './icons/icon-basic.svg?v=42', './icons/icon-premium.svg?v=42', './icons/icon-elite.svg?v=42', './favicon.svg?v=42'];
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE_NAME).then(cache => cache.addAll(APP_SHELL)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key)))).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || url.pathname.startsWith('/api/') || event.request.method !== 'GET') return;
  if (event.request.mode === 'navigate') {
    event.respondWith(fetch(event.request).then(response => {
      const copy = response.clone(); caches.open(CACHE_NAME).then(cache => cache.put('./', copy)); return response;
    }).catch(() => caches.match('./')));
    return;
  }
  event.respondWith(caches.match(event.request).then(cached => cached || fetch(event.request).then(response => {
    if (response.ok) { const copy=response.clone(); caches.open(CACHE_NAME).then(cache=>cache.put(event.request,copy)); }
    return response;
  })));
});
