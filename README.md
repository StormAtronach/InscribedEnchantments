# Inscribed Enchantments

An MWSE-Lua mod for Morrowind that replaces the enchanted-item "plastic wrap" sheen with faint
Daedric glyphs (or a network of glowing cracks) drawn on the item's own surface. The glyphs sit in
each mesh's texture space, so they stay put on the item; they take the colour of the enchantment's
first magic effect; the engine animates them, nothing runs per frame in Lua.

The user-facing readme is [readme.txt](readme.txt). Releases are on Nexus Mods.

## Layout

```
MWSE/mods/InscribedEnchantments/   the mod (main, glow, config, mcm, i18n)
tools/generate_rune_sets.py        generates every texture set and template mesh
tools/font/                        hardek's Better Daedric Font (Aligned+XY), the glyph source
Better Daedric Font.txt            its licence; ships with the mod
Inscribed Enchantments-metadata.toml
readme.txt
```

`Textures/ie/` and `Meshes/ie/` are generated and not committed (about 90 MB). To rebuild them:

```
pip install numpy pillow
python tools/generate_rune_sets.py .            # all sets
python tools/generate_rune_sets.py . tools/font c,ch   # only the named sets
```

Every tunable is at the top of the script; each entry in `SETS` is one dropdown option in the
MCM and one folder suffix on disk.

## How it works, briefly

- Each enchanted item's texturing properties are cloned and given a glow map, an additive
  texture in the mesh's own UV coordinates.
- A `NiFlipController` cloned from a small template mesh cycles that map through 192 baked
  frames. An animated `NiBSAnimationNode` from the same template gives the controllers the
  game's global clock, so worn, drawn and dropped items animate at the same pace.
- The engine's shared reflective effect is detached from each item node; its `enabled` flag is
  only honoured for lights.
- Surfaces whose UV layout would stretch or oversize the glyphs are skipped, based on a
  per-shape measurement of the UV-to-world mapping.

## Credits

Glyphs are baked from hardek's "Better Daedric Font" (Aligned+XY variant), based on Dongle's
Oblivion Worn Daedric font; see `Better Daedric Font.txt`. Built with MWSE.
