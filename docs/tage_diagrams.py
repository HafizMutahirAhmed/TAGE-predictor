"""Schematic-style SVG diagrams of the TAGE predictor (used by make_tage_doc.py)."""

INK, BLUE, ORANGE, PURPLE, GREEN, RED, GRAY = (
    "#1d2330", "#2457a6", "#c0561f", "#6a4fb3", "#2f7d4f", "#c62828", "#5b6475")


class S:
    """Tiny SVG builder."""

    def __init__(self, w, h):
        self.w, self.h, self.o = w, h, []

    def add(self, s):
        self.o.append(s)

    # ---------------------------------------------------------------- basics
    def rect(self, x, y, w, h, fill="#fff", stroke=INK, rx=4, sw=1.4, dash=False):
        d = ' stroke-dasharray="7,5"' if dash else ""
        self.add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
                 f'stroke="{stroke}" stroke-width="{sw}"{d}/>')

    def text(self, x, y, s, size=11, anchor="start", weight="normal", fill=INK, italic=False, rot=None):
        st = ' font-style="italic"' if italic else ""
        tr = f' transform="rotate({rot} {x} {y})"' if rot is not None else ""
        self.add(f'<text x="{x}" y="{y}" font-size="{size}" text-anchor="{anchor}" '
                 f'font-weight="{weight}" fill="{fill}"{st}{tr}>{s}</text>')

    def wire(self, pts, color=INK, w=1.4, arrow=True, dash=False):
        p = " ".join(f"{x},{y}" for x, y in pts)
        m = f' marker-end="url(#ar_{color[1:]})"' if arrow else ""
        d = ' stroke-dasharray="6,4"' if dash else ""
        self.add(f'<polyline points="{p}" fill="none" stroke="{color}" stroke-width="{w}"'
                 f' stroke-linejoin="round"{m}{d}/>')

    def bus(self, pts, color=INK, arrow=True):
        self.wire(pts, color, 3.2, arrow)

    def dot(self, x, y, color=INK):
        self.add(f'<circle cx="{x}" cy="{y}" r="3.2" fill="{color}"/>')

    def label(self, x, y, s, color=INK, size=9.5, anchor="start"):
        self.text(x, y, s, size, anchor, "normal", color)

    def value(self, x, y, s, anchor="start"):
        self.text(x, y, s, 10, anchor, "bold", RED)

    # ---------------------------------------------------------------- gates
    # all gates point right, height 30, inputs at y+8 / y+22, output at y+15
    def xor(self, x, y, fill="#fff"):
        self.add(f'<path d="M{x+6},{y} Q{x+32},{y} {x+44},{y+15} Q{x+32},{y+30} {x+6},{y+30} '
                 f'Q{x+16},{y+15} {x+6},{y} Z" fill="{fill}" stroke="{INK}" stroke-width="1.4"/>')
        self.add(f'<path d="M{x},{y} Q{x+10},{y+15} {x},{y+30}" fill="none" stroke="{INK}" stroke-width="1.4"/>')
        return (x + 3, y + 8), (x + 3, y + 22), (x + 44, y + 15)

    def xnor(self, x, y):
        a, b, o = self.xor(x, y)
        self.add(f'<circle cx="{x+48}" cy="{y+15}" r="4" fill="#fff" stroke="{INK}" stroke-width="1.4"/>')
        return a, b, (x + 52, y + 15)

    def and_(self, x, y, n_in=2, h=30):
        self.add(f'<path d="M{x},{y} L{x+20},{y} A{h/2},{h/2} 0 0 1 {x+20},{y+h} L{x},{y+h} Z" '
                 f'fill="#fff" stroke="{INK}" stroke-width="1.4"/>')
        ins = [(x, y + h * (i + 1) / (n_in + 1)) for i in range(n_in)]
        return ins, (x + 20 + h / 2, y + h / 2)

    def or_(self, x, y, n_in=2, h=30):
        self.add(f'<path d="M{x},{y} Q{x+30},{y} {x+42},{y+h/2} Q{x+30},{y+h} {x},{y+h} '
                 f'Q{x+10},{y+h/2} {x},{y} Z" fill="#fff" stroke="{INK}" stroke-width="1.4"/>')
        ins = [(x + 4, y + h * (i + 1) / (n_in + 1)) for i in range(n_in)]
        return ins, (x + 42, y + h / 2)

    def inv_bubble(self, x, y):
        self.add(f'<circle cx="{x-4}" cy="{y}" r="4" fill="#fff" stroke="{INK}" stroke-width="1.4"/>')

    def mux(self, x, y, w, h, labels, sel_label=None):
        self.add(f'<path d="M{x},{y} L{x+w},{y+h*0.18} L{x+w},{y+h*0.82} L{x},{y+h} Z" '
                 f'fill="#fff" stroke="{INK}" stroke-width="1.4"/>')
        n = len(labels)
        pins = []
        for i, l in enumerate(labels):
            py = y + h * (i + 1) / (n + 1)
            self.text(x + 4, py + 3.5, l, 8.5)
            pins.append((x, py))
        self.text(x + w / 2 + 2, y + h / 2 + 3, "M", 9, "middle", "bold", GRAY)
        return pins, (x + w, y + h / 2), (x + w / 2, y + h * 0.09)

    def cmp(self, cx, cy, r=14, s="="):
        self.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#fff" stroke="{INK}" stroke-width="1.4"/>')
        self.text(cx, cy + 5, s, 15 if s == "=" else 10, "middle", "bold")

    def clk(self, x, y):
        self.add(f'<path d="M{x},{y-6} L{x+9},{y} L{x},{y+6}" fill="none" stroke="{INK}" stroke-width="1.2"/>')

    def svg(self):
        defs = "".join(
            f'<marker id="ar_{c[1:]}" markerUnits="userSpaceOnUse" markerWidth="10" markerHeight="10" '
            f'refX="9" refY="5" orient="auto"><path d="M0,0 L10,5 L0,10 z" fill="{c}"/></marker>'
            for c in (INK, BLUE, ORANGE, PURPLE, GREEN, RED, GRAY))
        return (f'<svg viewBox="0 0 {self.w} {self.h}" xmlns="http://www.w3.org/2000/svg" '
                f'font-family="DejaVu Sans, Arial, sans-serif"><defs>{defs}</defs>'
                + "".join(self.o) + "</svg>")


