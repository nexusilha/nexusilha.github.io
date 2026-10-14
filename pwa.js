/* Gestão de Insumos — instalação como aplicativo (PWA).
   Registra o service worker e, no portal, mostra o botão "Instalar app"
   (Chrome/Edge no PC e Android) ou as instruções do iPhone/iPad (Safari). */
(function () {
  'use strict';
  if (!('serviceWorker' in navigator) && !/iphone|ipad|ipod/i.test(navigator.userAgent)) return;

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', function () {
      navigator.serviceWorker.register('/sw.js', { scope: '/' }).catch(function () { /* sem SW o sistema funciona normalmente */ });
    });
  }

  var instalado = (window.matchMedia && matchMedia('(display-mode: standalone)').matches) || navigator.standalone === true;
  var noPortal = location.pathname === '/' || location.pathname === '/index.html';
  if (instalado || !noPortal) return;

  var ua = navigator.userAgent;
  var ios = /iphone|ipad|ipod/i.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
  var safari = /safari/i.test(ua) && !/crios|fxios|edgios|chrome|android/i.test(ua);
  var CHAVE = 'gi.instalar.dispensado';
  function dispensado() { try { var t = +localStorage.getItem(CHAVE); return t && Date.now() - t < 7 * 864e5; } catch (e) { return false; } }
  function dispensar() { try { localStorage.setItem(CHAVE, String(Date.now())); } catch (e) {} }

  var css = document.createElement('style');
  css.textContent =
    '.gi-inst{position:fixed;top:calc(12px + env(safe-area-inset-top,0px));right:12px;z-index:9999;display:flex;align-items:center;gap:2px;' +
    'background:#fff;border-radius:999px;box-shadow:0 8px 24px rgba(60,20,0,.28);padding:3px;font:600 13.5px Inter,system-ui,sans-serif}' +
    '.gi-inst button{border:0;background:#E55C0E;color:#fff;font:inherit;padding:8px 14px;border-radius:999px;cursor:pointer;display:flex;align-items:center;gap:7px}' +
    '.gi-inst button:hover{background:#C84B07}.gi-inst .x{background:none;color:#8A7766;padding:8px 10px}.gi-inst .x:hover{background:#FFF3E3;color:#2A1A0E}' +
    '.gi-inst svg{width:16px;height:16px}' +
    '.gi-ios{position:fixed;inset:0;z-index:10000;background:rgba(30,10,0,.5);display:flex;align-items:flex-end;justify-content:center;padding:16px}' +
    '.gi-ios .c{background:#fff;border-radius:16px;max-width:420px;width:100%;padding:22px 22px 18px;font:15px/1.5 Inter,system-ui,sans-serif;color:#2A1A0E;box-shadow:0 20px 50px rgba(0,0,0,.35)}' +
    '.gi-ios h3{margin:0 0 10px;font-size:18px}.gi-ios ol{margin:0 0 16px;padding-left:20px}.gi-ios li{margin:6px 0}' +
    '.gi-ios b{color:#C84B07}.gi-ios button{width:100%;border:0;background:#E55C0E;color:#fff;font:600 15px inherit;padding:12px;border-radius:10px;cursor:pointer}';
  var ICONE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v12M7 10l5 5 5-5M5 21h14"/></svg>';

  function botao(acao) {
    if (dispensado() || document.querySelector('.gi-inst')) return;
    if (!css.isConnected) document.head.appendChild(css);
    var w = document.createElement('div'); w.className = 'gi-inst';
    w.innerHTML = '<button type="button" class="ok">' + ICONE + 'Instalar app</button><button type="button" class="x" aria-label="Agora não" title="Agora não">✕</button>';
    w.querySelector('.ok').onclick = function () { acao(w); };
    w.querySelector('.x').onclick = function () { dispensar(); w.remove(); };
    document.body.appendChild(w);
  }

  // Chrome, Edge (PC e Android)
  var pedido = null;
  window.addEventListener('beforeinstallprompt', function (e) {
    e.preventDefault(); pedido = e;
    botao(function (w) {
      if (!pedido) return;
      pedido.prompt();
      pedido.userChoice.then(function () { pedido = null; w.remove(); });
    });
  });
  window.addEventListener('appinstalled', function () { var w = document.querySelector('.gi-inst'); if (w) w.remove(); });

  // iPhone / iPad (Safari não tem botão automático)
  if (ios) {
    var abrir = function () {
      botao(function () {
        if (!css.isConnected) document.head.appendChild(css);
        var m = document.createElement('div'); m.className = 'gi-ios';
        m.innerHTML = '<div class="c" role="dialog" aria-label="Instalar no iPhone"><h3>Instalar no iPhone ou iPad</h3>' +
          (safari ? '' : '<p style="margin:0 0 10px">Abra este endereço no <b>Safari</b> para instalar.</p>') +
          '<ol><li>Toque em <b>Compartilhar</b> (o quadrado com a seta para cima).</li>' +
          '<li>Escolha <b>Adicionar à Tela de Início</b>.</li><li>Toque em <b>Adicionar</b>.</li></ol>' +
          '<button type="button">Entendi</button></div>';
        m.onclick = function (ev) { if (ev.target === m || ev.target.tagName === 'BUTTON') m.remove(); };
        document.body.appendChild(m);
      });
    };
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', abrir); else abrir();
  }
})();
