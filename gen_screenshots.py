#!/usr/bin/env python3
"""
Aimachi App Store Screenshots  v8
Design: Solid color top + white card (professional designer style)
Story : まんなかへ、3ステップ
"""
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

BASE  = '/Users/sasakikyoutadashi/mannaka'
OUT   = f'{BASE}/appstore_images'
PHOTO = f'{BASE}/photo'

SS = {
    'home':    f'{PHOTO}/Simulator Screenshot - iPhone 16e - 2026-03-29 at 22.48.50.png',
    'search3': f'{PHOTO}/Simulator Screenshot - iPhone 16e - 2026-03-29 at 22.49.26.png',
    'result':  f'{PHOTO}/Simulator Screenshot - iPhone 16e - 2026-03-29 at 22.50.01.png',
    'history': f'{PHOTO}/Simulator Screenshot - iPhone 16e - 2026-03-29 at 22.50.07.png',
    'profile': f'{PHOTO}/Simulator Screenshot - iPhone 16e - 2026-03-29 at 22.50.25.png',
}

BOLD  = '/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc'
SEMI  = '/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc'
REG   = '/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc'
os.makedirs(OUT, exist_ok=True)

# ── Palette ───────────────────────────────────────────────────────────────────
PINK    = (255, 107, 129)
PINK_D  = (210,  40,  72)
CORAL   = (255,  72, 100)
WHITE   = (255, 255, 255)
NAVY    = ( 18,  24,  44)
GRAY    = ( 88,  98, 114)
GRAY_L  = (152, 162, 176)

# ── Canvas ────────────────────────────────────────────────────────────────────
CW, CH = 1290, 2796

# ── iPhone frame ─────────────────────────────────────────────────────────────
PF_W  = 880
PF_H  = int(PF_W * 2.165)   # 1905
PF_CR = 112
PF_BZ = 13
SC_W  = PF_W - PF_BZ * 2    # 854
SC_H  = PF_H - PF_BZ * 2 - 4
SC_CR = PF_CR - PF_BZ
PF_X  = (CW - PF_W) // 2    # 205
PF_Y  = CH - PF_H            # 891

# White card starts here (above phone)
CARD_Y = PF_Y - 88           # 803


def fnt(p, s): return ImageFont.truetype(p, s)


# ── Background: solid top color + white card at bottom ───────────────────────

def make_bg(img, top_col, card_col=(255, 255, 255), decor=None):
    """
    Professional layout:
      top_col  → solid colored area (where headline text lives)
      card_col → rounded card for the phone (white by default)
      decor    → optional list of (cx,cy,r,col,alpha) circles on the top area
    """
    d = ImageDraw.Draw(img)

    # 1. Fill entire bg with top color
    d.rectangle([0, 0, CW, CH], fill=(*top_col, 255))

    # 2. Optional decorative circles on top area
    if decor:
        for cx, cy, r, col, alpha in decor:
            ov = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
            ImageDraw.Draw(ov).ellipse([cx-r, cy-r, cx+r, cy+r], fill=(*col, alpha))
            img.alpha_composite(ov)

    # 3. Card shadow
    sh = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [-30, CARD_Y - 8, CW+30, CH+30], radius=80, fill=(0, 0, 0, 50))
    sh = sh.filter(ImageFilter.GaussianBlur(28))
    img.alpha_composite(sh)

    # 4. White card (rounded top corners only — extend beyond canvas bottom)
    ov2 = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    ImageDraw.Draw(ov2).rounded_rectangle(
        [-30, CARD_Y, CW+30, CH+30], radius=80, fill=(*card_col, 255))
    img.alpha_composite(ov2)


# ── iPhone frame ─────────────────────────────────────────────────────────────

