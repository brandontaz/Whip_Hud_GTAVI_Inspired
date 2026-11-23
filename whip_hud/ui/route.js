// The GPS card next to the radar ring: the next turn's arrow and the distance left.
(() => {
    const root = document.getElementById('route');
    // client/route.lua names the turn.
    const ARROWS = {
        straight: 'M12 20V4M6 10l6-6 6 6',
        left: 'M18 20v-7a3 3 0 0 0-3-3H5M10 5l-5 5 5 5',
        right: 'M6 20v-7a3 3 0 0 1 3-3h10M14 5l5 5-5 5',
        sharpLeft: 'M15 20V6l-9 9M6 9v6h6',
        sharpRight: 'M9 20V6l9 9M18 9v6h-6',
    };

    root.hidden = true;
    root.innerHTML = '<div class="r-card"><b></b><svg class="ic" viewBox="0 0 24 24" aria-hidden="true"><path/></svg><small></small></div>';
    const arrow = root.querySelector('path');
    const distance = root.querySelector('b');
    const ahead = root.querySelector('small');

    function format(meters) {
        if (meters < 1000) return `${meters} m`;
        const km = (meters / 1000).toFixed(1);
        return `${D11Hud.lang === 'pt-BR' ? km.replace('.', ',') : km} km`;
    }

    D11Hud.on('route', route => {
        root.hidden = !route;
        if (!route) return;
        arrow.setAttribute('d', ARROWS[route.maneuver] || ARROWS.straight);
        distance.textContent = format(route.meters);
        ahead.textContent = Number.isFinite(route.ahead) ? format(route.ahead) : '';
        ahead.hidden = !ahead.textContent;
    });
})();
