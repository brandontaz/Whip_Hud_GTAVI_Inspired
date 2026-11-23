// Weapon and ammo, bottom-right (client/weapons.lua sends 'ammo').
(() => {
    const host = document.getElementById('hud');
    const wrap = document.createElement('div');
    wrap.id = 'ammo';
    wrap.innerHTML = `
        <div class="ammo-line">
            <div class="mag">
                <div class="mag-icon">
                    <svg class="mag-outline" viewBox="0 0 24 24"><path d="M8 2h8l1 3v15a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V5l1-3Z"/></svg>
                    <svg class="mag-fill" viewBox="0 0 24 24"><path d="M8 2h8l1 3v15a2 2 0 0 1-2 2H9a2 2 0 0 1-2-2V5l1-3Z"/></svg>
                </div>
                <span class="spare">0</span>
            </div>
            <div class="rounds"><span class="current">0</span><span class="sep">/</span><span class="capacity">0</span></div>
        </div>
        <div class="weapon-silhouette" aria-hidden="true"></div>`;
    host.appendChild(wrap);
    const magFill = wrap.querySelector('.mag-fill');
    const spareEl = wrap.querySelector('.spare');
    const currentEl = wrap.querySelector('.current');
    const capacityEl = wrap.querySelector('.capacity');
    const silhouette = wrap.querySelector('.weapon-silhouette');
    const PATH = /^weapons\/(?:weapon|tool)_[a-z0-9_]+\/[a-z0-9_]+\.png$/;
    let visualKey = null;

    D11Hud.on('ammo', (data) => {
        if (!data) return;
        wrap.classList.toggle('melee', data.showAmmo === false);
        wrap.classList.toggle('in-vehicle', data.inVehicle === true);
        const clip = data.clip || 0, max = data.max || 0, spare = data.spare || 0;
        const pct = max > 0 ? Math.max(0, Math.min(1, clip / max)) : 0;
        magFill.style.clipPath = 'inset(' + (100 - pct * 100) + '% 0 0 0)';
        currentEl.textContent = String(clip).padStart(2, '0');
        capacityEl.textContent = String(max).padStart(2, '0');
        spareEl.textContent = spare;
        currentEl.classList.toggle('empty', clip === 0);
        spareEl.classList.toggle('empty', spare === 0);
        if (typeof data.visualKey === 'string' && data.visualKey !== visualKey && Array.isArray(data.layers)) {
            visualKey = data.visualKey;
            silhouette.replaceChildren(...data.layers.filter((p) => PATH.test(p)).map((p) => {
                const img = document.createElement('img');
                img.src = p;
                img.alt = '';
                img.draggable = false;
                img.onerror = () => img.remove();
                return img;
            }));
        }
        wrap.classList.toggle('visible', !!data.visible);
    });
})();
