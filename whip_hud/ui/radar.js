// The GTA VI minimap frame: a rounded rectangle round WHIP's map (#minimap3d, clipped by ../whip/hud.css), a compass
// tape across its top edge that scrolls with the camera, and the area and street inside the bottom edge.
// The map is WHIP's; this only draws the frame and the readouts.
(() => {
    const root = document.getElementById('radar');
    const DIRECTIONS = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];
    const SPAN = 180;                 // degrees visible across the tape
    const FROM = -180, TO = 540;      // strip covers 720 degrees so the wrap never shows
    const pos = d => ((d - FROM) / (TO - FROM) * 100).toFixed(4);

    const marks = [];
    for (let d = FROM; d <= TO; d += 5) {
        const major = d % 15 === 0;
        const mod = ((d % 360) + 360) % 360;
        const card = mod % 45 === 0;
        marks.push(`<i class="tk${major ? ' mj' : ''}${mod === 0 ? ' n' : ''}" style="left:${pos(d)}%"></i>`);
        if (card) marks.push(`<b class="lt${mod % 90 ? ' it' : ''}${mod === 0 ? ' n' : ''}" data-d="${DIRECTIONS[mod / 45]}" style="left:${pos(d)}%"></b>`);
    }

    root.hidden = true;
    root.innerHTML = `
        <div class="r-tape"><div class="r-strip" style="width:${(TO - FROM) / SPAN * 100}%">${marks.join('')}</div></div>
        <div class="r-pointer"></div>
        <div class="r-foot"><div class="r-loc"><span class="r-area"></span><span class="r-street"></span></div>
            <div class="r-deg"><span></span><i></i></div></div>`;

    const strip = root.querySelector('.r-strip');
    const letters = [...strip.querySelectorAll('.lt')];
    const degrees = root.querySelector('.r-deg span');
    const direction = root.querySelector('.r-deg i');
    const area = root.querySelector('.r-area');
    const street = root.querySelector('.r-street');
    const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
    const normalize = v => ((v % 360) + 360) % 360;
    let current = 0, target = 0, frame = 0, previousTime = 0;

    // translateX in % of the strip's own width: heading h sits at the tape's centre (left: 50%)
    const draw = () => { strip.style.transform = `translateX(${-pos(current)}%)`; };

    function animate(time) {
        frame = 0;
        const delta = normalize(target - current + 180) - 180;
        const elapsed = Math.max(0, time - previousTime);
        previousTime = time;
        current = Math.abs(delta) < .02 || reducedMotion.matches ? target : normalize(current + delta * (1 - Math.exp(-elapsed / 35)));
        draw();
        if (current !== target && !root.hidden) frame = requestAnimationFrame(animate);
    }
    function sync() {
        if (root.hidden) { cancelAnimationFrame(frame); frame = 0; current = target; draw(); }
        else if (!frame && current !== target) { previousTime = performance.now(); frame = requestAnimationFrame(animate); }
    }

    const relabel = () => letters.forEach(t => { t.textContent = D11Hud.T(t.dataset.d); });
    D11Hud.on('locale', relabel);
    relabel();
    D11Hud.on('heading', value => {
        if (!Number.isFinite(value)) return;
        target = normalize(value);
        degrees.textContent = `${String(Math.round(target) % 360).padStart(3, '0')}°`;
        direction.textContent = D11Hud.T(DIRECTIONS[Math.floor((target + 22.5) / 45) % 8]);
        sync();
    });
    D11Hud.on('radar', show => { root.hidden = show !== true; sync(); });
    D11Hud.on('location', loc => {
        if (!loc) return;
        street.textContent = loc.street || '';
        area.textContent = loc.area && loc.area !== 'NULL' ? loc.area : '';
    });
    draw();
})();
