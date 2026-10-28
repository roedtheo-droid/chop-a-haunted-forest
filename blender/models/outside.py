"""The view outside the forest (see src/server/Systems/SceneryManager.luau): mountain ranges
far away and rolling hills with little trees a bit closer.

  Mountains1-2  a range of chunky peaks, about 150 studs wide: "Mountain" (the rock) and
                "Snow" (caps on the tallest peaks). The game makes them two or three times bigger.
  Hill1-2       a low, rolling hill about 100 studs wide: "Hill" (grass, its edge sunk into the
                ground) and "Grove" (lots of tiny trees on it, all one part so they're cheap)
"""

import random

from lib import palette
from lib.geometry import Piece, box, peak, place, terrain


def _range(collection, seed, peaks):
    """Mountains from `peaks`: (x, y, radius, height, snow) each. They overlap, like a range."""
    rng = random.Random(seed)
    rock = Piece("Mountain", palette.MOUNTAIN)
    snow = Piece("Snow", palette.SNOW)
    for x, y, radius, height, white in peaks:
        lean = (rng.uniform(-0.15, 0.15), rng.uniform(-0.15, 0.15))
        body, cap = peak(radius, height, sides=rng.choice((5, 6)), jitter=0.18, lean=lean, snow=white, rng=rng)
        where = place((x, y, 0))
        rock.add(body, where)
        if cap is not None:
            snow.add(cap, where)
    rock.build(collection)
    snow.build(collection)


def mountains1(collection):
    _range(
        collection,
        151,
        [
            (-40, 4, 30, 55, 0.3),
            (-5, -6, 34, 72, 0.36),
            (32, 6, 28, 50, 0.28),
            (-22, 16, 22, 40, 0.2),
            (14, 18, 22, 36, 0),
            (58, -4, 20, 30, 0),
            (-66, -2, 18, 26, 0),
        ],
    )


def mountains2(collection):
    _range(
        collection,
        152,
        [
            (-55, 0, 26, 45, 0.26),
            (-20, 8, 32, 62, 0.33),
            (18, -4, 36, 80, 0.38),
            (55, 6, 28, 52, 0.3),
            (0, 20, 24, 44, 0.18),
            (80, -2, 16, 24, 0),
            (-82, 2, 16, 22, 0),
        ],
    )


def _hill(collection, seed, width, depth, bumps, trees):
    """A hill whose shape is the sum of `bumps` (x, y, half-width, half-depth, height): round
    domes that run into each other. `trees` little trees stand on its higher parts."""
    rng = random.Random(seed)
    sink = 0.6

    def height_at(x, y):
        total = 0.0
        for bx, by, bw, bd, bh in bumps:
            d = ((x - bx) / bw) ** 2 + ((y - by) / bd) ** 2
            total += bh * max(0.0, 1 - d) ** 0.7
        return total

    Piece("Hill", palette.GRASS_HILL).add(terrain(width, depth, height_at, columns=12, rows=7, sink=sink, rng=rng)).build(collection)

    top = max(bh for *_, bh in bumps)
    grove = Piece("Grove", palette.FAR_TREES)
    placed = 0
    while placed < trees:
        x = rng.uniform(-width / 2, width / 2)
        y = rng.uniform(-depth / 2, depth / 2)
        ground = height_at(x, y) - sink
        if ground < top * 0.2:
            continue  # only on the hill, not at its foot
        placed += 1
        turn = rng.uniform(0, 90)
        if rng.random() < 0.7:
            # A pine: a pointed block.
            w, h = rng.uniform(3.0, 4.2), rng.uniform(6.5, 9.5)
            grove.add(box((w, w, h), taper=0.12), place((x, y, ground + h / 2 - 0.4), turn_z=turn))
        else:
            # A leafy tree: a chunky block.
            w = rng.uniform(3.8, 5.2)
            grove.add(box((w, w, w * 0.85), bevel=w * 0.12), place((x, y, ground + w * 0.6), turn_z=turn))
    grove.build(collection)


def hill1(collection):
    _hill(collection, 161, 90.0, 50.0, [(0, 0, 40, 22, 18), (-24, 6, 22, 14, 7)], 46)


def hill2(collection):
    _hill(collection, 162, 110.0, 46.0, [(-26, 0, 34, 20, 14), (22, -2, 36, 22, 17)], 52)