# =============================================================================
# Fig. A: complete datapath
# =============================================================================
def fig_datapath():
    s = S(1500, 1075)
    L = [4, 8, 16, 32]
    ys = [60, 170, 280, 390]              # top of T1..T4

    # ---------------- module frame of tage_top
    s.add(f'<path d="M76,36 L1128,36 L1128,700 L1482,700 L1482,1066 L76,1066 Z" fill="none" '
          f'stroke="{BLUE}" stroke-width="1.2" stroke-dasharray="7,5"/>')
    s.text(84, 1058, "tage_top  (Member 3)", 13, weight="bold", fill=BLUE)

    # ---------------- pc_i input trunk
    s.text(4, 318, "pc_i", 12, weight="bold")
    s.text(4, 331, "[31:0]", 9, fill=GRAY)
    s.bus([(4, 337), (40, 337)], arrow=False)
    s.bus([(40, 25), (40, 545)], arrow=False)
    s.dot(40, 337)
    s.bus([(40, 300), (110, 300)])
    s.dot(40, 300)
    s.bus([(40, 545), (420, 545)])
    s.label(300, 539, "pc[11:2]")
    s.bus([(40, 25), (1158, 25), (1158, 40)])
    s.label(560, 19, "pc_i  (saved for the update)")

    # ---------------- tage_hash
    s.rect(110, 60, 200, 440, "#efe9fa", PURPLE)
    s.text(210, 80, "tage_hash", 13, "middle", "bold", PURPLE)
    s.text(210, 93, "Member 2", 9, "middle", fill=PURPLE)
    s.rect(128, 103, 164, 48, "#fff", INK)
    s.clk(128, 140)
    s.text(210, 122, "GHR [31:0]", 11, "middle", "bold")
    s.text(210, 138, "shift register, newest = bit 0", 8.5, "middle", fill=GRAY)
    for i, t in enumerate(["for each table i (L = 4, 8, 16, 32):",
                           "f = xor_fold(GHR[L-1:0])",
                           "idx_i = pc[9:2] XOR f",
                           "tag_i = pc[17:10] XOR rotl(f,1)",
                           "gate level: see Fig. B"]):
        s.text(210, 178 + 15 * i, t, 9.5 if i < 4 else 9, "middle",
               "bold" if i == 0 else "normal", INK if i < 4 else GRAY, italic=(i == 4))
    gx, gy = 192, 258
    a, b, o = s.xor(gx, gy)
    s.wire([(gx - 25, a[1]), a], arrow=False)
    s.wire([(gx - 25, b[1]), b], arrow=False)
    s.wire([o, (o[0] + 20, o[1])], arrow=False)
    s.text(116, 304, "pc", 10)
    s.text(116, 424, "update_en", 9.5)
    s.text(116, 449, "actual_taken", 9.5)
    s.text(116, 474, "clk, rst_n", 9.5, fill=GRAY)
    s.clk(110, 470)

    # ---------------- channels for the update side
    BLUE_X, ORANGE_X, PURP_X = 395, 380, 615
    s.wire([(BLUE_X, 100), (BLUE_X, 985)], BLUE, arrow=False)
    s.wire([(ORANGE_X, 130), (ORANGE_X, 1000)], ORANGE, 1.8, arrow=False)
    s.wire([(PURP_X, 138), (PURP_X, 700)], PURPLE, 1.8, arrow=False)

    # ---------------- tables T1..T4
    for i, y in enumerate(ys, 1):
        s.rect(420, y, 180, 90, "#eef3fb", BLUE)
        s.text(510, y + 42, f"T{i}", 13, "middle", "bold", BLUE)
        s.text(510, y + 57, f"L = {L[i-1]}  ·  256 x 13 bit", 9, "middle", fill=GRAY)
        s.text(426, y + 18, "ra_idx", 9)
        s.text(426, y + 44, "rb_idx", 9, fill=BLUE)
        s.text(426, y + 74, "we, w_*", 9, fill=ORANGE)
        s.clk(420, y + 82)
        for yy, t, c in [(12, "ra_valid", INK), (30, "ra_tag", INK), (62, "ra_ctr", INK), (80, "rb_*", PURPLE)]:
            s.text(594, y + yy + 3.5, t, 9, "end", fill=c)
        # hash -> table index
        s.wire([(310, y + 15), (420, y + 15)], BLUE)
        s.label(316, y + 11, f"idx{i}", BLUE)
        s.text(304, y + 18, f"idx{i}", 8.5, "end", fill=PURPLE)
        s.text(304, y + 103, f"tag{i}", 8.5, "end", fill=PURPLE)
        # update side
        s.wire([(BLUE_X, y + 40), (420, y + 40)], BLUE)
        s.wire([(ORANGE_X, y + 70), (420, y + 70)], ORANGE, 1.8)
        s.dot(BLUE_X, y + 40, BLUE)
        s.dot(ORANGE_X, y + 70, ORANGE)
        s.wire([(600, y + 80), (PURP_X, y + 80)], PURPLE, 1.8, arrow=False)
        if i > 1:
            s.dot(PURP_X, y + 80, PURPLE)

    # ---------------- T0
    s.rect(420, 520, 180, 85, "#eef3fb", BLUE)
    s.text(510, 560, "T0  base", 13, "middle", "bold", BLUE)
    s.text(510, 575, "1024 x 2-bit counters", 9, "middle", fill=GRAY)
    s.text(510, 588, "update read @ update_pc[11:2]", 8, "middle", fill=GRAY)
    s.text(426, 541, "idx", 9)
    s.text(426, 600, "we, w_*", 9, fill=ORANGE)
    s.wire([(ORANGE_X, 596), (420, 596)], ORANGE, 1.8)
    s.dot(ORANGE_X, 596, ORANGE)
    s.text(594, 538, "ctr[1]", 9, "end")
    s.text(594, 600, "ctr", 9, "end", fill=PURPLE)
    s.wire([(600, 596), (PURP_X, 596)], PURPLE, 1.8, arrow=False)
    s.dot(PURP_X, 596, PURPLE)

    # ---------------- tage_predict frame
    s.rect(632, 56, 482, 600, "none", PURPLE, 8, 1.2, dash=True)
    s.text(640, 650, "tage_predict (Member 2)", 11, "start", "bold", PURPLE)

    hit_xv = [860, 865, 870, 875]
    enc_in = [95, 125, 155, 185]
    dir_xv = [805, 800, 795, 790]
    mux_in = []
    # pred mux first so we know its pins
    pins, pred_out, pred_sel = s.mux(830, 468, 38, 120, ["T1", "T2", "T3", "T4", "T0"])
    for i, y in enumerate(ys, 1):
        # tag compare
        cx, cy = 680, y + 30
        s.cmp(cx, cy)
        s.wire([(600, cy), (cx - 14, cy)])
        s.wire([(310, y + 100), (cx, y + 100), (cx, cy + 15)], BLUE)
        # AND with valid
        ins, out = s.and_(720, y + 4)
        s.wire([(600, y + 12), ins[0]])
        s.wire([(cx + 14, cy), (705, cy), (705, ins[1][1]), ins[1]])
        s.label(out[0] + 2, out[1] - 4, f"hit{i}")
        # hit -> encoder
        s.wire([out, (hit_xv[i-1], out[1]), (hit_xv[i-1], enc_in[i-1]), (900, enc_in[i-1])])
        # dir = ctr MSB -> pred mux
        dy = y + 62
        s.wire([(600, dy), (dir_xv[i-1], dy), (dir_xv[i-1], pins[i-1][1]), pins[i-1]])
        s.label(622, dy - 4, f"dir{i} = ctr{i}[2]")
        mux_in.append(pins[i-1])
    s.wire([(600, 534), (720, 534), (720, pins[4][1]), pins[4]])
    s.label(626, 529, "dir0 (T0 MSB)")

    # ---------------- priority encoders
    s.rect(900, 70, 92, 170, "#fff", INK)
    for i, y in enumerate(enc_in, 1):
        s.text(905, y + 3.5, f"hit{i}", 8.5)
    s.text(960, 140, "PRIORITY", 9, "middle", "bold")
    s.text(960, 153, "ENCODER", 9, "middle", "bold")
    s.text(960, 170, "highest hit", 8.5, "middle", fill=GRAY)
    s.text(960, 183, "= provider", 8.5, "middle", fill=GRAY)
    s.rect(900, 272, 92, 120, "#fff", INK)
    s.text(946, 302, "remove prov,", 8.5, "middle")
    s.text(946, 316, "PRIORITY", 9, "middle", "bold")
    s.text(946, 329, "ENCODER", 9, "middle", "bold")
    s.text(946, 346, "= alternate", 8.5, "middle", fill=GRAY)
    s.wire([(930, 240), (930, 272)])
    s.label(934, 258, "hit[4:1]")
    # prov
    s.wire([(992, 155), (1040, 155)])
    s.label(996, 150, "prov[2:0]")
    s.dot(1005, 155)
    s.wire([(1005, 155), (1005, 258), (975, 258), (975, 272)])
    s.dot(1005, 258)
    s.wire([(1005, 258), (1005, 452), (pred_sel[0], 452), pred_sel])
    s.label(870, 446, "sel = prov")
    # alt
    s.wire([(992, 340), (1040, 340)])
    s.label(996, 335, "alt[2:0]")
    s.dot(1022, 340)
    pins2, alt_out, alt_sel = s.mux(940, 498, 38, 110, ["dir", "[4:0]"])
    s.wire([(1022, 340), (1022, 482), (alt_sel[0], 482), alt_sel])
    s.label(965, 477, "sel = alt")
    # dir bus to alt mux
    s.dot(812, pins[0][1])
    s.bus([(812, pins[0][1]), (812, 625), (918, 625), (918, pins2[1][1]), (940, pins2[1][1])], arrow=True)
    s.label(822, 620, "same dir[4:0] bus")
    for p in pins[1:4]:
        s.dot(812, p[1])
    s.dot(812, pins[4][1])
    # mux outputs
    s.wire([alt_out, (1040, alt_out[1])])
    s.label(984, alt_out[1] - 5, "alt_pred")
    s.wire([pred_out, (885, pred_out[1]), (885, 640), (1020, 640), (1020, 600), (1040, 600)])
    s.label(888, 600, "pred")
    s.dot(1020, 640)

    # ---------------- meta concatenation
    s.rect(1040, 60, 62, 585, "#f3f6fb", INK)
    s.text(1076, 350, "meta = { prov, alt, idx[4:1], tag[4:1], pred, alt_pred }   (72 bits)",
           10.5, "middle", "bold", rot=-90)
    s.wire([(300, 60), (300, 48), (1071, 48), (1071, 60)], PURPLE)
    s.label(700, 43, "idx[4:1], tag[4:1] from tage_hash (64 bits)", PURPLE)

    # ---------------- PRED -> UPD register (outside tage_top)
    s.rect(1146, 40, 34, 645, "#fff", INK, 3, 2)
    s.text(1166, 360, "PRED / UPD pipeline register  (nexys7_top: p_pc, p_meta, p_taken, p_tage)",
           10.5, "middle", "bold", rot=-90)
    s.clk(1146, 675)
    s.bus([(1102, 350), (1146, 350)])
    s.text(1104, 340, "meta_o", 9.5, weight="bold")
    s.wire([(1020, 640), (1020, 660), (1146, 660)], INK, 2)
    s.text(1104, 654, "pred_o", 9.5, weight="bold")
    s.wire([(1172, 4), (1172, 40)], GREEN, 2)
    s.text(1178, 12, "taken (real outcome, from hw_trace_gen)", 9.5, fill=GREEN)

    # outputs of the register -> update
    outs = [(150, 1440, "update_valid_i", GREEN), (250, 1380, "update_taken_i", GREEN),
            (350, 1310, "update_pc_i", INK), (450, 1240, "update_meta_i", BLUE)]
    for y, x, name, c in outs:
        s.wire([(1180, y), (x, y), (x, 720)], c, 2.6 if name == "update_meta_i" else 1.8)
        s.text(1186, y - 5, name, 9.5, fill=c, weight="bold")

    # ---------------- tage_update
    s.rect(1190, 720, 255, 220, "#fbf1ee", ORANGE)
    s.text(1318, 760, "tage_update", 13, "middle", "bold", ORANGE)
    s.text(1318, 774, "Member 3 (pure logic, see Fig. C)", 9, "middle", fill=ORANGE)
    for i, t in enumerate(["1  provider ctr +/-1 (or T0 ctr)",
                           "2  u = 1 if pred right, alt wrong",
                           "3  mispredict: allocate in first",
                           "    longer table with u = 0,",
                           "    else clear u of longer tables"]):
        s.text(1210, 800 + 15 * i, t, 9.5)
    s.text(1196, 735, "rd_valid / rd_tag / rd_ctr / rd_u, t0_ctr", 8.5, fill=PURPLE)
    s.wire([(PURP_X, 700), (1170, 700), (1170, 745), (1190, 745)], PURPLE, 1.8)
    s.label(640, 695, "read-back of the entries being updated (table port B)", PURPLE)
    # outputs back to the tables
    s.wire([(1230, 940), (1230, 985), (BLUE_X, 985)], BLUE, 1.6, arrow=False)
    s.label(800, 980, "meta.idx[i] -> rb_idx of every table (read the entry to modify)", BLUE)
    s.wire([(1310, 940), (1310, 1000), (ORANGE_X, 1000)], ORANGE, 1.8, arrow=False)
    s.label(560, 1014, "write ports: t_we, t_waddr, t_wvalid, t_wtag, t_wctr, t_wu,  t0_we, t0_waddr, t0_wctr",
            ORANGE)
    s.text(1236, 935, "idx", 8.5, fill=BLUE)
    s.text(1316, 935, "writes", 8.5, fill=ORANGE)

    # GHR update (green)
    s.dot(1440, 705, GREEN)
    s.wire([(1440, 705), (1462, 705), (1462, 1027), (84, 1027), (84, 420), (110, 420)], GREEN, 1.6)
    s.dot(1380, 695, GREEN)
    s.wire([(1380, 695), (1472, 695), (1472, 1038), (93, 1038), (93, 445), (110, 445)], GREEN, 1.6)
    s.label(560, 1052, "update_valid_i / update_taken_i -> shift the outcome into the GHR (rule 4)", GREEN)

    # legend
    lx, ly = 640, 735
    s.rect(lx, ly, 330, 125, "#fff", GRAY, 4, 1)
    s.text(lx + 10, ly + 18, "Legend", 10, weight="bold")
    for k, (c, t) in enumerate([(INK, "predict path (combinational, cycle A)"),
                                (BLUE, "indices / tags"),
                                (PURPLE, "table read-back for the update (port B)"),
                                (ORANGE, "table writes (clock edge, cycle B)"),
                                (GREEN, "real outcome / GHR update")]):
        s.wire([(lx + 12, ly + 36 + 18 * k), (lx + 50, ly + 36 + 18 * k)], c, 2.2, arrow=False)
        s.text(lx + 58, ly + 40 + 18 * k, t, 9.5)
    s.text(lx + 10, ly + 140, "Thick line = multi-bit bus. Dot = connection. Crossing without dot = no connection.",
           8.5, fill=GRAY)
    return s.svg()


