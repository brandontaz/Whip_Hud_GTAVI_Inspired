# whip_theme

Your own WHIP theme. It carries [whip_hud](../whip_hud)'s layer, which **overrides WHIP's old HUD**: WHIP's status
gauges and 3D rev dial are hidden and its minimap becomes the rounded GTA VI box, so whip_hud's HUD is all you see.

```cfg
ensure whip_core
ensure whip_theme
ensure whip_hud
```

whip_hud sets whip_theme as WHIP's active theme by itself when nothing else is active (or when the old `d11_hud`,
`d11_theme` or `whip_theme_d12` is still the saved one). If the old `whip_theme_d12` is running and holds the theme, whip_hud stops it and takes over: remove `ensure whip_theme_d12` from `server.cfg` so it doesn't start again. To pin it yourself: `Config.Theme = 'whip_theme'` in whip_core.

Put your own CSS in `theme.css`, **below** the `@import` line (CSS ignores an `@import` after any rule). Do not edit
`css/whip_hud.css`: `server.lua` rewrites it from whip_hud.
