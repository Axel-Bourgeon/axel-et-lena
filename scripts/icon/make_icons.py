"""Génère les icônes Android de l'appli (à relancer si le logo change).

Logo : A et L qui partagent un trait, crème, sur un disque en dégradé
horizontal orange → rouille. Sortie dans scripts/android_res/ (copié dans
android/app/src/main/res par patch_android.py).
"""
import pathlib
from PIL import Image, ImageDraw

OUT = pathlib.Path(__file__).resolve().parent.parent / "android_res"
LEFT, RIGHT = (0xD9, 0x70, 0x3A), (0xB5, 0x40, 0x1F)
INK = (0xFF, 0xF4, 0xE0, 255)
SS = 4  # suréchantillonnage pour des bords lisses

# Dessin dans une boîte 200 × 200 (disque centré en (100, 104), rayon 76).
A_L = [(56, 150), (100, 54), (100, 150), (150, 150)]
BAR = [(76, 124), (100, 124)]
STROKE = 19
ZOOM = 0.92  # taille des lettres dans le disque
CX, CY, R = 100, 104, 76


def gradient(w, h, x0, x1):
    img = Image.new("RGBA", (w, h))
    px = img.load()
    for x in range(w):
        t = min(1.0, max(0.0, (x - x0) / max(1, x1 - x0)))
        c = tuple(round(LEFT[i] + (RIGHT[i] - LEFT[i]) * t) for i in range(3)) + (255,)
        for y in range(h):
            px[x, y] = c
    return img


def letters(size, scale, ox, oy, color=INK):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    w = round(STROKE * scale)

    scale *= ZOOM
    # Lettres recentrées dans le disque (boîte 56–150 × 54–150).
    mx, my = (56 + 150) / 2, (54 + 150) / 2

    def pt(p):
        return (ox + (p[0] - mx) * scale, oy + (p[1] - my) * scale)

    for line in (A_L, BAR):
        pts = [pt(p) for p in line]
        for a, b in zip(pts, pts[1:]):
            d.line([a, b], fill=color, width=w)
        for p in pts:  # bouts et angles arrondis
            d.ellipse([p[0] - w / 2, p[1] - w / 2, p[0] + w / 2, p[1] + w / 2], fill=color)
    return img


def legacy(px):
    s = px * SS
    disc = gradient(s, s, 0, s)
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, s - 1, s - 1], fill=255)
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    img.paste(disc, (0, 0), mask)
    img.alpha_composite(letters(s, s / (2 * R), s / 2, s / 2))
    return img.resize((px, px), Image.LANCZOS)


def adaptive(px):
    """Calques 108 dp : seule la zone centrale de 72 dp est visible."""
    s = px * SS
    view = s * 72 / 108
    margin = (s - view) / 2
    bg = gradient(s, s, round(margin), round(s - margin)).resize((px, px), Image.LANCZOS)
    scale = view / (2 * R)
    fg = letters(s, scale, s / 2, s / 2).resize((px, px), Image.LANCZOS)
    mono = letters(s, scale, s / 2, s / 2, (255, 255, 255, 255)).resize((px, px), Image.LANCZOS)
    return bg, fg, mono


DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

for name, k in DENSITIES.items():
    d = OUT / f"mipmap-{name}"
    d.mkdir(parents=True, exist_ok=True)
    legacy(round(48 * k)).save(d / "ic_launcher.png")
    bg, fg, mono = adaptive(round(108 * k))
    bg.save(d / "ic_launcher_background.png")
    fg.save(d / "ic_launcher_foreground.png")
    mono.save(d / "ic_launcher_monochrome.png")

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
# Aperçu grand format pour vérifier le rendu.
legacy(512).save(OUT.parent / "icon" / "preview.png")
print("ok")
