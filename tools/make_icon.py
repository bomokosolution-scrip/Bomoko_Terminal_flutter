from PIL import Image, ImageDraw, ImageFilter, ImageChops
import math

S = 3072          # supersampling canvas
OUT = 1024

def lerp(a, b, t): return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))

def gradient(size, c1, c2, angle=135):
    w, h = size
    g = Image.new("RGB", size)
    px = g.load()
    ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
    mx = abs(ca) * w + abs(sa) * h
    for y in range(h):
        for x in range(w):
            t = ((x - w / 2) * ca + (y - h / 2) * sa) / mx + 0.5
            px[x, y] = lerp(c1, c2, max(0, min(1, t)))
    return g

def small_gradient(c1, c2, angle=135):
    # build at low res then upscale: fast and smooth
    g = gradient((256, 256), c1, c2, angle)
    return g.resize((S, S), Image.BICUBIC)

def stroke_mask(points, width):
    m = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(m)
    d.line(points, fill=255, width=width, joint="curve")
    r = width // 2
    for (x, y) in (points[0], points[-1]):
        d.ellipse((x - r, y - r, x + r, y + r), fill=255)
    return m

def glyph_layer(scale=1.0):
    """Returns RGBA layer (S x S, transparent) with the Bomoko mark."""
    c = S / 2
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))

    def P(x, y):  # coordinates in a 1000 unit box centred
        return (c + (x - 500) * S / 1000 * scale * 0.80, c + (y - 500) * S / 1000 * scale * 0.80)

    w_big = int(150 * S / 1000 * scale * 0.80)
    w_small = int(96 * S / 1000 * scale * 0.80)

    # back chevron (unity: two chevrons moving together)
    back = stroke_mask([P(250, 255), P(525, 500), P(250, 745)], w_small)
    back_col = small_gradient((150, 130, 255), (110, 90, 255), 90)
    back_a = back.point(lambda v: int(v * 0.55))
    layer.paste(back_col, (0, 0), back_a)

    # front chevron with glow
    front = stroke_mask([P(365, 215), P(655, 500), P(365, 785)], w_big)
    glow = front.filter(ImageFilter.GaussianBlur(S * 0.018)).point(lambda v: int(v * 0.65))
    glow_col = Image.new("RGB", (S, S), (45, 212, 255))
    layer.paste(glow_col, (0, 0), glow)
    front_col = small_gradient((255, 255, 255), (120, 232, 255), 120)
    layer.paste(front_col, (0, 0), front)

    # cursor block (amber)
    cur = Image.new("L", (S, S), 0)
    d = ImageDraw.Draw(cur)
    x0, y0 = P(690, 700); x1, y1 = P(880, 770)
    d.rounded_rectangle((x0, y0, x1, y1), radius=int((y1 - y0) / 2), fill=255)
    cur_col = small_gradient((255, 200, 70), (255, 140, 40), 90)
    layer.paste(cur_col, (0, 0), cur)
    return layer

def background():
    bg = small_gradient((16, 22, 56), (74, 46, 190), 135).convert("RGBA")
    # soft light top-left, cyan bloom bottom-right
    lights = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(lights)
    d.ellipse((-S * 0.2, -S * 0.25, S * 0.7, S * 0.55), fill=(140, 120, 255, 95))
    d.ellipse((S * 0.45, S * 0.55, S * 1.2, S * 1.25), fill=(45, 212, 255, 70))
    lights = lights.filter(ImageFilter.GaussianBlur(S * 0.09))
    return Image.alpha_composite(bg, lights)

def down(img): return img.resize((OUT, OUT), Image.LANCZOS)

bg = background()
fg = glyph_layer(scale=0.82)      # adaptive foreground: glyph inside the 66% safe zone

# adaptive layers
down(bg.convert("RGB")).save("assets/icon/icon_bg.png")
down(fg).save("assets/icon/icon_fg.png")

# full legacy icon (rounded corners)
full = Image.alpha_composite(bg, glyph_layer(scale=1.0))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S, S), radius=int(S * 0.225), fill=255)
full.putalpha(mask)
down(full).save("assets/icon/icon.png")
print("ok")
