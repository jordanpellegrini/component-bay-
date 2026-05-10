// Components Bay Service Worker
const CACHE_NAME = 'components-bay-v1';

self.addEventListener('install', e => {
    self.skipWaiting();
});

self.addEventListener('activate', e => {
    e.waitUntil(clients.claim());
});

// Network first strategy - always get fresh data from Supabase
self.addEventListener('fetch', e => {
    // Don't cache Supabase API calls
    if (e.request.url.includes('supabase.co') || e.request.url.includes('api/claude')) {
        return;
    }
    e.respondWith(fetch(e.request).catch(() => caches.match(e.request)));
});
