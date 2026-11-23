// The /hud editor: drag each part of the HUD where you want it, resize it, and choose whether the status bars stay on
// screen. client/menu.lua opens it ('editor' action) and keeps the saved layout ('layout', 'pinStatus'); this draws it.
// While it is open, the parts that are only on screen in some situations (compass, GPS card, ammo, passenger seatbelt)
// are fed sample data and the real updates are held, then replayed when it closes.
(() => {
    const D = window.D11Hud;
    const doc = document.documentElement;
    const T = text => D.T(text);

    const PARTS = [
        { id: 'status', sel: '#status', label: 'Status' },
        { id: 'radar', sel: '#radar', label: 'Bússola' },
        { id: 'route', sel: '#route', label: 'Cartão GPS' },
        { id: 'gauge', sel: '#gauge', label: 'Velocímetro' },
        { id: 'ammo', sel: '#ammo', label: 'Munição' },
        { id: 'hints', sel: '#hints', label: 'Dicas de teclas' },
        { id: 'belt', sel: '#passenger-seatbelt', label: 'Cinto do passageiro' },
    ];
    const SAMPLE = {
        radar: true,
        heading: 48,
        location: { street: 'Ocean Drive', area: 'Ocean Beach' },
        route: { maneuver: 'right', meters: 240, ahead: 3800 },
        ammo: { visible: true, clip: 14, max: 17, spare: 3, showAmmo: true, visualKey: 'editor', layers: ['weapons/weapon_pistol/base.png'] },
        passengerBelt: { visible: true, buckled: false },
    };
    const OFF = { radar: false, heading: 0, location: { street: '', area: '' }, route: null, ammo: { visible: false }, passengerBelt: { visible: false } };
    const STEP = .3;                 // vh per arrow key press
    const MIN_S = .5, MAX_S = 1.6;

    let isOpen = false, selected = 'status', work = {}, workPin = false, savedLayout = {}, savedPin = false, real = {};

    const panel = document.createElement('div');
    panel.id = 'editor';
    panel.hidden = true;
    document.body.appendChild(panel);

    const part = id => PARTS.find(p => p.id === id);
    const node = id => document.querySelector(part(id).sel);
    const entry = id => (work[id] ||= { x: 0, y: 0, s: 1 });
    const round = v => Math.round(v * 1000) / 1000;

    function normalize(layout) {
        const out = {};
        if (!layout || typeof layout !== 'object' || Array.isArray(layout)) return out;   // Lua sends an empty table as []
        for (const p of PARTS) {
            const v = layout[p.id];
            if (!v || typeof v !== 'object') continue;
            out[p.id] = { x: round(+v.x || 0), y: round(+v.y || 0), s: Math.min(MAX_S, Math.max(MIN_S, +v.s || 1)) };
        }
        return out;
    }
    function setVars(id, v) {
        const n = node(id);
        if (!n) return;
        n.style.setProperty('--dx', String(round(v.x)));
        n.style.setProperty('--dy', String(round(v.y)));
        n.style.setProperty('--s', String(v.s));
    }
    function applyLayout(layout) {
        const l = normalize(layout);
        PARTS.forEach(p => setVars(p.id, l[p.id] || { x: 0, y: 0, s: 1 }));
    }
    // only what differs from the default is saved
    const compact = () => {
        const out = {};
        for (const p of PARTS) {
            const v = work[p.id];
            if (v && (Math.abs(v.x) > .001 || Math.abs(v.y) > .001 || Math.abs(v.s - 1) > .001)) out[p.id] = { x: round(v.x), y: round(v.y), s: v.s };
        }
        return out;
    };

    // keeps a part on the screen: shifts it back if its box leaves the window
    function keepOnScreen(id) {
        const n = node(id), v = entry(id);
        if (!n) return;
        const r = n.getBoundingClientRect();
        if (!r.width || !r.height) return;
        const vh = window.innerHeight / 100;
        let sx = 0, sy = 0;
        if (r.left < 0) sx = -r.left; else if (r.right > window.innerWidth) sx = window.innerWidth - r.right;
        if (r.top < 0) sy = -r.top; else if (r.bottom > window.innerHeight) sy = window.innerHeight - r.bottom;
        if (sx || sy) { v.x += sx / vh; v.y += sy / vh; setVars(id, v); }
    }

    function markSelected() {
        PARTS.forEach(p => { const n = node(p.id); if (n) n.classList.toggle('sel', isOpen && p.id === selected); });
    }
    function select(id) {
        selected = id;
        markSelected();
        render();
    }

    function render() {
        const cur = entry(selected);
        const pct = Math.round(cur.s * 100);
        panel.innerHTML = `
            <h2 class="ed-title">${T('Editar HUD')}</h2>
            <p>${T('Arraste cada parte para onde quiser. As setas do teclado movem a parte escolhida (Shift = mais rápido).')}</p>
            <div class="ed-parts">${PARTS.map(p => `<button type="button" data-part="${p.id}"${p.id === selected ? ' class="on"' : ''}>${T(p.label)}</button>`).join('')}</div>
            <div class="ed-size">
                <label for="ed-scale">${T('Tamanho')}</label>
                <input id="ed-scale" type="range" min="${MIN_S * 100}" max="${MAX_S * 100}" step="5" value="${pct}">
                <output>${pct}%</output>
                <button type="button" data-act="reset-one">${T('Restaurar esta parte')}</button>
            </div>
            <label class="ed-pin"><input id="ed-pin" type="checkbox"${workPin ? ' checked' : ''}>
                <span><b>${T('Manter status sempre na tela')}</b><small>${T('Vida, colete, energia, fome, sede e estresse')}</small></span></label>
            <p class="ed-note">${T('O minimapa e o medidor de voz são do WHIP e não se movem aqui.')}</p>
            <div class="ed-actions">
                <button type="button" data-act="reset-all">${T('Restaurar tudo')}</button>
                <button type="button" data-act="cancel">${T('Cancelar')}</button>
                <button type="button" class="save" data-act="save">${T('Salvar')}</button>
            </div>`;
    }

    panel.addEventListener('click', e => {
        const b = e.target.closest('button');
        if (!b) return;
        if (b.dataset.part) return select(b.dataset.part);
        if (b.dataset.act === 'reset-one') { work[selected] = { x: 0, y: 0, s: 1 }; setVars(selected, work[selected]); render(); }
        if (b.dataset.act === 'reset-all') { work = {}; PARTS.forEach(p => setVars(p.id, entry(p.id))); render(); }
        if (b.dataset.act === 'cancel') close('cancel');
        if (b.dataset.act === 'save') close('save');
    });
    panel.addEventListener('input', e => {
        if (e.target.id !== 'ed-scale') return;
        const v = entry(selected);
        v.s = Math.min(MAX_S, Math.max(MIN_S, Number(e.target.value) / 100));
        setVars(selected, v);
        keepOnScreen(selected);
        panel.querySelector('output').textContent = `${Math.round(v.s * 100)}%`;
    });
    panel.addEventListener('change', e => {
        if (e.target.id !== 'ed-pin') return;
        workPin = e.target.checked;
        D.apply('pinStatus', workPin);
    });

    // dragging a part
    let drag = null;
    const partAt = target => PARTS.find(p => { const n = node(p.id); return n && n.contains(target); });
    window.addEventListener('mousedown', e => {
        if (!isOpen || e.button !== 0) return;
        if (panel.contains(e.target)) {
            if (e.target.closest('.ed-title')) {
                const r = panel.getBoundingClientRect();
                panel.style.transform = 'none';
                panel.style.left = `${r.left}px`;
                panel.style.top = `${r.top}px`;
                drag = { panel: true, x: e.clientX, y: e.clientY, left: r.left, top: r.top };
                e.preventDefault();
            }
            return;
        }
        const p = partAt(e.target);
        if (!p) return;
        if (p.id !== selected) select(p.id);
        drag = { id: p.id, x: e.clientX, y: e.clientY };
        e.preventDefault();
    });
    window.addEventListener('mousemove', e => {
        if (!drag) return;
        if (drag.panel) {
            panel.style.left = `${drag.left + e.clientX - drag.x}px`;
            panel.style.top = `${drag.top + e.clientY - drag.y}px`;
            return;
        }
        const vh = window.innerHeight / 100;
        const v = entry(drag.id);
        v.x += (e.clientX - drag.x) / vh;
        v.y += (e.clientY - drag.y) / vh;
        drag.x = e.clientX;
        drag.y = e.clientY;
        setVars(drag.id, v);
        keepOnScreen(drag.id);
    });
    window.addEventListener('mouseup', () => { drag = null; });

    window.addEventListener('keydown', e => {
        if (!isOpen) return;
        if (e.key === 'Escape') { e.preventDefault(); return close('cancel'); }
        const move = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] }[e.key];
        if (!move || (e.target && e.target.type === 'range')) return;
        e.preventDefault();
        const v = entry(selected), k = STEP * (e.shiftKey ? 4 : 1);
        v.x += move[0] * k;
        v.y += move[1] * k;
        setVars(selected, v);
        keepOnScreen(selected);
    });

    function open() {
        if (isOpen) return;
        isOpen = true;
        savedLayout = normalize(D.state.layout);
        savedPin = D.state.pinStatus === true;
        work = JSON.parse(JSON.stringify(savedLayout));
        workPin = savedPin;
        real = {};
        Object.keys(SAMPLE).forEach(k => { real[k] = D.state[k]; });
        D.hold = { keys: new Set(Object.keys(SAMPLE)), values: {} };
        PARTS.forEach(p => { const n = node(p.id); if (n) { n.dataset.label = T(p.label); n.classList.add('movable'); } });
        doc.classList.add('editing');
        Object.entries(SAMPLE).forEach(([k, v]) => D.apply(k, v));
        D.apply('editing', true);
        selected = 'status';
        render();
        panel.style.left = panel.style.top = panel.style.transform = '';
        panel.hidden = false;
        markSelected();
    }

    // mode: 'save' | 'cancel' (the player closed it here) | 'remote' (Lua closed it)
    function close(mode) {
        if (!isOpen) return;
        isOpen = false;
        drag = null;
        panel.hidden = true;
        doc.classList.remove('editing');
        PARTS.forEach(p => { const n = node(p.id); if (n) n.classList.remove('movable', 'sel'); });
        const held = D.hold ? D.hold.values : {};
        D.hold = null;
        Object.keys(SAMPLE).forEach(k => {
            const v = k in held ? held[k] : real[k];
            D.apply(k, v === undefined ? OFF[k] : v);
        });
        D.apply('editing', false);
        if (mode === 'save') {
            const layout = compact();
            D.apply('layout', layout);
            D.apply('pinStatus', workPin);
            D.post('editorSave', { layout, pinStatus: workPin });
        } else {
            applyLayout(savedLayout);
            D.apply('pinStatus', savedPin);
            if (mode === 'cancel') D.post('editorClose');
        }
    }

    D.on('layout', layout => { if (!isOpen) applyLayout(layout); });
    D.on('editor', show => { if (show === true) open(); else close('remote'); });
    D.on('locale', () => { if (isOpen) { PARTS.forEach(p => { const n = node(p.id); if (n) n.dataset.label = T(p.label); }); render(); } });
    window.addEventListener('resize', () => { if (isOpen) PARTS.forEach(p => keepOnScreen(p.id)); });
})();
