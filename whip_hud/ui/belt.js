// Passenger seatbelt (client/seatbelt.lua sends 'passengerBelt' { visible, buckled }).
(() => {
    const el = document.getElementById('passenger-seatbelt');
    D11Hud.on('passengerBelt', (belt) => {
        belt = belt || {};
        const visible = belt.visible === true;
        const buckled = belt.buckled === true;
        el.classList.toggle('visible', visible);
        el.classList.toggle('buckled', buckled);
        el.classList.toggle('unbuckled', !buckled);
        el.setAttribute('aria-hidden', visible ? 'false' : 'true');
    });
})();
