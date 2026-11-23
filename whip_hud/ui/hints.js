// Action hints, bottom-right; they move left of the speedometer and the ammo when those are on screen.
(() => {
    const root = document.getElementById('hints');
    const GAP = 12; // px between the hints and whatever is to their right
    let signature, vehicleVisible = false;

    function place() {
        const edges = [];
        const gauge = document.querySelector('#gauge .gauge');
        if (vehicleVisible && gauge) {
            const box = gauge.getBoundingClientRect();
            if (box.width > 0) edges.push(box.left);
        }
        // ammo lives top-right in the GTA VI layout: only the speedometer pushes the hints left
        const right = edges.length ? Math.ceil(window.innerWidth - Math.min(...edges) + GAP) : null;
        root.style.right = right === null ? '' : `${right}px`;
    }

    D11Hud.on('hints', message => {
        const rows = Array.isArray(message && message.rows) ? message.rows : [];
        const next = JSON.stringify(message);
        if (next === signature) return; // the 250 ms beat does not rebuild the DOM
        signature = next;
        const scale = Math.max(1, Math.min(1.5, Number(message && message.scale) || 1));
        root.style.fontSize = `calc(clamp(12px, 1.3vh, 16px) * ${scale})`;
        root.replaceChildren(...rows.slice(0, 6).map(row => {
            const line = document.createElement('div');
            line.className = 'hint';
            const label = document.createElement('span');
            label.textContent = row.label;
            const key = document.createElement('kbd');
            key.textContent = row.key;
            line.append(label, key);
            return line;
        }));
        place();
    });
    D11Hud.on('vehicle', v => { vehicleVisible = !!(v && v.visible); place(); });
    D11Hud.on('ammo', () => requestAnimationFrame(place));
    window.addEventListener('resize', place);
})();
