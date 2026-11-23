# D11 HUD for WHIP

The HUD we run on District 11 (D11), for [WHIP](https://github.com/WHIPFX/whip_core). It draws in its own page and
reads everything from whip_core's exports and stats: no framework bridge, no SQL.

> **English and Brazilian Portuguese.** One line in server.cfg picks the language of every D11 resource:
> `setr whip_locale en` (the default) or `setr whip_locale pt-BR`.

## GTA VI look (v1.2.0)

This version restyles every part of the HUD after Grand Theft Auto VI's interface, in a Vice City neon palette
(pink `#FF3C8E`, violet `#9B5CFF`, teal `#28E1D0`, sunset orange `#FFB347`):

| Part | Now |
| --- | --- |
| **Status** | Slim segmented bars, **top-left**: health, armour (only while you have some) and stamina, with a white separator between them. Hunger, thirst, oxygen and stress are small chips underneath. A purple **Focus** bar (eye icon) appears if a resource sends `focus` (0-100) in the status payload. |
| **Dynamic HUD** | The status block fades out when nothing needs attention (full bars, no weapon out) and returns for 6 s on any change. `Dynamic = false` keeps it always on. |
| **Ammo** | Top-right: big italic counter, spare magazines and the weapon's silhouette. |
| **Minimap** | **Bottom-left**, a rounded rectangle with a pink-to-violet frame (drawn by the WHIP layer). |
| **Compass** | **Top middle**: a tape that scrolls with the camera, with area, street and heading under it. |
| **GPS card** | Pink distance card beside the minimap. |
| **Voice** | WHIP's own voice bars, unchanged, in the bottom-right corner; the speedometer sits just left of them. |
| **Speedometer** | Same dial, neon face: teal-to-pink RPM band, pink rim, teal nitrous, amber turbo. |

The minimap frame (`#radar` in `ui/hud.css`) and the clip in `whip/hud.css` (`--mm-w`, `--mm-h`, `--mm-r`) must stay in
step: change them together. If your WHIP minimap box is smaller than 21vh x 13.5vh, the map just fills the box.
The pink line GTA draws on the in-world route is the game's own and is not touched by this resource.

## What's inside

| Part | What it does |
| --- | --- |
| **Status** | Health and armour pills with hunger and thirst lines under them; stress, energy and oxygen orbs that show only when they matter. |
| **Speedometer** | Speed (mph or km/h), gear, RPM arc, fuel (or charge on an electric car), engine health, lights, locks and seatbelt. Aircraft get heading, knots, altitude, AGL, climb rate and an artificial horizon. |
| **Turbo gauge** | For cars with a [whip_autos](https://github.com/WHIPFX/whip_autos) turbo: an arc inside the RPM one, filled up to the stage's full boost, and the boost in psi. Only shows when a turbo is fitted. |
| **Nitrous gauge** | For cars with a whip_autos nitrous bottle: the mirror arc on the left, how much is left, bright while it burns. Only shows when a bottle is fitted. |
| **Seatbelt** | **B** buckles up (players rebind it in Settings > Key Bindings > FiveM). Unbuckled, a crash above 20 km/h throws you through the windscreen (160 km/h buckled); buckled, you can't leave the car until you unbuckle. Passengers get a small belt icon. `LocalPlayer.state.seatbelt` is there for other scripts. |
| **Radar** | A round compass ring over WHIP's minimap (clipped round), the heading in degrees, area and street. |
| **GPS card** | Next to the ring: the next turn, read off the GPS line itself, the distance to it and the distance left. |
| **Ammo** | Rounds in the weapon, spare magazines and the weapon's silhouette with its attachments, from [whip_gunny](https://github.com/WHIPFX/whip_gunny) (`GetDrawnWeapon` and its own catalogue). GTA's ammo without gunny. |
| **Action hints** | The keys that matter right now, in the bottom-right corner (seatbelt, engine, cancel an emote). `/hints on\|off\|bigger\|smaller` (`/legendas` in pt-BR). Other scripts can add theirs. |
| **Low fuel** | A WHIP notification when the tank is at 20% or less. |

WHIP's own voice gauge stays (only whip_core knows when the player talks), as a small circle above the speedometer.

## /hud: move everything where you want it

`/hud` opens the editor (`Menu.Command` in `config.lua`; `Menu.Enabled = false` turns it off).

- **Drag** any part (status, compass, GPS card, speedometer, ammo, key hints, passenger seatbelt) with the mouse; the
  arrow keys nudge the selected one (Shift = faster). Parts can't be dragged off the screen.
- **Size**: a slider per part, 50% to 160%. **Reset this part** / **Reset all** put the defaults back.
- **Keep status on screen**: health, armour, energy, food, water and stress stay visible all the time instead of fading
  out (oxygen still only shows underwater). `PinStatus = true` in `config.lua` makes that the default.
- **Save** keeps it on that PC (KVP, so it survives restarts); **Cancel** / Esc throws the changes away.

The compass, GPS card, ammo and seatbelt tile are shown with sample data while you edit, and the real values are held
back until you close it. The **minimap and WHIP's voice gauge belong to WHIP's own page**, so they can't be dragged here.

## whip_theme (overrides WHIP's old HUD)

`whip_theme` ships next to whip_hud. It is a WHIP theme whose `theme.css` imports whip_hud's layer, so WHIP's own
status gauges and rev dial are hidden and its minimap becomes the rounded box: the old HUD is gone, whip_hud's replaces
it. whip_hud makes it WHIP's active theme by itself (over nothing, an old `d11_` name, or `whip_theme_d12`). Your own CSS
goes in `whip_theme/theme.css`, below the `@import` line.

```cfg
ensure whip_core
ensure whip_theme
ensure whip_hud
```

`Theme = 'some_theme'` in `config.lua` is the other way: whip_hud adds its two `@import` lines to that theme's
stylesheet (and removes them when it stops).

## Installation

Put `whip_hud` in your `resources` folder and add, after the `ensure whip_*` lines:

```cfg
setr whip_locale en
ensure whip_hud
```

whip_hud hides WHIP's status gauges and 3D rev dial and clips the minimap round. That is CSS inside whip_core's page,
so whip_hud loads it as a WHIP theme when **no other theme** is active. Already running a theme (Config.Theme or a
theme resource)? Add these lines to your theme's `theme.css` and set `WhipLayer = false` in `config.lua`:

```css
@import url('https://cfx-nui-whip_hud/whip/hud.css');     /* rev dial hidden, round minimap */
@import url('https://cfx-nui-whip_hud/whip/status.css');  /* WHIP's status gauges hidden, voice as a circle */
```

Running [whip_theme](https://github.com/DLady25/whip-d11-theme), our WHIP theme? Uncomment the two whip_hud lines at the
top of its `theme.css` (1.0.1 ships them commented out, so the theme still loads without whip_hud). The old `whip_theme_d12` from the D11 Starter Kit does not round the minimap: replace it with whip_theme.

At start the server console says which way it went, in a `[whip_hud] WHIP layer ...` line, and each player gets the
same line in F8 a few seconds after loading in.

**Use WHIP's classic HUD skin** (`/whip` → Config → HUD skin: classic). The black skin draws a white frame round the
minimap in the game itself, under the page, so no CSS can move it: it would stay empty at the bottom left.

### Keeping WHIP's own health gauges

Like WHIP's gauges better than whip_hud's pills? Set `Status = false` in `config.lua` and delete the `whip/status.css`
line from `whip_hud/theme.css` (or don't import it into your theme). whip_hud then draws no health, armour, hunger or
thirst, and WHIP's own gauges stay; the map, speedometer, turbo, nitrous, seatbelt, ammo and hints don't change.

## Troubleshooting

### The map is not in the pink frame / WHIP's round gauges show at the bottom left

WHIP's page is not loading the whip_hud layer (`whip/hud.css` + `whip/status.css`). With `Debug = true` (config.lua) the
server console and F8 say why, in a `[whip_hud] WHIP layer ...` line. Quick test, in game: `/whip_theme whip_hud` (needs the
devtools ACE). If the map jumps into the frame, the layer is fine and it was only not loading at login. To make it load
every time, set `Config.Theme = 'whip_hud'` in whip_core's config.lua. After updating whip_hud, reconnect to the server
(not just restart the resource) so FiveM re-downloads the files.


| What you see | Check |
| --- | --- |
| The ring is empty and WHIP's square minimap is still at the bottom left | The F8 or server `[whip_hud] WHIP layer` line. "off: the WHIP theme ... is active": add the two `@import` lines to that theme. "on" but still square: restart the client once (FiveM's NUI cache), and send us that line. |
| An empty white frame at the bottom left | WHIP's black HUD skin: switch it to classic. |
| WHIP's gauges show next to whip_hud's pills | `whip/status.css` is not loaded: see the line above. |
| The turbo gauge reads a little differently from WHIP's own dial | Expected without the whip_core patch (below). |

## Configuration

`whip_hud/config.lua`:

```lua
D11Hud = {
    SpeedUnit = 'mph',      -- 'mph' or 'kmh'
    Logo = false,           -- the D11 logo top-right (ui/logo.png: swap it for your own)
    Status = true,          -- false: keep WHIP's own health gauges (see above)
    WhipLayer = true,       -- load whip/hud.css as a WHIP theme when no other theme is active
    Radar = true,           -- compass ring over the minimap
    Route = true,           -- GPS card next to it
    MapDefaults = true,     -- once per PC: minimap on foot too, 25% less zoom in a vehicle
    Dynamic = true,         -- status bars fade out when idle
    Ammo = true,
    Turbo = true,
    Nitro = true,
    Seatbelt = { Enabled = true, Key = 'B', EjectKmh = 20, EjectBuckledKmh = 160 },
    Hints = { Enabled = true, Command = 'hints' },
    LowFuel = { Enabled = true, Threshold = 20, RepeatSeconds = 60 },
    Stamina = false,        -- or { resource = 'my_movement', export = 'GetStamina' } (0-100) for the energy orb
}
```

## Turbo and nitrous

whip_autos keeps both as whip_core vehicle stats (`boost` and `nitro`), so whip_hud needs nothing from whip_autos
itself. The driver's **live** boost, though, is a number whip_autos hands only to whip_core's own gauge, and whip_core
has no export for it. Two ways:

- **With the patch** in `whip_core-patches/` (one export, `GetVehicleStatReading`, read only): the turbo gauge shows
  exactly what whip_autos simulates, the same psi WHIP's own dial would show, and nitrous drains smoothly.
- **Without it** it still works: the nitrous arc follows the bottle as whip_core holds it (a step behind while it
  burns), and the turbo arc follows GTA's own turbo part, which whip_autos fits with every stage, scaled to the
  stage's psi: the same spool and blow-off, not the same number. With a passenger in the car it is exact either way.

```
cd resources
patch -p1 < whip_core-vehicle-stat-reading-d11.patch
```

Restart whip_core after applying it.

## For developers

```lua
-- action hints, client side: up to six rows, priority 0-100 (default 50); cleared when your resource stops
exports.whip_hud:SetHints('vehicle-access', {
    { key = 'E', label = 'Open the boot' },
    { command = 'my_command', label = 'Do the thing' },   -- shows the key the player bound
}, 60)
exports.whip_hud:ClearHints('vehicle-access')
```

Texts are in `ui/locales.js` (the Portuguese text is the key; one map per language) and in the Lua files as
`L(english, portuguese)`.

## Requirements

- whip_core 1.0.1 or newer.
- Optional: whip_autos (turbo and nitrous), whip_gunny (ammo), whip_fuel (fuel).

## License

MIT (see `LICENSE`). `whip_core-patches/` changes whip_core and is under whip_core's own license (LGPL-3.0).

## Credits

- Fonts in `ui/fonts`: Quantico (Andrea Herstowski) and Geist (Vercel), both under the SIL Open Font License.
- Built on WHIP by Whippy and the WHIP contributors.
