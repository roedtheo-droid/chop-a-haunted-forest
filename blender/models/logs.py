"""Logs, stumps and the Elder Hollow (see src/server/Systems/LogManager, TreeManager and
BossManager). Each is ONE part: the game sets its Size directly (a log is always
Config.Logs' size, a stump as wide as its tree, a root gets thinner when it's hit), so its
outline is a clean box, with the bark detail inside it.

  Log         a 4 x 1.2 x 1.2 log lying along X, bark ridges along it ("Log"); the game
              paints the light rings on its ends
  Stump       a stump 3 wide and 1.2 tall with bark ridges up its sides ("Stump"); the game
              paints the rings on top
  ElderTrunk  the boss's trunk, 10 x 40 x 10, deep bark ridges ("Trunk")
  ElderCrown  one chunky clump of its crown ("Crown"); the game makes several, in cubes
  ElderRoot   one of its roots, 12 long along X, thinner at its far end (+X), knobbly ("Root")
"""

import random

from lib import palette
from lib.geometry import Piece, bark, box, leaf_clump, place


def _bark_along_x(piece, length, thick, ridges, rng):
    """A square log along X: a core, corner edges and raised ridges on its four sides,
    exactly `length` x `thick` x `thick` outside."""
    core = 0.86
    piece.add(box((length, thick * core, thick * core)))
    post = thick * 0.13
    for sy in (-1, 1):
        for sz in (-1, 1):
            piece.add(box((length, post, post), bevel=post * 0.2), place((0, sy * (thick / 2 - post / 2), sz * (thick / 2 - post / 2))))
    usable = thick - 2 * post
    out = thick * (1 - core) / 2 + thick * 0.02
    for side in range(4):
        for i in range(ridges):
            w = usable / ridges * rng.uniform(0.45, 0.7)
            middle = -usable / 2 + usable / ridges * (i + 0.5)
            offset = thick / 2 - out / 2
            ridge = box((length * rng.uniform(0.92, 1.0), w, out), bevel=min(w, out) * 0.3)
            if side == 0:
                piece.add(ridge, place((0, middle, offset)))
            elif side == 1:
                piece.add(ridge, place((0, middle, -offset)))
            elif side == 2:
                piece.add(ridge, place((0, offset, middle), tilt_x=90))
            else:
                piece.add(ridge, place((0, -offset, middle), tilt_x=90))
    return piece


def log(collection):
    _bark_along_x(Piece("Log", palette.BARK), 4.0, 1.2, 2, random.Random(601)).build(collection)


def stump(collection):
    bark(Piece("Stump", palette.BARK), 3.0, 1.2, ridges=3, rng=random.Random(602)).build(collection)


def elder_trunk(collection):
    bark(Piece("Trunk", palette.DEAD_BARK), 10.0, 40.0, ridges=5, rng=random.Random(603)).build(collection)


def elder_crown(collection):
    leaf_clump(Piece("Crown", palette.DARK_STONE), 10.0, (0, 0, 5.0), turn=10, bumps=3, rng=random.Random(604)).build(collection)


def elder_root(collection):
    rng = random.Random(605)
    root = Piece("Root", palette.DEAD_BARK)
    length, thick = 12.0, 3.0
    # A tapered beam standing along Z, turned to lie along X with its thin end at +X.
    root.add(box((thick, thick, length), bevel=0.3, taper=0.55), place((0, 0, 0), tilt_y=90))
    # Knobs and a little side root, all inside its outline.
    for x in (-3.5, -0.5, 2.0):
        size = rng.uniform(0.9, 1.3)
        root.add(box((size, size, size), bevel=0.2), place((x, rng.uniform(-0.6, 0.6), thick / 2 - size / 2), turn_z=rng.uniform(0, 90)))
    root.add(box((3.0, 0.7, 0.7), bevel=0.1, taper=0.5), place((3.0, -0.9, -0.6), turn_z=-25))
    root.build(collection)
