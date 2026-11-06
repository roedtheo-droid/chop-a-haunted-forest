// The game's colours by name (from STYLE_GUIDE.md and Config.TimberUi). Any `color` prop takes one
// of these names, a "#rrggbb" string or an [r, g, b] list. The game paints the parts itself, so
// these colours show what a model will look like; they don't travel to Roblox as a texture.

export type Rgb = [number, number, number];
export type Color = string | Rgb;

export const palette = {
  bark: [104, 82, 66] as Rgb,
  barkLight: [116, 92, 72] as Rgb,
  barkDark: [80, 60, 47] as Rgb,
  root: [94, 76, 62] as Rgb,
  innerWood: [235, 200, 150] as Rgb,
  rings: [186, 146, 98] as Rgb,
  bone: [240, 232, 205] as Rgb,
  bite: [255, 107, 92] as Rgb,
  tongue: [200, 84, 72] as Rgb,
  gum: [58, 26, 44] as Rgb,
  throat: [26, 20, 42] as Rgb,
  iron: [70, 70, 78] as Rgb,
  ironDark: [40, 40, 46] as Rgb,
  brass: [190, 152, 82] as Rgb,
  amber: [238, 180, 70] as Rgb,
  moss: [112, 138, 92] as Rgb,
  mossLight: [128, 150, 100] as Rgb,
  pine: [70, 104, 76] as Rgb,
  grass: [112, 134, 84] as Rgb,
  dirt: [85, 62, 45] as Rgb,
  plank: [150, 104, 66] as Rgb,
  plankDark: [126, 84, 50] as Rgb,
  edge: [52, 34, 22] as Rgb,
  paper: [232, 220, 190] as Rgb,
  ink: [60, 44, 30] as Rgb,
  berry: [190, 60, 52] as Rgb,
  ghost: [235, 242, 255] as Rgb,
  cursed: [120, 70, 240] as Rgb,
  water: [110, 146, 160] as Rgb,
  mist: [201, 208, 194] as Rgb,
  person: [168, 172, 176] as Rgb,
};

export type PaletteName = keyof typeof palette;

export function resolveColor(color: Color | undefined, fallback: Rgb = palette.bark): Rgb {
  if (!color) return fallback;
  if (Array.isArray(color)) return color;
  const named = palette[color as PaletteName];
  if (named) return named;
  const hex = /^#?([0-9a-f]{6})$/i.exec(color);
  if (hex) {
    const n = parseInt(hex[1], 16);
    return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
  }
  return fallback;
}