# =============================================================================
# Fig. B: one table, gate level (T3, L = 16), with the worked example values
# =============================================================================
def fig_hash_zoom():
    s = S(1500, 900)
    ghr = 0xB6CE5D36
    # ---------------- GHR bits [15:0]
    cw, x0, y0 = 30, 70, 70
    s.text(x0, y0 - 28, "GHR (32-bit shift register)  -  T3 uses the newest 16 bits, ghr[15:0]", 12, weight="bold")
    s.rect(x0 - 62, y0, 56, 34, "#f3f6fb", GRAY)
    s.text(x0 - 34, y0 + 21, "[31:16]", 9.5, "middle", fill=GRAY)
    for k in range(16):
        bit = 15 - k
        v = (ghr >> bit) & 1
        x = x0 + k * cw
        s.rect(x, y0, cw, 34, "#eef3fb" if bit >= 8 else "#efe9fa", INK, 0, 1.1)
        s.text(x + cw / 2, y0 + 22, str(v), 13, "middle", "bold", RED)
        s.text(x + cw / 2, y0 + 48, str(bit), 8.5, "middle", fill=GRAY)
    s.clk(x0 - 62, y0 + 26)
    # shift in
    s.wire([(x0 + 16 * cw + 60, y0 + 17), (x0 + 16 * cw, y0 + 17)], GREEN, 2)
    s.text(x0 + 16 * cw + 66, y0 + 14, "update_taken_i shifts in at bit 0", 10, fill=GREEN)
    s.text(x0 + 16 * cw + 66, y0 + 28, "(every bit moves one place left)", 9.5, fill=GREEN)

    # byte brackets -> 8 XOR gates (fold)
    hi_c, lo_c = x0 + 4 * cw, x0 + 12 * cw
    s.bus([(hi_c, y0 + 54), (hi_c, 170), (300, 170), (300, 196)], BLUE)
    s.bus([(lo_c, y0 + 54), (lo_c, 185), (330, 185), (330, 196)], PURPLE)
    s.label(hi_c + 6, 165, "ghr[15:8] = 5D", BLUE)
    s.label(lo_c + 6, 180, "ghr[7:0] = 36", PURPLE)
    # 8 parallel XOR gates drawn as a stack
    gx, gy = 285, 200
    s.rect(gx - 12, gy - 6, 120, 290, "#fafbfd", GRAY, 6, 1)
    s.text(gx + 48, gy + 278, "XOR fold: 8 XOR gates", 9.5, "middle", "bold")
    for k in range(8):
        y = gy + 8 + k * 32
        a, b, o = s.xor(gx + 22, y)
        s.wire([(gx + 2, a[1]), a], BLUE, 1, arrow=False)
        s.wire([(gx + 12, b[1]), b], PURPLE, 1, arrow=False)
        s.text(gx + 98, y + 19, f"f[{7-k}]", 8.5)
    s.wire([(gx + 2, gy + 16), (gx + 2, gy + 8 + 7 * 32 + 8)], BLUE, 1, arrow=False)
    s.wire([(gx + 12, gy + 30), (gx + 12, gy + 8 + 7 * 32 + 22)], PURPLE, 1, arrow=False)
    s.text(gx - 16, gy + 120, "bit k of each byte", 8.5, "end", fill=GRAY)
    s.text(gx - 16, gy + 132, "goes to gate k", 8.5, "end", fill=GRAY)

    f = 0x6B
    # f bus out
    s.wire([(gx + 90, 330), (gx + 108, 330)], INK, 1.2, arrow=False)
    s.bus([(gx + 108, 330), (470, 330)], INK, arrow=False)
    s.value(410, 322, "f = 6B")
    s.dot(470, 330)

    # pc input
    s.text(20, 590, "pc_i [31:0]", 12, weight="bold")
    s.value(20, 606, "= 0x00001A3C")
    s.bus([(110, 585), (190, 585)], arrow=False)
    s.bus([(190, 540), (190, 760)], arrow=False)
    s.dot(190, 585)
    s.bus([(190, 540), (500, 540), (500, 418), (520, 418)])
    s.label(200, 535, "pc[9:2] = 8F")
    s.bus([(190, 640), (640, 640), (640, 552), (661, 552)])
    s.label(200, 635, "pc[17:10] = 06")
    s.bus([(190, 760), (360, 760)])
    s.label(200, 755, "pc[11:2] = 28F")
    s.rect(360, 740, 140, 40, "#eef3fb", BLUE)
    s.text(430, 765, "T0 (base)", 11, "middle", "bold", BLUE)

    # XOR idx (8-bit wide)
    a, b, o = s.xor(520, 395)
    s.wire([(470, 330), (470, 403), a])
    s.bus([o, (700, o[1])], BLUE, arrow=True)
    s.text(542, 390, "8-bit XOR", 9, "middle", fill=GRAY)
    s.text(542, 440, "(8 XOR gates)", 8.5, "middle", fill=GRAY)
    s.value(600, o[1] - 7, "idx3 = E4")
    s.text(600, o[1] + 16, "(8F XOR 6B)", 9, fill=RED)

    # rotl: wiring only
    rx, ry = 520, 470
    s.rect(rx, ry, 110, 70, "#fff", INK)
    s.text(rx + 55, ry + 14, "rotl(f, 1)", 9.5, "middle", "bold")
    s.text(rx + 55, ry + 64, "just wires, no gates", 8, "middle", fill=GRAY)
    for k in range(8):
        xa = rx + 13 + k * 12
        xb = rx + 13 + ((k - 1) % 8) * 12
        s.wire([(xa, ry + 20), (xb, ry + 50)], INK, 0.9, arrow=False)
    s.wire([(470, 330), (470, 455), (575, 455), (575, ry)])
    s.wire([(575, ry + 70), (575, 566), (661, 566)], INK, 1.6)
    s.value(480, ry + 100, "rotl(6B) = D6")
    a, b, o = s.xor(660, 544)
    s.bus([o, (760, o[1]), (760, 640), (1000, 640), (1000, 548)], BLUE)
    s.value(770, 632, "tag3 = 06 XOR D6 = D0")
    s.text(682, 590, "8-bit XOR", 9, "middle", fill=GRAY)

    # ---------------- the table
    tx, ty = 705, 230
    s.text(tx, ty - 14, "T3: 256 entries, read at index idx3", 12, weight="bold", fill=BLUE)
    s.rect(tx, ty, 240, 300, "#eef3fb", BLUE)
    cols = [("valid", 46), ("tag[7:0]", 84), ("ctr[2:0]", 66), ("u", 44)]
    rows = [("00", None), ("01", None), ("...", None), ("E3", None), ("E4", (1, "D0", "101", 0)),
            ("E5", None), ("...", None), ("FF", None)]
    hx = tx
    for name, w in cols:
        s.text(hx + w / 2, ty + 17, name, 9, "middle", "bold")
        hx += w
    for r, (addr, data) in enumerate(rows):
        y = ty + 26 + r * 33
        hl = data is not None
        s.rect(tx + 2, y, 236, 28, "#fff3c4" if hl else "#ffffff", RED if hl else "#c5cdd9", 2, 1.6 if hl else 0.8)
        s.text(tx - 6, y + 18, addr, 9, "end", "bold" if hl else "normal", RED if hl else GRAY)
        if hl:
            hx = tx
            for (name, w), v in zip(cols, data):
                s.text(hx + w / 2, y + 19, str(v), 11, "middle", "bold", RED)
                hx += w
    s.wire([(700, 418), (tx + 2, 418)], BLUE, 1.2, arrow=False)
    s.text(tx - 6, ty + 312, "address decoder selects one row (a 256-to-1 multiplexer)", 9, fill=GRAY)
    s.clk(tx, ty + 285)
    s.text(tx + 12, ty + 290, "write port (clock edge)", 8.5, fill=ORANGE)

    # read outputs
    ry0 = ty + 26 + 4 * 33 + 14     # highlighted row centre
    s.wire([(tx + 240, ry0), (980, ry0)], RED, 1.2, arrow=False)
    s.dot(980, ry0, RED)
    ins, out = s.and_(1090, 316, 2, 34)
    # valid
    s.wire([(980, ry0), (980, ins[0][1]), ins[0]])
    s.label(990, ins[0][1] - 5, "valid = 1")
    # stored tag
    s.bus([(980, ry0), (980, 530), (982, 530)], INK, arrow=False)
    s.label(940, 470, "stored", INK)
    s.label(940, 482, "tag = D0", INK)
    # comparator
    s.cmp(1000, 530, 18)
    s.text(1000, 575, "8-bit compare", 9, "middle", fill=GRAY)
    s.text(1000, 587, "(8 XNOR + AND)", 8.5, "middle", fill=GRAY)
    s.wire([(1018, 530), (1060, 530), (1060, ins[1][1]), ins[1]])
    s.label(1025, 525, "equal = 1")
    s.wire([out, (1200, out[1])], INK, 2)
    s.text(1206, out[1] + 4, "hit3", 13, weight="bold")
    s.value(1250, out[1] + 4, "= 1  (T3 hits)")
    # ctr msb
    s.wire([(980, ry0), (1130, ry0), (1130, 420), (1200, 420)], INK, 1.6)
    s.text(1206, 424, "dir3 = ctr[2]", 12, weight="bold")
    s.value(1206, 440, "= 1 (101 -> taken)")

    # explanation
    ex, ey = 1100, 520
    s.rect(ex, ey, 385, 210, "#f3f6fb", GRAY, 6, 1)
    for i, t in enumerate([
            "<tspan font-weight='bold'>What happens, in one clock cycle:</tspan>",
            "1. 16 history bits are cut into 2 bytes; 8 XOR gates",
            "   fold them into one byte f.",
            "2. f XOR pc[9:2] picks the row of T3 (idx3).",
            "3. f is rotated (only wires cross over) and XORed",
            "   with pc[17:10]: the expected tag (tag3).",
            "4. The row is read; its stored tag is compared",
            "   with tag3. hit3 = valid AND equal.",
            "5. The counter's top bit is T3's direction.",
            "The same circuit exists 4 times (L = 4, 8, 16, 32);",
            "only the number of bytes folded differs."]):
        s.text(ex + 12, ey + 22 + 17.5 * i, t, 10)
    s.text(20, 880, "Red numbers: the worked example from chapter 3 (GHR = B6CE5D36, pc = 0x1A3C).",
           10, fill=RED)
    return s.svg()


