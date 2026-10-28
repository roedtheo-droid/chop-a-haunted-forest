"""Preview colours, the same as STYLE_GUIDE.md and src/shared/Config.luau.
The game paints every part itself (random leaf colours, cursed trees, the mimic tint),
so these only make the preview pictures look like the game."""


def rgb(r, g, b):
    return (r / 255, g / 255, b / 255)


BARK = rgb(120, 75, 45)
ROOT = rgb(102, 64, 38)
BIRCH = rgb(235, 232, 222)
OAK_LEAF = rgb(75, 150, 55)
PINE_LEAF = rgb(58, 127, 51)
BIRCH_LEAF = rgb(95, 165, 60)
STONE = rgb(143, 150, 163)
MOSS = rgb(95, 150, 60)
GRASS_LIGHT = rgb(110, 190, 70)
SAND = rgb(226, 205, 150)
HEDGE = rgb(55, 110, 45)
TWIG = rgb(58, 42, 36)
WALL_STONE = rgb(107, 103, 117)
WOOD = rgb(168, 105, 58)
SIGN = rgb(205, 160, 105)
ROOF = rgb(125, 55, 35)
IRON = rgb(40, 40, 46)
LAMP = rgb(255, 220, 150)