def draw_phone(img, key, crop=None):
    x, y = PF_X, PF_Y

    # Phone shadow
    sh = Image.new('RGBA', (CW, CH), (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle(
        [x+18, y+26, x+PF_W+18, y+PF_H+26], radius=PF_CR, fill=(0, 0, 0, 88))
    sh = sh.filter(ImageFilter.GaussianBlur(44))
    img.alpha_composite(sh)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle([x, y, x+PF_W, y+PF_H], radius=PF_CR, fill=(11, 11, 15))
    d.rounded_rectangle([x, y, x+PF_W, y+PF_H], radius=PF_CR, outline=(36, 38, 46), width=3)

    sx, sy = x + PF_BZ, y + PF_BZ
    ss = Image.open(SS[key]).convert('RGB')
    if crop:
        ow, oh = ss.size
        ss = ss.crop((int(crop[0]*ow), int(crop[1]*oh),
                      int(crop[2]*ow), int(crop[3]*oh)))
    ss = ss.resize((SC_W, SC_H), Image.LANCZOS)

    mask = Image.new('L', (SC_W, SC_H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SC_W, SC_H], radius=SC_CR, fill=255)
    img.paste(ss, (sx, sy), mask)


# ── Text helpers ──────────────────────────────────────────────────────────────

def c_text(d, y, text, font, fill):
    w = d.textlength(text, font=font)
    d.text(((CW-w)//2, y), text, font=font, fill=fill)
    return y + int(font.size * 1.28)

def l_text(d, x, y, text, font, fill):
    d.text((x, y), text, font=font, fill=fill)
    return y + int(font.size * 1.28)

def badge(d, x, y, text, bg, fg=WHITE):
    """Small pill badge (e.g. STEP 1)."""
    f = fnt(SEMI, 38)
    tw = int(d.textlength(text, font=f))
    d.rounded_rectangle([x, y, x+tw+40, y+f.size+18], radius=26, fill=bg)
    d.text((x+20, y+9), text, font=f, fill=fg)
    return y + f.size + 18 + 26


def make(n, fn):
    img = Image.new('RGBA', (CW, CH), WHITE + (255,))
    fn(img)
    p = f'{OUT}/appstore_{n:02d}.png'
    img.convert('RGB').save(p, 'PNG')
    print(f'  {n:02d}  {p}')


# ══════════════════════════════════════════════════════════════════════════════
#  Text area: y = 88 … CARD_Y (803)  →  715 px  (comfortable)
#  Phone:     y = PF_Y (891) … CH (2796)
# ══════════════════════════════════════════════════════════════════════════════

# ── 01  HERO ──────────────────────────────────────────────────────────────────
def c01(img):
    make_bg(img, CORAL, decor=[
        (CW + 160, -200, 720, WHITE, 14),
        (-140, 500, 480, (230, 30, 60), 20),
    ])
    d = ImageDraw.Draw(img)
    y = 92
    y = c_text(d, y, 'Aimachi', fnt(SEMI, 48), (255, 255, 255, 195))
    y += 28
    fh = fnt(BOLD, 138)
    y = c_text(d, y, 'みんなの', fh, WHITE)
    y = c_text(d, y, 'まんなかで', fh, WHITE)
    y = c_text(d, y, '会おう', fh, WHITE)
    y += 22
    c_text(d, y, '出発駅が違っても、一番いい場所に集まれる。', fnt(REG, 52), (255, 255, 255, 215))
    draw_phone(img, 'home')

make(1, c01)


# ── 02  STEP 1：友達の駅を入力 ───────────────────────────────────────────────
def c02(img):
    make_bg(img, (248, 248, 255), decor=[
        (CW + 220, -260, 780, PINK, 10),
    ])
    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'STEP  1', PINK)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, '友達の駅を', fh, NAVY)
    y = l_text(d, M, y, '入れるだけ', fh, NAVY)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, 'それぞれの最寄り駅を入力するだけ。', fs, GRAY)
    l_text(d, M, y, 'GPSで自動入力、最大5名まで対応。', fs, GRAY)
    draw_phone(img, 'search3')

make(2, c02)


# ── 03  STEP 2：シーンとジャンルを選ぶ ──────────────────────────────────────
def c03(img):
    make_bg(img, (255, 240, 246), decor=[
        (-200, CH - 180, 700, PINK, 14),
        (CW + 100, 180, 400, WHITE, 30),
    ])
    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'STEP  2', PINK)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, 'シーンと', fh, NAVY)
    y = l_text(d, M, y, 'ジャンルを選ぶ', fh, NAVY)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, '「ランチ」「女子会」など目的を選ぶと', fs, GRAY)
    l_text(d, M, y, 'ぴったりのお店に自動で絞り込む。', fs, GRAY)
    # Full screenshot, no distortion-causing crop
    draw_phone(img, 'search3')

make(3, c03)


