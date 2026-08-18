#!/usr/bin/env python3
"""Render the TrueBurn mark to every icon size iOS and Android need.

The geometry is the same bezier data as `lib/splash.dart`. It lives in two places
because nothing can rasterise a Flutter CustomPainter headlessly — so the rule is that
this file and `_MarkPainter` are edited together, and the README says so. Previously
there was no generator checked in at all and the icons could only be reproduced by hand.

Cubics are flattened to polylines and filled with PIL rather than going through an SVG
rasteriser, because that would add a dependency (rsvg / cairo) the rest of this repo
does not have. Everything is drawn at 4x and downsampled, which is what supplies the
antialiasing PIL's polygon fill does not.

    python3 tool/gen_icons.py

Then check the result against launcher masking before shipping — only the inner 66dp of
Android's 108dp adaptive canvas is safe, and iOS applies its own squircle.
"""

import json
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

ACCENT = (14, 107, 91)      # theme.dart light accent, 0xFF0E6B5B
ACCENT_DARK = (70, 192, 164)  # theme.dart dark accent, 0xFF46C0A4
MARK = (255, 255, 255)

# Same numbers as _MarkPainter._outer / ._inner.
OUTER = [
    [0.46, 0.00, 0.52, 0.09, 0.88, 0.28, 0.90, 0.58],
    [0.90, 0.58, 0.91, 0.83, 0.73, 0.99, 0.48, 0.99],
    [0.48, 0.99, 0.23, 0.99, 0.07, 0.83, 0.09, 0.58],
    [0.09, 0.58, 0.08, 0.40, 0.28, 0.38, 0.29, 0.22],
    [0.29, 0.22, 0.30, 0.11, 0.40, 0.06, 0.46, 0.00],
]
INNER = [
    [0.52, 0.42, 0.58, 0.52, 0.72, 0.62, 0.70, 0.76],
    [0.70, 0.76, 0.69, 0.90, 0.58, 0.96, 0.47, 0.96],
    [0.47, 0.96, 0.35, 0.96, 0.27, 0.88, 0.28, 0.76],
    [0.28, 0.76, 0.29, 0.63, 0.46, 0.58, 0.52, 0.42],
]


def flatten(segs, x0, y0, w, h, steps=96):
    """Cubic beziers -> a closed polyline in device pixels."""
    pts = []
    for s in segs:
        p0 = (x0 + s[0] * w, y0 + s[1] * h)
        c1 = (x0 + s[2] * w, y0 + s[3] * h)
        c2 = (x0 + s[4] * w, y0 + s[5] * h)
        p1 = (x0 + s[6] * w, y0 + s[7] * h)
        for i in range(steps + 1):
            t = i / steps
            u = 1 - t
            pts.append((
                u * u * u * p0[0] + 3 * u * u * t * c1[0] + 3 * u * t * t * c2[0] + t * t * t * p1[0],
                u * u * u * p0[1] + 3 * u * u * t * c1[1] + 3 * u * t * t * c2[1] + t * t * t * p1[1],
            ))
    return pts


def draw_mark(size, bg, fg, scale_mark=1.0, transparent=False):
    """The icon at `size` px. `scale_mark` shrinks the art inside the canvas, which is
    what keeps it clear of Android's adaptive-icon mask."""
    ss = 4  # supersample
    s = size * ss
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0) if transparent else bg)
    d = ImageDraw.Draw(im)

    fw = s * 0.50 * scale_mark
    fx = (s - fw) / 2
    fh = fw * 1.22
    # Keep the mark plus its rule vertically centred as it scales, rather than pinned to
    # the 0.14 offset that only balances at full size.
    total = fh + s * 0.060 * scale_mark + s * 0.038 * scale_mark
    fy = (s - total) / 2

    d.polygon(flatten(OUTER, fx, fy, fw, fh), fill=fg)
    # The core is punched by painting the background back over it. That works because an
    # app icon is an opaque square on both platforms — for the transparent notification
    # silhouette it has to be a real hole instead, handled below.
    if transparent:
        core = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        ImageDraw.Draw(core).polygon(flatten(INNER, fx, fy, fw, fh), fill=(0, 0, 0, 255))
        im.paste((0, 0, 0, 0), (0, 0), core)
    else:
        d.polygon(flatten(INNER, fx, fy, fw, fh), fill=bg)

    rw = fw * 0.86
    rh = s * 0.038 * scale_mark
    ry = fy + fh + s * 0.060 * scale_mark
    d.rounded_rectangle([(s - rw) / 2, ry, (s + rw) / 2, ry + rh], radius=rh / 2, fill=fg)

    return im.resize((size, size), Image.LANCZOS)


