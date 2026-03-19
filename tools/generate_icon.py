"""
まんなか app icon v8
Design: まんちゃん顔 × ロケーションピン（耳なし・シンメトリー）
- コーラルピンクグラデ背景
- 白いティアドロップ形ピン（中央配置）
- ピン内にまんちゃんの顔（目・ほっぺ・笑顔）
- 突起なし・完全シンメトリー
"""
from PIL import Image, ImageDraw, ImageFilter
import math
import os

SIZE = 1024
OUT  = "assets/icon/app_icon.png"

# Palette
CORAL     = (255, 107, 129, 255)   # #FF6B81
COLLAR    = (212,  80, 112, 255)   # darker coral for depth ring
DARK_EYE  = ( 40,  32,  28, 255)
WHITE     = (255, 255, 255, 255)

img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# ── 1. Gradient background ──────────────────────────────────────────────────
bg = Image.new("RGBA", (SIZE, SIZE))
bd = ImageDraw.Draw(bg)
for y in range(SIZE):
    t = y / SIZE
    r = int(255 * (1 - t) + 212 * t)
    g = int(107 * (1 - t) +  56 * t)
    b = int(129 * (1 - t) +  80 * t)
    bd.line([(0, y), (SIZE, y)], fill=(r, g, b, 255))
img = Image.alpha_composite(img, bg)

cx       = SIZE // 2   # 512
face_cy  = 385         # pin circle center y (slightly above center)
face_r   = 265         # white circle radius
tail_tip = 820         # tip of pin tail y

# ── 2. Drop shadow ──────────────────────────────────────────────────────────
shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
sd = ImageDraw.Draw(shadow)
off = 18
# Shadow for circle part
sd.ellipse([cx - face_r + off, face_cy - face_r + off,
            cx + face_r + off, face_cy + face_r + off], fill=(0, 0, 0, 50))
# Shadow for tail
tail_base_y = face_cy + face_r - 20
steps = 30
for i in range(steps + 1):
    t = i / steps
    hw = 90 * (1 - t) ** 1.5
    y  = tail_base_y + (tail_tip - tail_base_y) * t
    sd.ellipse([cx - hw + off, y - 4 + off, cx + hw + off, y + 4 + off],
               fill=(0, 0, 0, 50))
shadow = shadow.filter(ImageFilter.GaussianBlur(24))
img = Image.alpha_composite(img, shadow)

draw = ImageDraw.Draw(img)

# ── 3. Collar ring (depth effect) ───────────────────────────────────────────
collar_r = face_r + 22
draw.ellipse([cx - collar_r, face_cy - collar_r,
              cx + collar_r, face_cy + collar_r], fill=COLLAR)

# ── 4. White smooth tail polygon ────────────────────────────────────────────
# Tail starts where it meets the circle bottom and narrows to a point
tail_base_y = face_cy + face_r - 20
tail_hw     = 90   # half-width at base

steps = 40
right_pts = []
left_pts  = []
for i in range(steps + 1):
    t   = i / steps
    hw  = tail_hw * (1 - t) ** 1.5
    y   = tail_base_y + (tail_tip - tail_base_y) * t
    right_pts.append((cx + hw, y))
    left_pts.append( (cx - hw, y))

tail_poly = left_pts + list(reversed(right_pts))
draw.polygon(tail_poly, fill=WHITE)

# ── 5. White face circle ────────────────────────────────────────────────────
draw.ellipse([cx - face_r, face_cy - face_r,
              cx + face_r, face_cy + face_r], fill=WHITE)

# ── 6. Eyes ──────────────────────────────────────────────────────────────────
eye_y = face_cy - 50
eye_w = 52
eye_h = 68
lx    = cx - 88
rx    = cx + 88

# Left eye
draw.rounded_rectangle([lx - eye_w // 2, eye_y - eye_h // 2,
                         lx + eye_w // 2, eye_y + eye_h // 2],
                        radius=24, fill=DARK_EYE)
draw.ellipse([lx + 8, eye_y - 26, lx + 24, eye_y - 10],
             fill=(255, 255, 255, 220))

# Right eye
draw.rounded_rectangle([rx - eye_w // 2, eye_y - eye_h // 2,
                         rx + eye_w // 2, eye_y + eye_h // 2],
                        radius=24, fill=DARK_EYE)
draw.ellipse([rx + 8, eye_y - 26, rx + 24, eye_y - 10],
             fill=(255, 255, 255, 220))

# ── 7. Blush cheeks ──────────────────────────────────────────────────────────
blush = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
bl    = ImageDraw.Draw(blush)
br    = 65
bx_l  = cx - 170
bx_r  = cx + 170
by    = face_cy + 60
bl.ellipse([bx_l - br, by - br // 2, bx_l + br, by + br // 2],
           fill=(255, 110, 130, 110))
bl.ellipse([bx_r - br, by - br // 2, bx_r + br, by + br // 2],
           fill=(255, 110, 130, 110))
blush = blush.filter(ImageFilter.GaussianBlur(26))
img   = Image.alpha_composite(img, blush)
draw  = ImageDraw.Draw(img)

# ── 8. Smile ─────────────────────────────────────────────────────────────────
sm_r   = 75
sm_top = face_cy + 60
sm_bot = face_cy + 60 + sm_r
draw.arc([cx - sm_r, sm_top, cx + sm_r, sm_bot],
         start=10, end=170, fill=DARK_EYE, width=12)

# ── 9. Save ───────────────────────────────────────────────────────────────────
os.makedirs(os.path.dirname(OUT), exist_ok=True)
img = img.convert("RGB")
img.save(OUT, "PNG", quality=100)
print(f"Saved {OUT}  ({SIZE}x{SIZE}px)")
