// whip_hud's own icons (24x24 stroke). The contextual ones are centred on their optical centre (getBBox).
window.D11Icons = (() => {
    const paths = {
        health: '<path d="M19 14c1.5-1.5 3-3.2 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.8 0-3 .5-4.5 2-1.5-1.5-2.7-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4 3 5.5l7 7Z"/><path d="M3.5 12h4l1.5-3 3 6 1.5-3h7"/>',
        armor: '<path d="M20 13c0 5-3.5 7.5-7.7 9a1 1 0 0 1-.6 0C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.2-2.7a1.2 1.2 0 0 1 1.6 0C14.5 3.8 17 5 19 5a1 1 0 0 1 1 1z"/><path d="M12 3v18"/>',
        hunger: '<path d="M4 11a8 6.5 0 0 1 16 0Z"/><path d="M3 14.5h18"/><path d="M4.5 17.5h15v.5a2 2 0 0 1-2 2h-11a2 2 0 0 1-2-2Z"/><path d="M9 8h.01M12 7h.01M15 8h.01"/>',
        thirst: '<path d="M12 3c3 4 6.5 7.5 6.5 11a6.5 6.5 0 0 1-13 0C5.5 10.5 9 7 12 3Z"/><path d="M8.6 14.5a3.4 3.4 0 0 0 3.4 3.4"/>',
        stress: '<g transform="translate(0 .6)"><path d="M14.5 21v-3h2.2a1.8 1.8 0 0 0 1.8-1.8V13.5l1.8-.6-1.8-3.5A7.5 7.5 0 1 0 7 15.6V21"/><path d="M11.5 6.5l-2 2.5h3l-2 2.5"/></g>',
        energy: '<g transform="translate(0 .75)"><path d="M12 3v8M12 9.5l-2.5 2M12 9.5l2.5 2"/><path d="M8.5 6.5C6 6.5 4 10 4 14.5c0 3 1 5 2.6 5S9.5 18 9.5 16V9c0-1.5-.3-2.5-1-2.5ZM15.5 6.5C18 6.5 20 10 20 14.5c0 3-1 5-2.6 5S14.5 18 14.5 16V9c0-1.5.3-2.5 1-2.5Z"/></g>',
        bolt: '<path d="m13 2-8 12h6l-1 8 9-13h-6l1-7Z"/>',
        eye: '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12Z"/><circle cx="12" cy="12" r="3"/>',
        oxygen: '<g transform="translate(-1.5 .25)"><rect x="7.5" y="7" width="9" height="14" rx="4.5"/><path d="M10 7V4.5h4V7M12 2.5v2M14 3.5h3.5a2 2 0 0 1 2 2V8"/><path d="M10.5 13h3"/></g>',
    };
    return name => `<svg class="ic" viewBox="0 0 24 24" aria-hidden="true">${paths[name] || ''}</svg>`;
})();