def ios():
    """One PNG per entry in the generated appiconset, named by its pixel size.

    iOS icons must be fully opaque with no alpha channel — an icon with transparency is
    rejected at upload, and the failure arrives from App Store Connect long after the
    build looks fine locally.
    """
    d = os.path.join(ROOT, "ios/Runner/Assets.xcassets/AppIcon.appiconset")
    meta = json.load(open(os.path.join(d, "Contents.json")))
    for f in os.listdir(d):
        if f.endswith(".png"):
            os.remove(os.path.join(d, f))

    for img in meta["images"]:
        pt = float(img["size"].split("x")[0])
        sc = int(img.get("scale", "1x").rstrip("x"))
        px = int(round(pt * sc))
        name = f"Icon-App-{img['size']}@{img.get('scale', '1x')}.png"
        draw_mark(px, ACCENT, MARK).convert("RGB").save(os.path.join(d, name))
        img["filename"] = name
    json.dump(meta, open(os.path.join(d, "Contents.json"), "w"), indent=2)
    print(f"ios: {len(meta['images'])} icons")


def android():
    """Launcher, adaptive foreground, and the white notification silhouette."""
    res = os.path.join(ROOT, "android/app/src/main/res")
    legacy = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
    for bucket, px in legacy.items():
        m = os.path.join(res, f"mipmap-{bucket}")
        os.makedirs(m, exist_ok=True)
        draw_mark(px, ACCENT, MARK).convert("RGB").save(os.path.join(m, "ic_launcher.png"))
        # Adaptive foreground: transparent, because `@color/brand` is the background
        # layer beneath it — an opaque foreground would show its own square edge through
        # every launcher mask.
        #
        # SIZED AGAINST WHAT IS VISIBLE, NOT AGAINST WHAT IS SAFE. These are different
        # numbers and confusing them is what made the Android icon look zoomed next to
        # the iOS one.
        #
        # The safe zone (66/108 = 0.611) is a MAXIMUM — cross it and a round mask clips
        # the corners. This used to draw at 0.82, putting the ink at 0.60 of the canvas,
        # and called that correct because 0.60 < 0.611. But the launcher only ever shows
        # the inner 72dp, so the visible tile is 72/108 = 0.667 of the canvas: ink at
        # 0.60 of the canvas is 0.60/0.667 = 90% of the tile the user actually sees.
        # Not clipped, and almost edge to edge.
        #
        # iOS puts the mark at 0.71 of its tile and reads correctly. To match that:
        #     canvas fraction = 0.71 * 0.667 = 0.474
        # and the ink measures 0.732 * scale_mark, so scale_mark = 0.474 / 0.732 = 0.65.
        # That also drops the art's diagonal extent from 0.70 to about 0.55, comfortably
        # inside the 0.611 safe circle, so the corners stop being nibbled as well.
        # The adaptive canvas is 108dp where the legacy icon is 48dp.
        fg = px * 108 // 48
        draw_mark(fg, (0, 0, 0), MARK, scale_mark=0.65, transparent=True).save(
            os.path.join(m, "ic_launcher_foreground.png"))

    for bucket, px in {"mdpi": 24, "hdpi": 36, "xhdpi": 48, "xxhdpi": 72, "xxxhdpi": 96}.items():
        d = os.path.join(res, f"drawable-{bucket}")
        os.makedirs(d, exist_ok=True)
        # Android throws away the colour of a notification icon and tints the alpha, so
        # this one must be a white-on-transparent silhouette or it renders as a blob.
        draw_mark(px, (0, 0, 0), MARK, transparent=True).save(
            os.path.join(d, "ic_notification.png"))
    print("android: launcher, adaptive foreground, notification silhouette")


