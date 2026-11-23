// The speedometer, one SVG in a 180 x 180 box centred on (90, 90), so every arc and every text line is placed against
// the same radii and nothing can spill over the face:
//   74 ......... the face (and its rim at 73.5)
//   66.25-70.75  the RPM band: 26 segments with real gaps, the lit ones revealed by a mask
//   60.25-62.75  nitrous (left, filling upwards) and turbo boost (right, its mirror)
//   58 ......... the inner ring; text stays within 56 of the centre (the chord is checked line by line)
//   77.5-80.5 .. fuel (outside, right) and, for aircraft, the climb rate (outside, left)
// Aircraft use the same dial: heading in the gear ring, knots as the big number, altitude and AGL under it, the
// horizon behind.
(() => {
    const root = document.getElementById('gauge');
    const ratio = value => Math.max(0, Math.min(1, Number(value) || 0));
    const T = text => D11Hud.T(text);

    function warningColor(value, whiteAt, yellowAt, redAt) {
        const white = [40, 225, 208], yellow = [255, 179, 71], red = [255, 31, 122];
        const start = value <= yellowAt ? white : yellow;
        const end = value <= yellowAt ? yellow : red;
        const mix = ratio(value <= yellowAt ? (value - whiteAt) / (yellowAt - whiteAt) : (value - yellowAt) / (redAt - yellowAt));
        return `rgb(${start.map((v, i) => Math.round(v + (end[i] - v) * mix)).join(', ')})`;
    }

    const icons = {
        lights: '<path d="M13 5c8 0 8 14 0 14V5ZM3 6l6 2M2 11h7M3 17l6-2"/>',
        belt: '<circle cx="12" cy="4" r="2"/><path d="M8 9l-2 9m10-9 2 9M9 8h6v9H9zM5 9l14 9M9 20v2m6-2v2"/>',
        lock: '<rect x="5" y="10" width="14" height="11" rx="2"/><path class="shackle" d="M8 10V6a4 4 0 0 1 8 0v4"/><path d="M12 14v3"/>',
        fuel: '<path d="M4 21V4h10v17M2 21h14M6 7h6v5H6zM14 10h3v7a2 2 0 0 0 4 0V8l-3-3"/>',
        engine: '<path d="M6 8h10l3 4h3v7h-4l-2 2H6v-3H3V9h3V8ZM8 4h7M11 4v4M1 11v5"/>',
        nitro: '<path d="m13 2-8 12h6l-1 8 9-13h-6l1-7Z"/>',
        gear: '<circle cx="12" cy="17.5" r="3.5"/><path d="M12 3v11M7 6h10"/>',
        rotor: '<path d="M2 5h20M12 5v5"/><circle cx="12" cy="14" r="4"/><path d="M12 14h.01"/>',
        vs: '<path d="M8 20V4M4 8l4-4 4 4M16 4v16M12 16l4 4 4-4"/>',
    };
    const icon = name => `<svg class="gi" viewBox="0 0 24 24" aria-hidden="true">${icons[name]}</svg>`;
    // a 24 x 24 icon drawn inside the dial, `size` units wide, centred on (x, y)
    const dialIcon = (name, cls, x, y, size) =>
        `<g class="gi ${cls}" transform="translate(${x - size / 2} ${y - size / 2}) scale(${size / 24})">${icons[name]}</g>`;

    const point = (radius, angle) => [90 + radius * Math.cos(angle * Math.PI / 180), 90 + radius * Math.sin(angle * Math.PI / 180)];
    // clockwise from start to end (degrees, 0 = right, 90 = down)
    const arc = (radius, start, end) => {
        const a = point(radius, start), b = point(radius, end);
        return `M${a.join(',')}A${radius},${radius} 0 ${end - start > 180 ? 1 : 0} 1 ${b.join(',')}`;
    };
    // anticlockwise from start to end: the turbo fills upwards on the right, as nitrous does on the left
    const arcBack = (radius, start, end) => {
        const a = point(radius, start), b = point(radius, end);
        return `M${a.join(',')}A${radius},${radius} 0 ${start - end > 180 ? 1 : 0} 0 ${b.join(',')}`;
    };

    const RPM_R = 68.5, RPM_FROM = 140, RPM_STEP = 10, RPM_SEGMENTS = 26, RPM_GAP = .7;
    const rpmPath = arc(RPM_R, RPM_FROM, RPM_FROM + RPM_STEP * RPM_SEGMENTS);
    const segment = i => arc(RPM_R, RPM_FROM + i * RPM_STEP + RPM_GAP, RPM_FROM + (i + 1) * RPM_STEP - RPM_GAP);
    const segments = Array.from({ length: RPM_SEGMENTS }, (_, i) => i);
    const rpmTrack = segments.map(i => `<path d="${segment(i)}"/>`).join('');
    const rpmLit = segments.map(i =>
        `<path class="g-rpm" d="${segment(i)}" style="stroke:${warningColor(i / (RPM_SEGMENTS - 1), .3, .65, .92)}"/>`).join('');

    const fuelPath = arc(79, -30, 30);
    const vsTrack = arc(79, 150, 210);       // the fuel arc's mirror, left side
    const nitroPath = arc(61.5, 144, 246);    // inside the RPM band, from its start
    const turboPath = arcBack(61.5, 36, -66); // the mirror on the right, from the RPM band's end
    const pitchLines = [-20, -10, 10, 20].map(p => {
        const y = 90 - p * 1.6, w = p % 20 ? 10 : 16;
        return `<line x1="${90 - w}" x2="${90 + w}" y1="${y}" y2="${y}"/>`;
    }).join('');
    const INDICATORS = { gear: 'Trem de pouso', rotor: 'Rotor', lights: 'Faróis', belt: 'Cinto', lock: 'Travas', engine: 'Motor', nitro: 'Nitro' };
    const CAR_ONLY = ['belt', 'lock', 'nitro'];
    const CARDINAL = ['N', 'NE', 'L', 'SE', 'S', 'SO', 'O', 'NO'];

    root.innerHTML = `<div class="gauge" hidden>
        <svg class="g-dial" viewBox="0 0 180 180" aria-hidden="true">
            <defs>
                <mask id="g-rpm-mask" maskUnits="userSpaceOnUse" x="0" y="0" width="180" height="180">
                    <path class="g-reveal" d="${rpmPath}" pathLength="100" stroke="white" stroke-width="8" fill="none" style="stroke-dasharray:0 100"/>
                </mask>
                <clipPath id="g-clip"><circle cx="90" cy="90" r="57.5"/></clipPath>
                <radialGradient id="g-face" cx="50%" cy="40%" r="60%">
                    <stop offset="0" stop-color="#2b1046" stop-opacity=".86"/><stop offset="1" stop-color="#0d0618" stop-opacity=".92"/>
                </radialGradient>
            </defs>
            <circle class="g-back" cx="90" cy="90" r="74" fill="url(#g-face)"/>
            <circle class="g-rim" cx="90" cy="90" r="73.5"/>
            <g class="g-horizon" clip-path="url(#g-clip)"><g class="g-hz">
                <rect x="-110" y="-310" width="400" height="400" fill="#9B5CFF" fill-opacity=".25"/>
                <rect x="-110" y="90" width="400" height="400" fill="#000" fill-opacity=".34"/>
                <line class="g-hz-line" x1="-110" x2="290" y1="90" y2="90"/><g class="g-pitch">${pitchLines}</g>
            </g></g>
            <circle class="g-inner" cx="90" cy="90" r="58"/>
            <g class="g-rpm-track">${rpmTrack}</g>
            <g mask="url(#g-rpm-mask)">${rpmLit}</g>
            <g class="g-nitro-wrap"><path class="g-nitro-track" d="${nitroPath}"/><path class="g-nitro" d="${nitroPath}" pathLength="100" style="stroke-dasharray:0 100"/></g>
            <g class="g-turbo-wrap"><path class="g-turbo-track" d="${turboPath}"/><path class="g-turbo" d="${turboPath}" pathLength="100" style="stroke-dasharray:0 100"/>
                <text class="g-txt g-boost" x="90" y="131"><tspan class="g-boost-n">0</tspan><tspan class="g-boost-u" dx="2">PSI</tspan></text></g>
            <g class="g-fuel-ring"><path class="g-fuel-track" d="${fuelPath}"/><path class="g-fuel" d="${fuelPath}" pathLength="100"/></g>
            ${dialIcon('fuel', 'g-fuel-icon', 177.5, 90, 12)}
            <g class="g-vs-wrap"><path class="g-vs-track" d="${vsTrack}"/><path class="g-vs"/><line class="g-vs-zero" x1="8" x2="13" y1="90" y2="90"/></g>
            ${dialIcon('vs', 'g-vs-icon', 2.5, 90, 12)}
            <circle class="g-gear-ring" cx="90" cy="46" r="11"/>
            <text class="g-txt g-gear" x="90" y="46.5">N</text>
            <text class="g-txt g-gear-label" x="90" y="63">GEAR</text>
            <text class="g-txt g-speed" x="90" y="92" transform="matrix(.8 0 0 1 18 0)">000</text>
            <text class="g-txt g-unit" x="90" y="115">MPH</text>
            <text class="g-txt g-alt g-air-only" x="90" y="128"></text>
            <text class="g-txt g-agl g-air-only" x="90" y="139"></text>
        </svg>
        <div class="g-warn"></div>
        <div class="g-ind">${Object.keys(INDICATORS).map(name =>
            `<span data-i="${name}">${icon(name)}${name === 'engine' || name === 'rotor' ? '<i class="g-meter"></i>' : ''}</span>`).join('')}</div>
    </div>`;

    const el = root.querySelector('.gauge');
    const $ = s => el.querySelector(s);
    const show = (s, on) => { $(s).style.display = on ? '' : 'none'; };
    let vehicle = { visible: false };
    let nitro = { visible: false, level: 0, burst: false };
    let turbo = { visible: false, psi: 0, max: 0 };

    // The ammo and the action hints sit left of the speedometer: report its edge.
    let lastLeft;
    function reportBounds() {
        const box = el.getBoundingClientRect();
        const left = vehicle.visible && box.width > 0 ? +(box.left / window.innerWidth).toFixed(4) : null;
        if (left === lastLeft) return;
        lastLeft = left;
        D11Hud.post('gaugeBounds', { left });
    }

    function render() {
        el.hidden = !vehicle.visible;
        reportBounds();
        if (!vehicle.visible) return;
        const v = vehicle;
        const rpm = ratio(v.rpm);

        $('.g-speed').textContent = String(Math.max(0, Math.floor(Number(v.speed) || 0))).padStart(3, '0');
        $('.g-unit').textContent = v.unit || 'MPH';
        $('.g-gear').textContent = /^(R|N|D|[1-9][0-9]?)$/.test(String(v.gear)) ? v.gear : 'N';
        $('.g-gear-label').textContent = 'GEAR';
        el.style.setProperty('--fuel-color', warningColor(1 - ratio(v.fuel), .6, .8, .9));
        el.style.setProperty('--engine-color', warningColor(v.checkEngine ? 1 : 1 - ratio(v.engineHealth), .3, .5, .7));
        // electric: no red band, one blue arc
        el.classList.toggle('electric', !!v.electric);
        $('.g-reveal').style.strokeDasharray = `${rpm * 100} 100`;
        $('.g-fuel').style.strokeDasharray = `${ratio(v.fuel) * 100} 100`;
        show('.g-fuel-ring', v.fuelVisible);
        show('.g-fuel-icon', v.fuelVisible);
        el.classList.toggle('fuel-low', !!v.fuelVisible && ratio(v.fuel) <= .15);

        // nitrous: the inner left arc, bright while it burns
        const burst = nitro.burst === true;
        show('.g-nitro-wrap', nitro.visible && !v.aircraft);
        $('.g-nitro').style.strokeDasharray = `${ratio(nitro.level) * 100} 100`;
        $('.g-nitro').classList.toggle('burst', burst);

        // turbo: the inner right arc fills with boost up to the stage's full psi; vacuum leaves it empty
        const max = Number(turbo.max) || 0, psi = Number(turbo.psi) || 0;
        const boost = max > 0 ? ratio(psi / max) : 0;
        show('.g-turbo-wrap', turbo.visible && !v.aircraft);
        $('.g-turbo').style.strokeDasharray = `${boost * 100} 100`;
        $('.g-turbo').classList.toggle('full', boost >= .95);
        $('.g-boost-n').textContent = String(Math.round(psi));

        const air = v.aircraft;
        el.classList.toggle('air', !!air);
        const warn = air ? renderAircraft(air, v) : '';
        $('.g-warn').innerHTML = warn ? `<span>${T(warn)}</span>` : '';

        const gearDown = !!air && air.gear === 'down';
        const on = { lights: v.lights || v.highbeams, belt: v.seatbelt, lock: v.locked, engine: v.engineRunning, nitro: burst, gear: gearDown, rotor: !!air && air.rotor > .65 };
        const hide = { belt: !v.seatbeltVisible, engine: !v.engineVisible, nitro: !nitro.visible, gear: !air || !air.gear, rotor: !air || !air.heli };
        if (air) CAR_ONLY.forEach(name => { hide[name] = true; });
        for (const [name, title] of Object.entries(INDICATORS)) {
            const ind = $(`[data-i="${name}"]`);
            ind.hidden = !!hide[name];
            ind.title = T(title);
            ind.classList.toggle('on', !!on[name]);
            ind.classList.toggle('warning', (name === 'belt' && !v.seatbelt) || (name === 'engine' && !!v.checkEngine));
            ind.classList.toggle('blue', (name === 'lights' && !!v.highbeams) || (name === 'nitro' && burst));
            ind.classList.toggle('unlocked', name === 'lock' && !v.locked);
        }
        $('[data-i="belt"]').title = T(v.seatbelt ? 'Cinto afivelado' : 'Cinto desafivelado');
        $('[data-i="lock"]').title = T(v.locked ? 'Portas travadas' : 'Portas destravadas');
        $('[data-i="engine"] .g-meter').style.setProperty('--level', ratio(v.engineHealth));
        $('[data-i="gear"]').classList.toggle('alarm', warn === 'TREM');
        $('[data-i="gear"]').classList.toggle('blue', gearDown);
        $('[data-i="gear"]').title = T(gearDown ? 'Trem baixado' : 'Trem recolhido');
        $('[data-i="rotor"]').classList.toggle('warning', !!air && !!air.heli && air.rotor <= .65);
        if (air && air.heli) $('[data-i="rotor"] .g-meter').style.setProperty('--level', ratio(air.rotor));
    }

    const fmt = n => Math.round(n).toLocaleString(D11Hud.lang === 'pt-BR' ? 'pt-BR' : 'en-US');

    // Draws the aircraft readings and answers the footer warning ('' for none).
    function renderAircraft(a, v) {
        $('.g-speed').textContent = String(Math.max(0, Math.floor(a.knots))).padStart(3, '0');
        $('.g-unit').textContent = 'KT';
        $('.g-gear').textContent = a.direction || T(CARDINAL[Math.round(a.heading / 45) % 8]);
        $('.g-gear-label').textContent = T('RUMO');
        $('.g-alt').innerHTML = `<tspan class="g-n">${fmt(a.altitude)}</tspan><tspan class="g-u" dx="2">FT</tspan>`;
        $('.g-agl').innerHTML = `AGL <tspan class="g-n">${fmt(a.agl)}</tspan>`;
        const pitch = Math.max(-30, Math.min(30, a.pitch));
        $('.g-hz').setAttribute('transform', `rotate(${-a.roll} 90 90) translate(0 ${pitch * 1.6})`);

        // climb rate: 2000 ft/min fills the arc; up goes up, down goes down
        const ang = Math.max(-1, Math.min(1, a.vs / 2000)) * 30;
        $('.g-vs').setAttribute('d', Math.abs(ang) < .5 ? '' : ang > 0 ? arc(79, 180, 180 + ang) : arc(79, 180 + ang, 180));
        const danger = a.airborne && a.agl < 300 && a.vs < -800;
        el.style.setProperty('--vs-color', danger ? '#ef655b' : ang >= 0 ? '#62c8f2' : '#edf1f4');

        if (!a.heli && a.airborne && a.gear && a.gear !== 'down' && a.agl < 150) return 'TREM';
        if (v.fuelVisible && ratio(v.fuel) <= .1) return 'COMBUSTÍVEL';
        return '';
    }

    D11Hud.on('vehicle', v => { vehicle = v || { visible: false }; render(); });
    D11Hud.on('nitro', n => { nitro = n || nitro; render(); });
    D11Hud.on('turbo', t => { turbo = t || turbo; render(); });
    window.addEventListener('resize', () => { lastLeft = undefined; reportBounds(); });
})();
