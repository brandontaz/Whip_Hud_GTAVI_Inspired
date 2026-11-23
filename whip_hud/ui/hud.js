// The page's router: the Lua side sends { action, payload } (client/state.lua: Hud.set); each part draws itself with
// D11Hud.on(action, fn). D11Hud.T(text) translates (locales.js), D11Hud.lang is 'en' or 'pt-BR'.
(() => {
    const state = {};
    const listeners = {};
    const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'whip_hud';
    const api = { on, post, state, lang: 'en', T: text => text, hold: null, apply: (action, payload) => rawApply(action, payload) };

    function on(action, fn) {
        (listeners[action] ||= []).push(fn);
        if (action in state) fn(state[action], state);
    }

    function rawApply(action, payload) {
        state[action] = payload;
        (listeners[action] || []).forEach(fn => fn(payload, state));
    }
    // api.hold = { keys: Set, values: {} } while the /hud editor shows sample data: updates for those keys wait in
    // hold.values until the editor closes (ui/editor.js). api.apply skips the hold, for the editor's own samples.
    function apply(action, payload) {
        if (api.hold && api.hold.keys.has(action)) { api.hold.values[action] = payload; return; }
        rawApply(action, payload);
    }

    function post(name, data = {}) {
        return fetch(`https://${resource}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data),
        }).catch(() => {});
    }

    function setLocale(lang) {
        if (lang === api.lang) return;
        const map = (window.D11Locales || {})[lang];
        api.lang = map || lang === 'pt-BR' ? lang : 'en';
        api.T = map ? text => map[text] ?? text : text => text;
        document.documentElement.lang = api.lang;
        // everything already drawn, drawn again in the new language
        Object.entries(state).forEach(([key, value]) => { if (key !== 'locale') apply(key, value); });
    }

    // pt-BR is the source text; English until the Lua side says otherwise
    api.lang = '';
    setLocale('en');

    on('locale', setLocale);
    on('visible', visible => document.documentElement.classList.toggle('hud-hidden', visible === false));
    on('active', active => document.documentElement.classList.toggle('inactive', active !== true));
    on('inventoryOpen', open => document.documentElement.classList.toggle('inventory-open', open === true));
    on('dynamic', on => document.documentElement.classList.toggle('static-hud', on === false));
    on('logo', show => { document.getElementById('brand').hidden = show !== true; });
    on('showStatus', show => { document.getElementById('status').hidden = show === false; });

    window.addEventListener('message', ({ data }) => {
        if (!data || typeof data.action !== 'string') return;
        if (data.action === 'snapshot') {
            const payload = data.payload || {};
            if ('locale' in payload) apply('locale', payload.locale);
            Object.entries(payload).forEach(([key, value]) => apply(key, value));
            return;
        }
        apply(data.action, data.payload);
    });

    window.D11Hud = api;
    post('ready');
})();
