# Inscribed Enchantments

An MWSE-Lua mod for Morrowind that replaces the enchanted-item "plastic wrap" sheen with faint
Daedric glyphs (or a network of glowing cracks) drawn on the item's own surface. The glyphs sit in
each mesh's texture space, so they stay put on the item; they take the colour of the enchantment's
first magic effect; the engine animates them, nothing runs per frame in Lua.

The vanilla effect is an environment map, looked up by the surface's direction relative to the
camera, so anything drawn into its textures slides with the view. That is why this is a Lua mod
and not a texture replacer: the glow map is the one fixed-function stage that both stays put on
the surface and adds light.

The user-facing readme is [readme.txt](readme.txt). Releases are on Nexus Mods and under
[Releases](../../releases) here.

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

- The mod clones each enchanted item's texturing properties and gives them a glow map, an
  additive texture in the mesh's own UV coordinates.
- A `NiFlipController` cloned from a small template mesh cycles that map through 192 baked
  frames. An animated `NiBSAnimationNode` from the same template gives the controllers the
  game's global clock, so worn, drawn and dropped items animate at the same pace.
- The mod detaches the engine's shared reflective effect from each item node. Its `enabled`
  flag looks like the obvious switch, but only the light manager reads it.
- Before decorating a shape the mod measures its UV-to-world mapping and skips it when the
  glyphs would come out stretched or oversized.

A longer write-up of the engine behaviour this relies on (controller timing, animation
managers, why worn and placed items need different node layouts) lives with the author's
engineering notes and may move here later.

## Credits

The glyphs come from hardek's "Better Daedric Font" (Aligned+XY variant), based on Dongle's
Oblivion Worn Daedric font; see `Better Daedric Font.txt`. Built with MWSE. Licensed under MIT
(see `LICENSE`); the font keeps its own terms.