# ── 04  STEP 3：AIが見つける (dark card) ─────────────────────────────────────
def c04(img):
    # Dark theme — no white card, full dark bg
    d0 = ImageDraw.Draw(img)
    for y in range(CH):
        t = y / CH
        c = tuple(int((14,16,36)[i] + ((22,30,64)[i]-(14,16,36)[i])*t) for i in range(3))
        d0.line([(0,y),(CW,y)], fill=(*c,255))
    # Glow
    ov = Image.new('RGBA',(CW,CH),(0,0,0,0))
    for dr in range(580,0,-10):
        a = int(16*(1-dr/580)**2)
        ImageDraw.Draw(ov).ellipse(
            [CW//2-dr, PF_Y+280-dr, CW//2+dr, PF_Y+280+dr], fill=(*PINK, a))
    img.alpha_composite(ov)

    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'STEP  3', PINK)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, 'まんなかの', fh, WHITE)
    y = l_text(d, M, y, 'お店が', fh, WHITE)
    y = l_text(d, M, y, '見つかった', fh, WHITE)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, '移動時間・評価・予約可否を総合判定。', fs, GRAY_L)
    l_text(d, M, y, 'AIがベストなお店をランキング提案。', fs, GRAY_L)
    draw_phone(img, 'result')

make(4, c04)


# ── 05  MAP ───────────────────────────────────────────────────────────────────
def c05(img):
    GRN  = (22, 142, 76)
    SAGE = (204, 244, 220)
    make_bg(img, (214, 246, 228), card_col=(248, 255, 250), decor=[
        (-200, -200, 700, WHITE, 26),
    ])
    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'MAP', GRN)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, '地図で', fh, NAVY)
    y = l_text(d, M, y, 'その場確認', fh, NAVY)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, '全員の出発地と候補のお店が', fs, (50, 90, 68))
    l_text(d, M, y, '地図上に同時に表示される。', fs, (50, 90, 68))
    draw_phone(img, 'home', crop=(0, 0, 1, 0.65))

make(5, c05)


# ── 06  HISTORY ───────────────────────────────────────────────────────────────
def c06(img):
    make_bg(img, (255, 248, 252), decor=[
        (CW + 240, -240, 780, PINK, 9),
    ])
    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'HISTORY', PINK)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, '前回の検索を', fh, NAVY)
    y = l_text(d, M, y, 'すぐ再利用', fh, NAVY)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, 'メンバー・駅・お店をまとめて記録。', fs, GRAY)
    l_text(d, M, y, '次の幹事もこれ一本で完結。', fs, GRAY)
    draw_phone(img, 'history')

make(6, c06)


# ── 07  MY PAGE ───────────────────────────────────────────────────────────────
def c07(img):
    make_bg(img, (240, 238, 255), decor=[
        (CW + 200, CH + 100, 800, (180, 158, 240), 14),
        (-120, 160, 400, WHITE, 28),
    ])
    d = ImageDraw.Draw(img)
    M, y = 88, 92
    y = badge(d, M, y, 'MY PAGE', PINK)
    fh = fnt(BOLD, 150)
    y = l_text(d, M, y, '登録しておくと', fh, NAVY)
    y = l_text(d, M, y, '毎回ラクになる', fh, NAVY)
    y += 22
    fs = fnt(REG, 52)
    y = l_text(d, M, y, 'よく使う駅・人数・シーンを保存。', fs, GRAY)
    l_text(d, M, y, '次からは入力がほぼゼロになる。', fs, GRAY)
    draw_phone(img, 'profile')

make(7, c07)


# ── 08  CTA ───────────────────────────────────────────────────────────────────
def c08(img):
    make_bg(img, (248, 54, 86), decor=[
        (CW + 140, -240, 800, WHITE, 13),
        (-160,  CH - 60, 600, (222, 26, 66), 18),
    ])
    d = ImageDraw.Draw(img)
    y = 92
    y = c_text(d, y, 'Aimachi', fnt(SEMI, 48), (255, 255, 255, 200))
    y += 26
    fh = fnt(BOLD, 146)
    y = c_text(d, y, 'さあ、', fh, WHITE)
    y = c_text(d, y, 'まんなかへ', fh, WHITE)
    y = c_text(d, y, 'はじめよう', fh, WHITE)
    y += 26
    fb = fnt(BOLD, 52)
    btn = 'App Store  無料ダウンロード'
    bw  = int(d.textlength(btn, font=fb)) + 104
    bx  = (CW - bw) // 2
    d.rounded_rectangle([bx, y, bx+bw, y+82], radius=41, fill=WHITE)
    d.text((bx + 52, y + 16), btn, font=fb, fill=PINK_D)
    draw_phone(img, 'result')

make(8, c08)

print(f'\n完了  {OUT}')