# =============================================================================
# Fig. C: update logic, gate level
# =============================================================================
def fig_update():
    s = S(1500, 960)

    def panel(x, y, w, h, title):
        s.rect(x, y, w, h, "#fcfcfd", GRAY, 8, 1)
        s.text(x + 12, y + 22, title, 12, weight="bold", fill=ORANGE)

    # ---------------- Rule 1: saturating counter
    panel(20, 20, 700, 420, "Rule 1: saturating counter of the provider (3-bit)")
    s.text(40, 125, "rd_ctr", 11, weight="bold")
    s.text(40, 139, "(current value)", 9, fill=GRAY)
    s.bus([(40, 150), (110, 150)], arrow=False)
    s.bus([(110, 100), (110, 330)], arrow=False)
    s.dot(110, 150)
    # +1
    s.bus([(110, 100), (180, 100)])
    s.cmp(196, 100, 16, "+1")
    s.bus([(212, 100), (300, 100), (300, 118), (330, 118)])
    # =111 check
    s.bus([(110, 175), (180, 175)])
    s.cmp(198, 175, 18, "=111")
    s.wire([(216, 175), (340, 175), (340, 160)])
    pins_a, out_a, sel_a = s.mux(330, 100, 34, 70, ["0", "1"])
    s.wire([(110, 140), (318, 140), (318, pins_a[1][1]), pins_a[1]], INK, 1.4)
    s.label(226, 190, "saturated at 7? keep it")
    pins_t, out_t, sel_t = s.mux(480, 180, 40, 90, ["1", "0"])
    s.bus([out_a, (420, out_a[1]), (420, pins_t[0][1]), pins_t[0]])
    s.label(372, 128, "up")
    # -1
    s.bus([(110, 265), (180, 265)])
    s.cmp(196, 265, 16, "-1")
    s.bus([(212, 265), (300, 265), (300, 283), (330, 283)])
    s.bus([(110, 330), (180, 330)])
    s.cmp(198, 330, 18, "=000")
    s.wire([(216, 330), (347, 330), (347, 325)])
    pins_b, out_b, sel_b = s.mux(330, 265, 34, 70, ["0", "1"])
    s.wire([(110, 305), (318, 305), (318, pins_b[1][1]), pins_b[1]], INK, 1.4)
    s.label(226, 350, "saturated at 0? keep it")
    s.bus([out_b, (440, out_b[1]), (440, pins_t[1][1]), pins_t[1]])
    s.label(372, 293, "down")
    # taken mux (sel = taken: 1 -> up, 0 -> down)
    s.wire([(560, 60), (500, 60), (sel_t[0], sel_t[1])], GREEN, 1.6)
    s.text(565, 64, "taken", 11, weight="bold", fill=GREEN)
    s.bus([out_t, (640, out_t[1])], ORANGE)
    s.text(600, out_t[1] - 10, "w_ctr", 11, weight="bold", fill=ORANGE)
    s.text(40, 395, "Example: ctr = 5 (101), taken -> 6 (110).  ctr = 7, taken -> stays 7.", 10)
    s.text(40, 412, "Written to table 'prov' (we = 1). If prov = 0 the same circuit (2-bit) updates T0.", 10)

    # ---------------- Rule 2: useful bit
    panel(740, 20, 740, 420, "Rule 2: useful bit (u) of the provider")
    s.text(760, 100, "meta.pred", 11, weight="bold")
    s.text(760, 160, "taken", 11, weight="bold", fill=GREEN)
    s.text(760, 250, "meta.alt_pred", 11, weight="bold")
    a, b, o = s.xnor(900, 115)
    s.wire([(840, 96), (870, 96), (870, a[1]), a])
    s.wire([(810, 156), (880, 156), (880, b[1]), b], GREEN)
    s.dot(880, 156, GREEN)
    s.text(915, 165, "XNOR: pred == taken", 9, fill=GRAY)
    s.text(915, 177, "(provider was right)", 9, fill=GRAY)
    a2, b2, o2 = s.xor(900, 230)
    s.wire([(880, 156), (880, a2[1]), a2], GREEN)
    s.wire([(860, 246), (870, 246), (870, b2[1]), b2])
    s.text(915, 280, "XOR: alt_pred != taken", 9, fill=GRAY)
    s.text(915, 292, "(alternate was wrong)", 9, fill=GRAY)
    s.text(760, 340, "prov != 0", 11, weight="bold")
    ins, out = s.and_(1040, 175, 3, 60)
    s.wire([o, (1010, o[1]), (1010, ins[0][1]), ins[0]])
    s.wire([o2, (1010, o2[1]), (1010, ins[1][1]), ins[1]])  # will overlap visually little
    s.wire([(840, 336), (1025, 336), (1025, ins[2][1]), ins[2]])
    s.text(1040, 255, "set_u", 10, weight="bold")
    ins2, out2 = s.or_(1150, 190, 2, 40)
    s.wire([out, (1130, out[1]), (1130, ins2[0][1]), ins2[0]])
    s.text(1150, 270, "rd_u", 11, weight="bold")
    s.wire([(1150, 258), (1140, 258), (1140, ins2[1][1]), ins2[1]])
    s.wire([out2, (1290, out2[1])], ORANGE, 2)
    s.text(1296, out2[1] + 4, "w_u (provider)", 11, weight="bold", fill=ORANGE)
    s.text(760, 395, "u becomes 1 only when the provider made the difference: it was right and the", 10)
    s.text(760, 412, "alternate would have been wrong. Otherwise u keeps its old value.", 10)

    # ---------------- Rule 3: allocation chain
    panel(20, 460, 1460, 480, "Rule 3: allocation after a misprediction (first longer table with u = 0)")
    s.text(40, 525, "meta.pred", 11, weight="bold")
    s.text(40, 565, "taken", 11, weight="bold", fill=GREEN)
    a, b, o = s.xor(140, 525)
    s.wire([(110, 521), (125, 521), (125, a[1]), a])
    s.wire([(85, 561), (125, 561), (125, b[1]), b], GREEN)
    s.text(150, 575, "mispredict", 9, fill=GRAY)
    s.text(40, 615, "prov < 4", 11, weight="bold")
    ins, req = s.and_(230, 535, 2, 40)
    s.wire([o, (215, o[1]), (215, ins[0][1]), ins[0]])
    s.wire([(105, 611), (215, 611), (215, ins[1][1]), ins[1]])
    s.text(262, 538, "alloc_req", 10, weight="bold")
    s.wire([req, (300, req[1]), (300, 900), (1330, 900)], RED, 1.6, arrow=False)
    s.dot(300, req[1], RED)

    # candidates per table
    xs = [420, 650, 880, 1110]
    for j, x in enumerate(xs, 1):
        s.text(x - 20, 520, f"T{j}", 12, weight="bold", fill=BLUE)
        s.text(x - 20, 545, f"j &gt; prov", 10)
        s.text(x - 20, 585, f"rd_u[{j}]", 10)
        ins, out = s.and_(x + 50, 530, 2, 50)
        s.wire([(x + 25, 541), ins[0]])
        s.wire([(x + 30, 581), (x + 40, 581), (x + 40, ins[1][1]), (ins[1][0] - 8, ins[1][1])])
        s.inv_bubble(ins[1][0], ins[1][1])
        s.text(out[0] + 4, out[1] - 6, f"cand{j}", 9.5, weight="bold")
        # priority AND: cand_j and not any earlier cand and alloc_req
        ins2, out2 = s.and_(x + 120, 660, 3, 66)
        s.wire([out, (x + 100, out[1]), (x + 100, ins2[0][1]), ins2[0]])
        s.wire([(x + 110, 900), (x + 110, ins2[2][1]), ins2[2]], RED, 1.4)
        s.dot(x + 110, 900, RED)
        if j > 1:
            oin, oout = s.or_(x + 30, ins2[1][1] - 14 - 6 * (j - 1), j - 1, 28 + 12 * (j - 1))
            for k in range(j - 1):
                s.wire([(x - 2, oin[k][1]), oin[k]], INK, 1, arrow=False)
                s.text(x - 4, oin[k][1] + 3, f"cand{k+1}", 8, "end")
            s.wire([oout, (ins2[1][0] - 8, ins2[1][1])], INK, 1.4, arrow=False)
            s.inv_bubble(ins2[1][0], ins2[1][1])
            s.text(x + 30, ins2[1][1] + 34 + 6 * (j - 1), "a shorter table is free", 8, fill=GRAY)
        else:
            s.text(x + 62, ins2[1][1] + 4, "1", 9)
            s.wire([(x + 72, ins2[1][1]), ins2[1]], INK, 1.2, arrow=False)
        s.wire([out2, (out2[0] + 14, out2[1])], ORANGE, 2)
        s.text(out2[0] - 40, out2[1] + 48, f"alloc{j}", 10.5, weight="bold", fill=ORANGE)
    s.text(420, 800, "alloc_j = 1 -> write {valid=1, tag = meta.tag[j], ctr = taken ? 100 : 011, u = 0} into table j",
           10.5, fill=ORANGE)
    # none free
    ins, out = s.or_(1300, 520, 4, 60)
    s.text(1300, 512, "any cand?", 9.5, fill=GRAY)
    for k in range(4):
        s.wire([(1270, ins[k][1]), ins[k]], INK, 1, arrow=False)
        s.text(1265, ins[k][1] + 3, f"cand{k+1}", 8, "end")
    s.inv_bubble(out[0] + 8, out[1])
    ins3, out3 = s.and_(1360, 610, 2, 40)
    s.wire([(out[0] + 12, out[1]), (1350, out[1]), (1350, ins3[0][1]), ins3[0]])
    s.wire([(1330, 900), (1330, ins3[1][1]), ins3[1]], RED, 1.4)
    s.text(1350, 680, "none free:", 10, weight="bold", fill=ORANGE)
    s.text(1350, 695, "clear u in every", 10, fill=ORANGE)
    s.text(1350, 710, "table j &gt; prov", 10, fill=ORANGE)
    s.wire([out3, (1470, out3[1])], ORANGE, 2)
    s.text(40, 925, "The inverted input (bubble) on each priority gate blocks table j if an earlier (shorter) table "
           "already got the entry, so at most one table is allocated.", 10)
    s.text(40, 860, "Rule 4 (not drawn): the GHR shift register in tage_hash shifts 'taken' in at bit 0.", 10, fill=GREEN)
    return s.svg()
