// Concert Tracker — Service Worker
// Stale-while-revalidate: serve cache instantly, refresh in background.
// Bump CACHE version to force a full re-download on all devices.
const CACHE = 'concert-tracker-v1';

const REQUIRED = [
  './',
  './index.html',
  './styles.css',
  './app.js',
  './config.js',
  './data.js',
  './tour-data.js',
  './icon.svg',
];

const OPTIONAL = [
  './icon-192.png',
  './icon-512.png',
  './images/artists/motley-crue.jpg',
  './images/artists/def-leppard.jpg',
  './images/artists/sammy-hagar.jpg',
  './images/artists/van-halen-banner.jpg',
  './images/artists/poison.jpg',
  './images/artists/dave-matthews-band.jpg',
  './images/artists/counting-crows.jpg',
  './images/artists/pete-yorn.jpg',
  './images/artists/better-than-ezra.jpg',
  './images/artists/big-head-todd.jpg',
  './images/artists/jimmy-buffett.jpg',
  './images/artists/bodeans.jpg',
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE).then(cache =>
      cache.addAll(REQUIRED).then(() =>
        Promise.allSettled(OPTIONAL.map(url => cache.add(url)))
      )
    )
  );
  self.skipWaiting();
});

self.addEventListener('activate', event => {
  event.waitUntil(
    caches.keys().then(keys =>
      Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
    )
  );
  self.clients.claim();
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;
  event.respondWith(handleFetch(event.request));
});

async function handleFetch(request) {
  const cache = await caches.open(CACHE);
  const cached = await cache.match(request);

  // Always attempt a network refresh in the background
  const networkPromise = fetch(request).then(response => {
    if (response.ok) cache.put(request, response.clone());
    return response;
  }).catch(() => null);

  // Serve cache immediately if available; otherwise wait for network
  if (cached) {
    networkPromise; // fire-and-forget background refresh
    return cached;
  }

  const fresh = await networkPromise;
  if (fresh) return fresh;

  return new Response('Offline — open the app while connected to load the latest data.', {
    status: 503,
    headers: { 'Content-Type': 'text/plain' },
  });
}
