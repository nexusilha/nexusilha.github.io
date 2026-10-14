/* Service worker — Gestão de Insumos (Grupo Ilha)
   - Páginas: rede primeiro (sempre a versão mais nova); sem internet, usa a última cópia ou a tela "sem conexão".
   - Arquivos estáticos e bibliotecas de CDN: cache com atualização em segundo plano.
   - Nunca guarda chamadas ao Supabase (dados e login sempre ao vivo). */
const VERSAO = 'gi-v1';
const ESSENCIAIS = ['/offline.html', '/manifest.webmanifest', '/icon-192.png', '/icon-512.png', '/apple-touch-icon.png'];
const CDN = ['cdn.jsdelivr.net', 'cdnjs.cloudflare.com', 'fonts.googleapis.com', 'fonts.gstatic.com'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(VERSAO).then((c) => c.addAll(ESSENCIAIS)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then((ks) => Promise.all(ks.filter((k) => k !== VERSAO).map((k) => caches.delete(k))))
    .then(() => self.clients.claim()));
});

function guardar(req, res) {
  if (res && (res.ok || res.type === 'opaque')) { const cp = res.clone(); caches.open(VERSAO).then((c) => c.put(req, cp)); }
  return res;
}

self.addEventListener('fetch', (e) => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);
  if (url.hostname.endsWith('supabase.co')) return; // dados sempre da rede

  // navegação (abrir/recarregar páginas): rede primeiro
  if (req.mode === 'navigate') {
    e.respondWith(fetch(req).then((r) => guardar(req, r))
      .catch(() => caches.match(req, { ignoreSearch: true }).then((r) => r || caches.match('/offline.html'))));
    return;
  }
  const mesmo = url.origin === self.location.origin;
  if (mesmo || CDN.includes(url.hostname)) {
    e.respondWith(caches.match(req).then((cache) => {
      const rede = fetch(req).then((r) => guardar(req, r)).catch(() => cache || Response.error());
      return cache || rede;
    }));
  }
});
