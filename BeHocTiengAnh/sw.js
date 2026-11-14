// Cache everything so the app works offline. Bump VERSION when files change.
const VERSION = 'bhta-v1';
const FILES = [
  './', 'index.html', 'manifest.webmanifest',
  'icons/icon-180.png', 'icons/icon-192.png', 'icons/icon-512.png', 'icons/icon-32.png',
  'fonts/baloo2-600-latin-ext.woff2',
  'fonts/baloo2-600-latin.woff2',
  'fonts/baloo2-600-vietnamese.woff2',
  'fonts/baloo2-800-latin-ext.woff2',
  'fonts/baloo2-800-latin.woff2',
  'fonts/baloo2-800-vietnamese.woff2',
  'fonts/nunito-600-latin-ext.woff2',
  'fonts/nunito-600-latin.woff2',
  'fonts/nunito-600-vietnamese.woff2',
  'fonts/nunito-800-latin-ext.woff2',
  'fonts/nunito-800-latin.woff2',
  'fonts/nunito-800-vietnamese.woff2',
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(VERSION).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k => k !== VERSION).map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
// Serve from cache first (fast + offline), refresh the cache in the background.
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(caches.open(VERSION).then(async cache => {
    const hit = await cache.match(e.request, { ignoreSearch: true });
    const net = fetch(e.request).then(res => { if (res.ok) cache.put(e.request, res.clone()); return res; }).catch(() => hit);
    return hit || net;
  }));
});
