"""Génère les icônes Android de l'appli (à relancer si le logo change).

Source : logo_source.png (dessin d'Axel) : un trait blanc en forme de cœur
sur un disque en dégradé vertical rouille → orange. On en extrait le trait
blanc (en transparence, bords lissés), on recrée le dégradé proprement, puis
on fabrique l'icône classique, l'icône adaptative (fond + premier plan) et la
version monochrome (icônes à thème d'Android 13+). Sortie dans
scripts/android_res/ (copié dans android/app/src/main/res par
patch_android.py).
"""
import math
import pathlib

from PIL import Image, ImageDraw, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
OUT = HERE.parent / "android_res"
SRC = HERE / "logo_source.png"

# Disque de la source (mesuré) et couleurs du dégradé, de haut en bas.
CX, CY, R = 999.5, 982.5, 816.5
TOP, BOTTOM = (207, 82, 48), (245, 153, 68)
# Le trait touche presque le bord du disque : on le réduit un peu pour qu'il
# reste dans la zone visible quelle que soit la forme d'icône du téléphone.
SHRINK = 0.93


def stroke_mask():
    """Masque du trait blanc (0 à 255), carré de côté 2R centré sur le disque."""
    im = Image.open(SRC).convert("RGB")
    px = im.load()
    side = round(2 * R)
    x0, y0 = round(CX - R), round(CY - R)
    mask = Image.new("L", (side, side), 0)
    mp = mask.load()
    for y in range(side):
        sy = y0 + y
        t = y / side
        bg_blue = TOP[2] + (BOTTOM[2] - TOP[2]) * t
        for x in range(side):
            sx = x0 + x
            if math.hypot(x - R, y - R) > R - 2:
                continue
            b = px[sx, sy][2]
            a = (b - bg_blue) / (255 - bg_blue)
            mp[x, y] = max(0, min(255, round(a * 255)))
    # Lissage : flou léger puis contraste, pour gommer les facettes du dessin.
    mask = mask.filter(ImageFilter.GaussianBlur(3))
    mask = mask.point(lambda v: max(0, min(255, round((v - 128) * 3 + 128))))
    # Réduction autour du centre.
    inner = round(side * SHRINK)
    small = mask.resize((inner, inner), Image.LANCZOS)
    out = Image.new("L", (side, side), 0)
    out.paste(small, ((side - inner) // 2, (side - inner) // 2))
    return out


def gradient(w, h, y0, y1):
    img = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = min(1.0, max(0.0, (y - y0) / max(1, y1 - y0)))
        c = tuple(round(TOP[i] + (BOTTOM[i] - TOP[i]) * t) for i in range(3)) + (255,)
        d.line([(0, y), (w, y)], fill=c)
    return img


def white(mask, size):
    m = mask.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(m)
    return img


MASK = stroke_mask()


def legacy(px):
    s = px * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    circle = Image.new("L", (s, s), 0)
    ImageDraw.Draw(circle).ellipse([0, 0, s - 1, s - 1], fill=255)
    img.paste(gradient(s, s, 0, s), (0, 0), circle)
    img.alpha_composite(white(MASK, s))
    return img.resize((px, px), Image.LANCZOS)


def adaptive(px):
    """Calques de 108 dp : le disque visible correspond aux 72 dp du centre."""
    view = round(px * 72 / 108)
    margin = (px - view) // 2
    bg = gradient(px, px, margin, px - margin)
    fg = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    fg.alpha_composite(white(MASK, view), (margin, margin))
    return bg, fg


DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

for name, k in DENSITIES.items():
    d = OUT / f"mipmap-{name}"
    d.mkdir(parents=True, exist_ok=True)
    legacy(round(48 * k)).save(d / "ic_launcher.png")
    bg, fg = adaptive(round(108 * k))
    bg.save(d / "ic_launcher_background.png")
    fg.save(d / "ic_launcher_foreground.png")
    fg.save(d / "ic_launcher_monochrome.png")  # trait blanc : teinté par Android

v26 = OUT / "mipmap-anydpi-v26"
v26.mkdir(parents=True, exist_ok=True)
(v26 / "ic_launcher.xml").write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
    '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
    '    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />\n'
    '</adaptive-icon>\n',
    encoding="utf-8",
)

# Aperçus : grand format, et rendu réel sur un téléphone (cercle et carré
# arrondi, à 48 dp ≈ 144 px sur un écran courant).
legacy(512).save(HERE / "preview.png")
bg, fg = adaptive(432)
full = bg.copy()
full.alpha_composite(fg)
crop = full.crop((72, 72, 360, 360)).resize((144, 144), Image.LANCZOS)
sheet = Image.new("RGBA", (340, 170), (240, 240, 240, 255))
for i, shape in enumerate(("circle", "squircle")):
    m = Image.new("L", (144, 144), 0)
    dm = ImageDraw.Draw(m)
    if shape == "circle":
        dm.ellipse([0, 0, 143, 143], fill=255)
    else:
        dm.rounded_rectangle([0, 0, 143, 143], radius=40, fill=255)
    sheet.paste(crop, (13 + i * 170, 13), m)
sheet.save(HERE / "preview_phone.png")
print("ok")
