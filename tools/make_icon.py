"""Generates the app icon PNGs. Run: python3 tools/make_icon.py (requires Pillow)."""
from PIL import Image, ImageChops, ImageDraw

S = 1024
SS = 4  # supersampling
BLUE_TOP, BLUE_BOT = (37, 99, 235), (13, 148, 136)  # #2563EB -> #0D9488
GREEN = (16, 185, 129)


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            px[x, y] = tuple(int(BLUE_TOP[i] + (BLUE_BOT[i] - BLUE_TOP[i]) * t) for i in range(3))
    return img


def glyph(size, scale):
    """Photo card with mountains + sun, and a green 'shrink' badge. Transparent bg."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2

    def p(v):  # design units (0..1024) -> px, scaled around the centre
        return c + (v - 512) * scale * size / S

    # back card (tilted look via offset)
    d.rounded_rectangle([p(250), p(230), p(740), p(690)], radius=60 * scale * size / S,
                        fill=(255, 255, 255, 140))
    # front card
    d.rounded_rectangle([p(290), p(300), p(780), p(760)], radius=60 * scale * size / S,
                        fill=(255, 255, 255, 255))
    # sun
    r = 42 * scale * size / S
    d.ellipse([p(640) - r, p(400) - r, p(640) + r, p(400) + r], fill=(250, 204, 21, 255))
    # mountains
    d.polygon([(p(290), p(760)), (p(450), p(520)), (p(560), p(660)),
               (p(640), p(580)), (p(780), p(760))], fill=(37, 99, 235, 255))
    # clip mountains to card corners by re-masking bottom corners
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle([p(290), p(300), p(780), p(760)],
                                           radius=60 * scale * size / S, fill=255)
    card_only = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    card_only.paste(img, (0, 0), mask)
    # keep back card (outside mask) too
    back = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bd = ImageDraw.Draw(back)
    bd.rounded_rectangle([p(250), p(230), p(740), p(690)], radius=60 * scale * size / S,
                         fill=(255, 255, 255, 140))
    back.alpha_composite(card_only)
    img = back
    d = ImageDraw.Draw(img)
    # badge
    br = 120 * scale * size / S
    bx, by = p(760), p(740)
    d.ellipse([bx - br, by - br, bx + br, by + br], fill=GREEN + (255,),
              outline=(255, 255, 255, 255), width=int(14 * scale * size / S))
    # down arrow
    aw = 52 * scale * size / S
    d.rectangle([bx - 14 * scale * size / S, by - aw, bx + 14 * scale * size / S, by + 10 * scale * size / S],
                fill=(255, 255, 255, 255))
    d.polygon([(bx - aw, by), (bx + aw, by), (bx, by + aw * 1.05)], fill=(255, 255, 255, 255))
    # recentre the glyph (bbox centre is at (565, 545) in design units)
    k = scale * size / S
    img = ImageChops.offset(img, int(round((512 - 565) * k)), int(round((512 - 545) * k)))
    return img


def save(img, path):
    img.resize((S, S), Image.LANCZOS).save(path)


big = S * SS
# Full icon (legacy / iOS-style): gradient square + glyph
full = gradient(big).convert("RGBA")
full.alpha_composite(glyph(big, 1.3))
save(full, "assets/icon/icon.png")
# Adaptive foreground: transparent, glyph shrunk to stay inside the 66% safe zone
save(glyph(big, 1.08), "assets/icon/icon_foreground.png")
save(gradient(big).convert("RGBA"), "assets/icon/icon_background.png")
print("ok")
