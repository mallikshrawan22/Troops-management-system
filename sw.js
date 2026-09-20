// Patrol Tracker — offline app shell service worker
var CACHE_NAME = 'patrol-tracker-shell-v3';
var SHELL_FILES = [
  './',
  './index.html',
  './site.webmanifest'
];

self.addEventListener('install', function(evt){
  self.skipWaiting();
  evt.waitUntil(
    caches.open(CACHE_NAME).then(function(cache){
      var reqs = SHELL_FILES.map(function(u){ return new Request(u, {cache:'reload'}); });
      return Promise.all(reqs.map(function(r){
        return fetch(r).then(function(res){ if(res && res.ok) return cache.put(r.url, res); }).catch(function(){});
      }));
    })
  );
});

self.addEventListener('activate', function(evt){
  evt.waitUntil(
    caches.keys().then(function(keys){
      return Promise.all(keys.filter(function(k){ return k!==CACHE_NAME; }).map(function(k){ return caches.delete(k); }));
    }).then(function(){ return self.clients.claim(); })
  );
});

// STALE-WHILE-REVALIDATE (was network-first): network-first meant every
// single open of the app waited on a full fresh download of the ~800KB
// shell over whatever connection happened to be available at that moment
// before showing anything — on a patchy link that's a very visible few
// seconds of blank/loading screen on every launch, even when nothing
// actually changed since last time. This still always fetches a fresh
// copy in the background on every load (so an update is never more than
// one extra open away, same as before), but responds immediately with
// whatever's already cached when there is one, instead of making the
// person wait on the network first. This only affects the static shell
// (this file's SHELL_FILES) — every actual data call (troops/duties/etc,
// via apiFetch to API_URL) is a different origin and already skipped
// below, so data freshness is completely unaffected by this change.
self.addEventListener('fetch', function(evt){
  var req = evt.request;
  if(req.method !== 'GET') return;

  var url = new URL(req.url);
  var isShellRequest = url.origin === self.location.origin &&
    (url.pathname.endsWith('/') || url.pathname.endsWith('index.html') || url.pathname.endsWith('site.webmanifest'));

  if(!isShellRequest){
    return;
  }

  evt.respondWith(
    caches.open(CACHE_NAME).then(function(cache){
      return cache.match(req).then(function(cached){
        var networkFetch = fetch(req, {cache:'no-store'}).then(function(res){
          if(res && res.ok) cache.put(req, res.clone());
          return res;
        }).catch(function(){ return cached; });
        // Cached copy available: return it immediately (fast open), and
        // let networkFetch keep updating the cache in the background for
        // next time. No cached copy yet (very first load, or offline
        // with nothing cached): fall back to waiting on the network.
        return cached ? cached : networkFetch;
      });
    })
  );
});
