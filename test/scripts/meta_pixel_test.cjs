'use strict';
// Pixel Meta (2026-11-26) : rien ne part sans identifiant ni sans accord.
// Lancer : node --test test/scripts/meta_pixel_test.cjs
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const test = require('node:test');

const file = path.resolve(__dirname, '../../web/meta_pixel.js');
const source = fs.readFileSync(file, 'utf8');
const withId = source.replace("var PIXEL_ID = '';", "var PIXEL_ID = '123456789012345';");

function element(tag) {
  return {
    tag, children: [], style: {}, attrs: {}, listeners: {}, parentNode: null,
    setAttribute(k, v) { this.attrs[k] = v; },
    appendChild(c) { c.parentNode = this; this.children.push(c); return c; },
    removeChild(c) { this.children = this.children.filter((x) => x !== c); c.parentNode = null; },
    insertBefore(c) { c.parentNode = this; this.children.push(c); return c; },
    addEventListener(name, fn) { this.listeners[name] = fn; },
  };
}

function page(code, { pathname = '/fr', consent = null } = {}) {
  const store = new Map(consent ? [['movik_ads_consent', consent]] : []);
  const body = element('body');
  const head = element('head');
  const firstScript = element('script');
  head.appendChild(firstScript);
  const find = (node, id) => node.id === id ? node
    : node.children.map((c) => find(c, id)).find(Boolean) || null;
  const document = {
    body,
    createElement: element,
    createTextNode: (text) => ({ text, children: [] }),
    getElementById: (id) => find(body, id),
    getElementsByTagName: () => [firstScript],
    addEventListener() {},
  };
  const window = {
    location: { pathname },
    localStorage: {
      getItem: (k) => (store.has(k) ? store.get(k) : null),
      setItem: (k, v) => store.set(k, v),
      removeItem: (k) => store.delete(k),
    },
  };
  vm.runInNewContext(code, { window, document });
  // JSON : les objets viennent d’un autre contexte (vm).
  const calls = () => JSON.parse(JSON.stringify(window.fbq ? window.fbq.queue.map((a) => Array.from(a)) : []));
  const scripts = () => head.children.filter((c) => c.src);
  const banner = () => document.getElementById('movik-ads-consent');
  const click = (index) => banner().children[1].children[index].listeners.click();
  return { window, store, calls, scripts, banner, refuse: () => click(0), accept: () => click(1) };
}

test('the committed file has no stray identifier format', () => {
  const m = /var PIXEL_ID = '([^']*)';/.exec(source);
  assert.ok(m, 'PIXEL_ID line present');
  assert.match(m[1], /^(\d{15,16})?$/);
});

test('without an identifier: no banner, no Meta script, track is a no-op', () => {
  const p = page(source.replace(/var PIXEL_ID = '[^']*';/, "var PIXEL_ID = '';"));
  assert.equal(p.window.movikMeta.enabled, false);
  p.window.movikMeta.track('Lead');
  p.window.movikMeta.consent('granted');
  assert.equal(p.banner(), null);
  assert.equal(p.scripts().length, 0);
  assert.equal(p.window.fbq, undefined);
});

test('first visit: banner shown, nothing loaded, events wait', () => {
  const p = page(withId, { pathname: '/fr/livraison/demande' });
  assert.ok(p.banner());
  p.window.movikMeta.track('InitiateCheckout');
  assert.equal(p.scripts().length, 0);
  assert.equal(p.window.fbq, undefined);
});

test('accept: pixel loads, page view then the waiting events', () => {
  const p = page(withId, { pathname: '/fr/livraison/demande' });
  p.window.movikMeta.track('Lead', { currency: 'CAD', value: 59 });
  p.accept();
  assert.equal(p.store.get('movik_ads_consent'), 'granted');
  assert.equal(p.banner(), null);
  assert.equal(p.scripts().length, 1);
  assert.equal(p.scripts()[0].src, 'https://connect.facebook.net/en_US/fbevents.js');
  assert.deepEqual(p.calls(), [
    ['init', '123456789012345'],
    ['track', 'PageView'],
    ['track', 'Lead', { currency: 'CAD', value: 59 }],
  ]);
});

test('refuse: remembered, nothing ever loads', () => {
  const p = page(withId);
  p.window.movikMeta.track('Lead');
  p.refuse();
  p.window.movikMeta.track('Purchase', { value: 59, currency: 'CAD' });
  assert.equal(p.store.get('movik_ads_consent'), 'denied');
  assert.equal(p.banner(), null);
  assert.equal(p.scripts().length, 0);
  const again = page(withId, { consent: 'denied' });
  assert.equal(again.banner(), null);
  assert.equal(again.scripts().length, 0);
});

test('returning visitor who accepted: no banner, events go out with their id', () => {
  const p = page(withId, { consent: 'granted' });
  assert.equal(p.banner(), null);
  p.window.movikMeta.track('Purchase', { value: 59, currency: 'CAD' }, 'booking_abc');
  p.window.movikMeta.track('EstimateShown');
  assert.deepEqual(p.calls().slice(2), [
    ['track', 'Purchase', { value: 59, currency: 'CAD' }, { eventID: 'booking_abc' }],
    ['trackCustom', 'EstimateShown', {}],
  ]);
});

test('staff and driver pages are never measured', () => {
  for (const pathname of ['/fr/admin', '/fr/admin/centre-commande', '/en/provider/dashboard', '/fr/tableau-de-bord']) {
    const p = page(withId, { pathname, consent: 'granted' });
    p.window.movikMeta.track('Lead');
    assert.equal(p.scripts().length, 0, pathname);
    assert.equal(p.banner(), null, pathname);
  }
});

test('banner speaks the language of the address', () => {
  assert.match(page(withId, { pathname: '/en/pricing' }).banner().children[0].children[0].text, /advertising cookie/);
  assert.match(page(withId, { pathname: '/es/precios' }).banner().children[0].children[0].text, /cookie publicitaria/);
});
