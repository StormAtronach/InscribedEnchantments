Inscribed Enchantments - plastic wrap be gone
=========================================

Replaces Morrowind's enchanted-item "plastic wrap" sheen with faint Daedric glyphs that fade in
and out on the item's surface. The glyphs are written into each mesh's own texture space, so
they stay put on the item instead of sliding around with the camera. Their colour is the one the
game already uses for the enchantment's first magic effect (the colour of its spell light), and
they glow in the dark. The mod removes the vanilla reflective effect itself; no other patch is
needed.

Requirements
------------
- Morrowind with Tribunal and Bloodmoon
- MWSE 2.1 (a recent build; the mod uses mwse.Logger and the built-in MCM)
- MGE XE recommended but not required

Installation
------------
Copy the contents of the archive into your Data Files folder (or install with a mod manager):

    Data Files\MWSE\mods\InscribedEnchantments\...
    Data Files\Meshes\ie\...
    Data Files\Textures\ie\...
    Data Files\Inscribed Enchantments-metadata.toml

No plugin to activate. Works on existing saves.

Compatibility
-------------
- Assetless No Glow and similar no-glow patches: compatible, not required. The mod clones the
  item materials itself and detaches the vanilla sheen from each item on its own. With No Glow
  installed the "Hide vanilla sheen" setting has nothing left to hide, and the MCM says so.
- Mods that recolour magic effects: the glyph tint is read from the live effect record, so
  recoloured effects get recoloured glyphs.
- Texture replacers for the vanilla sheen (magicitem\CAUST*): untouched, and not shown while the
  sheen is hidden.

Settings
--------
All settings are in the Mod Config menu under "Inscribed Enchantments". Changes apply as soon
as the menu closes, no reload needed.

- Settings: show glyphs and hide the vanilla sheen (independent of each other), glyph colour
  (enchantment colour or a fixed one), glyph set (normal, small, sparse versions of both with
  fewer glyphs that light up one or two at a time, and "cracks", a network of hairline cracks
  that glow from one end to the other instead of letters, in a normal and a high resolution
  version), animation speed, whether items animate
  in step or each on its own, and the surface rules: respect existing glow maps, skip distorted
  surfaces, maximum stretch, minimum and maximum glyph height.
- Filters: player only, equipped only, weapons / armor / clothing, enchantment cast types, and
  a "skip meshes containing" text filter.
- Blocked items: per-item and per-plugin exclusions.
- Diagnostics: log level. DEBUG logs every decorated item and, per shape, the stretch and glyph
  height that decided whether it got glyphs.

About glyph height: the glyph textures repeat together with the item's own texture, so a
surface whose texture is stretched over a large area gets large glyphs. The height limits are in
game units (a character is 128 units tall, one unit is about 1.4 cm). On vanilla gear trousers
and gauntlets land at 2-5 units and cuirasses at 4-10; the default maximum of 6.5 drops the
billboard-sized ones.

How it works
------------
For each enchanted item the mod clones the shapes' texturing properties and adds a glow map, an
additive texture in the mesh's own UV coordinates. A NiFlipController cloned from a small
template mesh cycles that map through 192 frames. An animated node, also from the template,
gives the controllers the game's global clock. Dropped and placed items get the layout of an
authored animated NIF, with the geometry under the animated node and the controller on the
shape's property. Worn items keep their geometry where the character animation and the paperdoll
can pose it; there the animated node only carries the controllers. Nothing runs per frame in
Lua. Surfaces whose UV layout would stretch or oversize the glyphs are skipped.

Known limitations
-----------------
- Glyph size and orientation follow each mesh's UV unwrap; mirrored UV islands mirror the glyphs.
- Meshes that already carry a glow map (Daedric and glass gear, for example) are left alone by
  default.
- The 1.5 s flash on doors and containers hit by spells uses the vanilla effect and is unaffected.
- Thrown weapons (darts, stars, knives) are attached by a different engine path and do not get
  glyphs when drawn.
- An enchanted item that a script places into the current cell while you are in it gets its
  glyphs the next time the cell is entered or the settings menu is closed.

Credits
-------
Glyphs are baked from hardek's "Better Daedric Font" (Aligned+XY variant), itself based on
Dongle's Oblivion Worn Daedric font; see "Better Daedric Font.txt" (included as its licence
requires). Built with MWSE.

The mod itself (code, generator and generated assets) is released under the MIT licence; see
LICENSE in the repository at https://github.com/StormAtronach/InscribedEnchantments.
