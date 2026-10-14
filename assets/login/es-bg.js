/* =====================================================================
   Fundo do login — paisagens do Espírito Santo (Gestão de Insumos)
   Uso: marque o contêiner da tela de login com o atributo data-es-bg.
   O script monta o fundo sozinho (inclusive quando a tela é recriada)
   e nunca interfere no formulário: é decorativo (aria-hidden) e não
   captura cliques. Sem fotos ou sem JS, fica o fundo laranja original.
   Fotos: Wikimedia Commons (licenças livres, créditos na legenda).
   ===================================================================== */
(function () {
  'use strict';
  if (window.ESBG) return;
  var me = document.currentScript;
  var BASE = me && me.src ? me.src.replace(/[^\/]*$/, '') : '/assets/login/';
  var CENAS = [
    { f: 'convento', pos: '70% 50%', nome: 'Convento da Penha · Baía de Vitória', agua: true,
      autor: 'Elcio Alvares', lic: 'CC BY 2.0', pag: 'Terceira_Ponte_(10038703316).jpg' },
    { f: 'por-do-sol', pos: '50% 45%', nome: 'Pôr do sol em Vitória, visto do Convento', agua: true,
      autor: 'Alessandro Mesquita', lic: 'CC BY-SA 3.0', pag: 'Vitória,_no_Espírito_Santo,_vista_do_Convento_da_Penha.jpg' },
    { f: 'ponte', pos: '58% 50%', nome: 'Terceira Ponte · Vitória e Vila Velha', agua: true,
      autor: 'LucFreitas', lic: 'CC BY-SA 4.0', pag: 'Terceira_Ponte_vista_do_Convento.jpg' },
    { f: 'pedra-azul', pos: '62% 40%', nome: 'Pedra Azul · Domingos Martins', agua: false,
      autor: 'Marcio Malacarne', lic: 'CC BY-SA 4.0', pag: 'Pedra_Azul_-Largato.jpg' },
    { f: 'enseada', pos: '62% 55%', nome: 'Barcos de pesca · Enseada do Suá', agua: true,
      autor: 'Jsilvares', lic: 'CC BY-SA 4.0', pag: 'Enseada_do_suá_vitória_espírito_santo.jpg' }
  ];
  var DUR = 9000;
  var mq = function (q) { try { return window.matchMedia(q).matches; } catch (e) { return false; } };
  var calmo = mq('(prefers-reduced-motion: reduce)');
  var mouse = mq('(hover: hover) and (pointer: fine)');

  var atual = null; // instância montada

  function el(tag, cls) { var e = document.createElement(tag); if (cls) e.className = cls; return e; }

  function montar(host) {
    if (!host || host.querySelector(':scope > .es-bg')) return;
    if (atual) desmontar();
    var bg = el('div', 'es-bg'); bg.setAttribute('aria-hidden', 'true');
    var par = el('div', 'es-par');
    var cenas = CENAS.map(function (c) { var d = el('div', 'es-scene'); d.style.backgroundPosition = c.pos; par.appendChild(d); return { c: c, d: d, ok: false, carregando: false }; });
    var tint = el('div', 'es-tint'), shade = el('div', 'es-shade'), sol = el('div', 'es-sol'), agua = el('div', 'es-agua');
    var b1 = el('div', 'es-bokeh b1'), b2 = el('div', 'es-bokeh b2');
    var cv = el('canvas', 'es-part');
    var leg = el('div', 'es-leg'); leg.removeAttribute('aria-hidden');
    var dots = el('div', 'es-dots'), lt = el('b'), lc = el('small');
    leg.appendChild(dots); leg.appendChild(lt); leg.appendChild(lc);
    [par, tint, agua, sol, shade, b1, b2, cv].forEach(function (x) { bg.appendChild(x); });
    host.insertBefore(bg, host.firstChild);
    host.appendChild(leg);

    var st = { host: host, bg: bg, leg: leg, cenas: cenas, idx: -1, timer: null, raf: 0, vivo: true,
               tx: 0, ty: 0, x: 0, y: 0, cv: cv, ctx: null, parts: [], t0: performance.now() };
    atual = st;

    function carregar(i, cb) {
      var s = cenas[i]; if (s.ok) { cb && cb(true); return; }
      if (s.carregando) return; s.carregando = true;
      var pequena = BASE + s.c.f + '-m.jpg', grande = BASE + s.c.f + '.jpg';
      var img = new Image(); img.decoding = 'async';
      img.onload = function () {
        s.d.style.backgroundImage = 'url("' + pequena + '")'; s.ok = true; cb && cb(true);
        var g = new Image(); g.decoding = 'async';
        g.onload = function () { s.d.style.backgroundImage = 'url("' + grande + '")'; };
        g.src = grande; // a versão grande substitui sem piscar
      };
      img.onerror = function () { s.carregando = false; s.falhou = true; cb && cb(false); };
      img.src = pequena;
    }
    function proxima(de) {
      for (var k = 1; k <= cenas.length; k++) { var j = (de + k) % cenas.length; if (cenas[j].ok) return j; }
      return -1;
    }
    function legenda(i) {
      var c = cenas[i].c;
      dots.innerHTML = cenas.map(function (s, k) { return s.falhou ? '' : '<i' + (k === i ? ' class="on"' : '') + '></i>'; }).join('');
      leg.classList.add('troca');
      setTimeout(function () {
        lt.textContent = c.nome;
        lc.innerHTML = 'Foto: ' + c.autor + ' · ' + c.lic + ' · <a href="https://commons.wikimedia.org/wiki/File:' +
          encodeURIComponent(c.pag).replace(/%2C/g, ',') + '" target="_blank" rel="noopener" tabindex="-1">Wikimedia Commons</a>';
        leg.classList.remove('troca');
      }, st.idx < 0 ? 0 : 450);
    }
    function mostrar(i) {
      if (!st.vivo || i < 0 || i === st.idx) return;
      var ant = st.idx >= 0 ? cenas[st.idx].d : null;
      if (ant) { ant.classList.remove('on'); ant.classList.add('sai'); setTimeout(function () { ant.classList.remove('sai'); }, 2100); }
      var d = cenas[i].d; d.classList.remove('sai'); void d.offsetWidth; d.classList.add('on');
      agua.classList.toggle('on', !!cenas[i].c.agua && !calmo);
      legenda(i); st.idx = i;
      // pré-carrega só a próxima cena (economiza dados no celular)
      carregar((i + 1) % cenas.length);
    }
    function ciclo() {
      clearTimeout(st.timer);
      if (calmo || !st.vivo) return;
      st.timer = setTimeout(function () {
        if (!visivel()) { ciclo(); return; }
        var n = proxima(st.idx);
        if (n >= 0 && n !== st.idx) mostrar(n);
        else { var alvo = (st.idx + 1) % cenas.length; carregar(alvo); }
        ciclo();
      }, DUR);
    }
    function visivel() { return host.isConnected && host.getClientRects().length > 0 && !document.hidden; }

    // primeira cena; se falhar, tenta as seguintes; sem nenhuma, fica o laranja
    (function inicio(i) {
      if (i >= cenas.length) { leg.style.display = 'none'; return; }
      carregar(i, function (ok) { if (!st.vivo) return; if (ok) { mostrar(i); ciclo(); } else inicio(i + 1); });
    })(0);

    // partículas luminosas
    if (!calmo && cv.getContext) {
      st.ctx = cv.getContext('2d');
      var n = window.innerWidth < 700 ? 16 : 34;
      for (var k = 0; k < n; k++) st.parts.push(novaPart(true));
    }
    function novaPart(espalhar) {
      return { x: Math.random(), y: espalhar ? Math.random() : 1.05, r: .6 + Math.random() * 1.8,
               v: .00025 + Math.random() * .0006, f: Math.random() * 6.28, z: .3 + Math.random() * .7, a: .25 + Math.random() * .5 };
    }
    function tamanho() {
      var dpr = Math.min(window.devicePixelRatio || 1, 1.5);
      cv.width = Math.round(bg.clientWidth * dpr); cv.height = Math.round(bg.clientHeight * dpr);
      st.dpr = dpr;
    }
    tamanho();
    function quadro(t) {
      if (!st.vivo) return;
      st.raf = requestAnimationFrame(quadro);
      if (!visivel()) return;
      if (!mouse && !calmo) { // celular: deriva suave automática, sem exigir toque
        var s = (t - st.t0) / 1000; st.tx = Math.sin(s / 7) * .6; st.ty = Math.cos(s / 9) * .4;
      }
      st.x += (st.tx - st.x) * .05; st.y += (st.ty - st.y) * .05;
      if (!calmo) { bg.style.setProperty('--px', st.x.toFixed(4)); bg.style.setProperty('--py', st.y.toFixed(4)); }
      var c = st.ctx; if (!c) return;
      var W = cv.width, H = cv.height, d = st.dpr;
      c.clearRect(0, 0, W, H);
      for (var i = 0; i < st.parts.length; i++) {
        var p = st.parts[i];
        p.y -= p.v * p.z; p.f += .012;
        if (p.y < -.05) st.parts[i] = p = novaPart(false);
        var px = (p.x + Math.sin(p.f) * .008) * W - st.x * 30 * p.z * d;
        var py = p.y * H - st.y * 20 * p.z * d;
        var al = p.a * (.6 + .4 * Math.sin(p.f * 1.7)) * Math.min(1, (1.05 - p.y) * 4);
        var r = p.r * d * (1 + p.z);
        var g = c.createRadialGradient(px, py, 0, px, py, r * 3);
        g.addColorStop(0, 'rgba(255,226,170,' + al + ')'); g.addColorStop(1, 'rgba(255,170,60,0)');
        c.fillStyle = g; c.beginPath(); c.arc(px, py, r * 3, 0, 6.2832); c.fill();
      }
    }
    st.raf = requestAnimationFrame(quadro);

    st.onMove = function (e) {
      var w = window.innerWidth, h = window.innerHeight;
      st.tx = (e.clientX / w - .5) * 2; st.ty = (e.clientY / h - .5) * 2;
    };
    st.onResize = tamanho;
    if (mouse && !calmo) window.addEventListener('pointermove', st.onMove, { passive: true });
    window.addEventListener('resize', st.onResize, { passive: true });
    try { st.placa = criarPlaca(host); } catch (e) { /* sem placa: fica o logotipo */ }
  }


  /* ---------------------------------------------------------------
     Placa de madeira pendurada (substitui o logotipo do login).
     Física de pêndulo com duas correntes paralelas: a placa balança
     num arco e continua nivelada. Arraste para balançar; no computador,
     passar o mouse rápido também empurra. Sem a imagem, fica o logo.
     --------------------------------------------------------------- */
  var ELO = 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="16" height="44" viewBox="0 0 16 44">' +
    '<defs><linearGradient id="f" x1="0" x2="1"><stop offset="0" stop-color="#4A2A12"/><stop offset=".45" stop-color="#A86A35"/><stop offset="1" stop-color="#5A3216"/></linearGradient></defs>' +
    '<rect x="2.2" y="1.5" width="11.6" height="24" rx="5.8" fill="none" stroke="url(#f)" stroke-width="3.2"/>' +
    '<rect x="6.3" y="19" width="3.4" height="27" rx="1.7" fill="url(#f)"/>' +
    '<rect x="6.3" y="-3" width="3.4" height="6" rx="1.7" fill="url(#f)"/></svg>');
  var ANEL = 'data:image/svg+xml;utf8,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 22 22">' +
    '<defs><linearGradient id="g" x1="0" x2="1" y1="0" y2="1"><stop offset="0" stop-color="#B37440"/><stop offset=".5" stop-color="#6B3B18"/><stop offset="1" stop-color="#3E220E"/></linearGradient></defs>' +
    '<circle cx="11" cy="11" r="8" fill="none" stroke="url(#g)" stroke-width="3.6"/></svg>');
  var GANCHO = [0.1356, 0.8756]; // posição das correntes (fração da largura da placa)
  var PROP = 333 / 760;          // altura / largura da imagem

  function criarPlaca(host) {
    var logo = host.querySelector('.login-logo-out');
    if (!logo) return null;
    var img = new Image(); img.decoding = 'async';
    img.alt = 'Ilha do Caranguejo · Grupo Ilha';
    var P = { vivo: true, th: 0, w: 0, drag: null, raf: 0, ult: 0, vento: 0 };
    img.onload = function () { if (P.vivo) montarPlaca(); };
    img.onerror = function () { P.vivo = false; }; // fica o logotipo original
    img.src = BASE + 'placa.webp';

    function montarPlaca() {
      var slot = el('div', 'es-placa-slot');
      logo.parentNode.insertBefore(slot, logo);
      host.classList.add('es-com-placa');
      var raiz = el('div', 'es-placa');
      var c1 = el('div', 'es-corrente'), c2 = el('div', 'es-corrente');
      c1.style.backgroundImage = c2.style.backgroundImage = 'url("' + ELO + '")';
      var tab = el('div', 'es-tabua'); tab.setAttribute('role', 'img'); tab.setAttribute('aria-label', img.alt);
      tab.title = 'Arraste para balançar';
      var a1 = el('i', 'es-anel'), a2 = el('i', 'es-anel');
      a1.style.backgroundImage = a2.style.backgroundImage = 'url("' + ANEL + '")';
      img.className = 'es-tabua-img'; img.draggable = false;
      tab.appendChild(a1); tab.appendChild(a2); tab.appendChild(img);
      raiz.appendChild(c1); raiz.appendChild(c2); raiz.appendChild(tab);
      host.appendChild(raiz);
      P.slot = slot; P.raiz = raiz; P.c = [c1, c2]; P.tab = tab; P.a = [a1, a2];

      function medir() {
        var hr = host.getBoundingClientRect(), sr = slot.getBoundingClientRect();
        P.w = sr.width; P.h = P.w * PROP;
        P.x0 = sr.left - hr.left; P.L = Math.max(24, sr.top - hr.top);
        tab.style.width = P.w + 'px'; tab.style.height = P.h + 'px';
        GANCHO.forEach(function (g, k) {
          P.a[k].style.left = (g * P.w - 11) + 'px';
          P.c[k].style.left = (P.x0 + g * P.w - 8) + 'px';
          P.c[k].style.height = (P.L + 4) + 'px';
        });
        desenhar();
      }
      P.medir = medir;
      medir();
      if (window.ResizeObserver) { P.ro = new ResizeObserver(medir); P.ro.observe(host); P.ro.observe(slot); }
      window.addEventListener('resize', medir, { passive: true });

      // ---- interação: arrastar (mouse e toque) ----
      tab.addEventListener('pointerdown', function (e) {
        e.preventDefault();
        try { tab.setPointerCapture(e.pointerId); } catch (x) {}
        P.drag = { id: e.pointerId, x: e.clientX, dx0: P.L * Math.sin(P.th), t: performance.now(), th: P.th };
        P.om = 0; raiz.classList.add('pega');
      });
      tab.addEventListener('pointermove', function (e) {
        if (P.drag && e.pointerId === P.drag.id) {
          var dx = P.drag.dx0 + (e.clientX - P.drag.x);
          var lim = P.L * 0.82;
          dx = Math.max(-lim, Math.min(lim, dx));
          var novo = Math.asin(dx / P.L), t = performance.now(), dt = Math.max(8, t - P.drag.t) / 1000;
          P.om = (novo - P.drag.th) / dt * 0.6 + P.om * 0.4;
          P.th = novo; P.drag.th = novo; P.drag.t = t;
        } else if (!P.drag && mouse && e.movementX) {
          // empurrão ao passar o mouse
          P.om += Math.max(-.6, Math.min(.6, e.movementX * 0.012)) * (40 / Math.max(40, P.L));
        }
      });
      function soltar(e) { if (P.drag && (!e || e.pointerId === P.drag.id)) { P.drag = null; raiz.classList.remove('pega'); } }
      tab.addEventListener('pointerup', soltar); tab.addEventListener('pointercancel', soltar);
      tab.addEventListener('lostpointercapture', function () { soltar(); });

      P.ult = performance.now();
      P.raf = requestAnimationFrame(passo);
      // um pequeno balanço de chegada
      if (!calmo) P.om = 0.9 * (40 / Math.max(40, P.L));
    }

    function desenhar() {
      if (!P.raiz) return;
      var th = P.th, L = P.L;
      var dx = L * Math.sin(th), dy = L * (1 - Math.cos(th));
      var tilt = -(P.om || 0) * 0.9; // inclinação leve conforme a velocidade (graus)
      P.tab.style.transform = 'translate3d(' + (P.x0 + dx).toFixed(2) + 'px,' + (L - dy).toFixed(2) + 'px,0) rotate(' + tilt.toFixed(2) + 'deg)';
      var g = (-th * 180 / Math.PI).toFixed(3);
      P.c[0].style.transform = P.c[1].style.transform = 'rotate(' + g + 'deg)';
    }

    function passo(t) {
      if (!P.vivo) return;
      P.raf = requestAnimationFrame(passo);
      var dt = Math.min(0.033, (t - P.ult) / 1000); P.ult = t;
      if (!host.isConnected || !host.getClientRects().length || document.hidden) return;
      if (!P.drag) {
        // pêndulo amortecido: período ~1,7 s, independe do tamanho da corrente
        var k = 13.5, c = 0.75;
        if (!calmo) { // brisa: empurrões raros e suaves quando parada
          P.vento -= dt;
          if (P.vento <= 0) { P.vento = 5 + Math.random() * 6; if (Math.abs(P.om) < .05) P.om += (Math.random() - .5) * .35 * (40 / Math.max(40, P.L)); }
        }
        P.om += (-k * Math.sin(P.th) - c * P.om) * dt;
        P.th += P.om * dt;
        if (Math.abs(P.th) > 1.0) { P.th = Math.sign(P.th) * 1.0; P.om *= -0.4; }
      } else {
        P.om *= 0.9;
      }
      desenhar();
    }

    return {
      destruir: function () {
        P.vivo = false; cancelAnimationFrame(P.raf);
        if (P.ro) P.ro.disconnect();
        window.removeEventListener('resize', P.medir);
        if (P.raiz && P.raiz.isConnected) P.raiz.remove();
        if (P.slot && P.slot.isConnected) P.slot.remove();
        host.classList.remove('es-com-placa');
      }
    };
  }

  function desmontar() {
    var st = atual; if (!st) return;
    st.vivo = false; clearTimeout(st.timer); cancelAnimationFrame(st.raf);
    window.removeEventListener('pointermove', st.onMove); window.removeEventListener('resize', st.onResize);
    if (st.placa) st.placa.destruir();
    if (st.bg.isConnected) st.bg.remove(); if (st.leg.isConnected) st.leg.remove();
    atual = null;
  }

  function varrer() {
    if (atual && !atual.host.isConnected) desmontar();
    var h = document.querySelector('[data-es-bg]');
    if (h && (!atual || atual.host !== h)) { try { montar(h); } catch (e) { /* fundo é opcional */ } }
  }

  window.ESBG = { montar: montar, desmontar: desmontar, varrer: varrer };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', varrer); else varrer();
  // a tela de login do portal é recriada a cada saída; observa e monta de novo
  var pend = false;
  try { new MutationObserver(function () { if (pend) return; pend = true; requestAnimationFrame(function () { pend = false; varrer(); }); }).observe(document.body || document.documentElement, { childList: true, subtree: true }); } catch (e) {}
})();