def launch():
    """Launch-screen marks.

    The native launch screen exists only to stop a white flash before Flutter draws —
    it shows the mark on the app's own ground colour, and `lib/splash.dart` then takes
    over with the wordmark. Android already had this; iOS was generated with a plain
    white storyboard, which would have flashed white on a dark-mode phone.
    """
    # Android: the native mark must land at the SAME ON-SCREEN SIZE as
    # `LogoMark(size: 108)` in lib/splash.dart, or the handoff from launch screen to
    # Flutter visibly resizes it and reads as two separate splashes.
    #
    # That takes two different drawables, because the two eras size it differently:
    #
    #  * pre-Android-12 centres the bitmap at its natural density size, so the buckets
    #    below are simply 108dp and the mark fills them.
    #
    #  * Android 12+ ignores windowBackground entirely and draws
    #    `windowSplashScreenAnimatedIcon` into a fixed icon window, **scaling whatever
    #    drawable it is given to fill it**. The bitmap's own pixel size is therefore
    #    irrelevant; the only way to control apparent size is padding inside the image.
    #    Measured on a 420dpi device, that window works out to ~273dp, so the mark has
    #    to occupy 108/273 of the canvas to match Flutter — hence the 0.38 below rather
    #    than a full-bleed 1.0. Getting this wrong is what made the icon jump 2.5x.
    res = os.path.join(ROOT, "android/app/src/main/res")
    buckets = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}
    for bucket, px in buckets.items():
        for night, colour in ((False, ACCENT), (True, ACCENT_DARK)):
            night_q = "-night" if night else ""
            # pre-12: natural size, centred by launch_background.xml
            d = os.path.join(res, f"drawable{night_q}-{bucket}")
            os.makedirs(d, exist_ok=True)
            draw_mark(px, (0, 0, 0), colour, transparent=True).save(
                os.path.join(d, "splash_mark.png"))
            # Android 12+: padded, because the system scales it to its own icon window.
            # Density qualifier precedes the version qualifier.
            d31 = os.path.join(res, f"drawable{night_q}-{bucket}-v31")
            os.makedirs(d31, exist_ok=True)
            draw_mark(px * 2, (0, 0, 0), colour, scale_mark=0.38, transparent=True).save(
                os.path.join(d31, "splash_mark.png"))
    # A density-less original would win over the bucketed ones on some devices.
    for stale in ("drawable/splash_mark.png", "drawable-night/splash_mark.png"):
        f = os.path.join(res, stale)
        if os.path.exists(f):
            os.remove(f)

    ios_d = os.path.join(ROOT, "ios/Runner/Assets.xcassets/LaunchImage.imageset")
    for scale, px in ((1, 108), (2, 216), (3, 324)):
        name = "LaunchImage.png" if scale == 1 else f"LaunchImage@{scale}x.png"
        # Green on transparent: the storyboard supplies the ground colour, so one image
        # serves both appearances.
        draw_mark(px, (0, 0, 0), ACCENT, transparent=True).save(os.path.join(ios_d, name))

    # A named colour with a dark variant, referenced by the storyboard.
    cd = os.path.join(ROOT, "ios/Runner/Assets.xcassets/LaunchBackground.colorset")
    os.makedirs(cd, exist_ok=True)

    def entry(rgb, dark):
        c = {
            "idiom": "universal",
            "color": {
                "color-space": "srgb",
                "components": {
                    "alpha": "1.000",
                    "red": f"0x{rgb[0]:02X}",
                    "green": f"0x{rgb[1]:02X}",
                    "blue": f"0x{rgb[2]:02X}",
                },
            },
        }
        if dark:
            c["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
        return c

    json.dump(
        {
            # theme.dart `ground`: 0xFFF6F8F7 light, 0xFF0E1513 dark.
            "colors": [entry((0xF6, 0xF8, 0xF7), False), entry((0x0E, 0x15, 0x13), True)],
            "info": {"author": "xcode", "version": 1},
        },
        open(os.path.join(cd, "Contents.json"), "w"),
        indent=2,
    )
    print("launch: iOS LaunchImage 1x/2x/3x + LaunchBackground colorset")


def master():
    p = os.path.join(ROOT, "../design/icon-1024.png")
    draw_mark(1024, ACCENT, MARK).convert("RGB").save(p)
    print("master: design/icon-1024.png")


if __name__ == "__main__":
    ios()
    android()
    launch()
    master()
