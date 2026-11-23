// Player status, top-left, GTA VI style: slim segmented bars (health, armour, stamina, and focus when a resource
// supplies `focus`), small chips under them for hunger, thirst, oxygen and stress. Dynamic HUD: the block fades out
// when nothing needs attention (full bars, no weapon out) and wakes on any change.
(() => {
    const icon = window.D11Icons;
    const host = document.getElementById('status');
    if (!host || !icon) return;

    const LABEL = { health: 'Vida', armor: 'Colete' };
    const WAKE_MS = 6000;
    // 'Keep status on screen' (the /hud menu), and the /hud editor itself: every bar and chip stays visible
    const pinned = () => D11Hud.state.pinStatus === true || D11Hud.state.editing === true;
    const clamp = v => Math.max(0, Math.min(100, Number(v) || 0));

    const BARS = [
        // key, icon, colour, gradient start
        ['health', 'health', '#ff3c8e', '#ff1f5a'],
        ['armor', 'armor', '#28e1d0', '#1d8fd6'],
        ['energy', 'bolt', '#ffb347', '#ff7a3c'],
        ['focus', 'eye', '#9b5cff', '#6a3cff'],
    ];
    const CHIPS = [
        ['hunger', '#ffb347'],
        ['thirst', '#62c8f2'],
        ['oxygen', '#5aa0ff'],
        ['stress', '#9b5cff'],
    ];

    host.innerHTML = `<div class="sbars">${BARS.map(([k, ic, c, c0]) => `
        <div class="bar ${k}" data-k="${k}" style="--c:${c};--c0:${c0}" hidden>
            <span class="ico">${icon(ic)}</span>
            <span class="track"><i class="fill"></i></span>
        </div>`).join('')}</div>
        <div class="chips">${CHIPS.map(([k, c]) => `
        <span class="chip ${k}" data-c="${k}" style="--c:${c}" hidden>${icon(k)}<span class="meter"><i></i></span></span>`).join('')}</div>`;

    const bar = k => host.querySelector(`[data-k="${k}"]`);
    const chip = k => host.querySelector(`[data-c="${k}"]`);
    let status = null, wakeUntil = 0, timer = 0, lastSig = '';

    const idle = () => {
        if (!status) return true;
        if (pinned()) return false;
        const st = D11Hud.state;
        if (st.dynamic === false) return false;
        if (Date.now() < wakeUntil) return false;
        if (status.health <= 40 || status.energy < 100 || status.oxygen < 100) return false;
        if (status.hunger <= 30 || status.thirst <= 30 || status.stress >= 5) return false;
        if (st.ammo && st.ammo.visible) return false;
        return true;
    };

    function applyIdle() {
        host.classList.toggle('idle', idle());
        clearTimeout(timer);
        const left = wakeUntil - Date.now();
        if (left > 0) timer = setTimeout(applyIdle, left + 50);
    }
    const wake = () => { wakeUntil = Date.now() + WAKE_MS; applyIdle(); };

    function draw() {
        if (!status) return;
        const s = status;
        const show = (k, on, v) => {
            const el = bar(k);
            el.hidden = !on;
            if (!on) return;
            el.style.setProperty('--v', (clamp(v) / 100).toFixed(3));
            el.classList.toggle('crit', k === 'health' && v <= 25);
            el.classList.toggle('empty', v <= 0);
        };
        show('health', true, s.health);
        show('armor', s.armor > 0 || pinned() || D11Hud.state.dynamic === false, s.armor);
        show('energy', s.energy < 100 || pinned() || D11Hud.state.dynamic === false, s.energy);
        show('focus', typeof s.focus === 'number', s.focus);
        bar('health').title = D11Hud.T(LABEL.health);
        bar('armor').title = D11Hud.T(LABEL.armor);

        const chipOn = {
            hunger: s.hunger < 60, thirst: s.thirst < 60, oxygen: s.oxygen < 100, stress: s.stress >= 5,
        };
        for (const [k] of CHIPS) {
            const el = chip(k);
            const v = clamp(s[k]);
            const on = chipOn[k] || (pinned() && k !== 'oxygen') || D11Hud.state.dynamic === false && k !== 'oxygen' && k !== 'stress';
            el.hidden = !on;
            if (!on) continue;
            el.querySelector('i').style.transform = `scaleX(${v / 100})`;
            el.classList.toggle('low', k === 'stress' ? v >= 75 : v <= 20);
            el.title = k;
        }
    }

    D11Hud.on('status', s => {
        if (!s) return;
        // wake on a change in what the bars show, not on every 200 ms poll
        const sig = [s.health, s.armor, s.energy, s.oxygen, s.stress, s.hunger, s.thirst].join('|');
        const first = lastSig === '';
        status = s;
        draw();
        if (sig !== lastSig) { lastSig = sig; if (!first) wake(); else applyIdle(); }
    });
    ['ammo', 'dynamic', 'vehicle', 'pinStatus', 'editing'].forEach(key => D11Hud.on(key, () => { draw(); applyIdle(); }));
})();
