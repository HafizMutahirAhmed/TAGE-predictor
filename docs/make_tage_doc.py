#!/usr/bin/env python3
"""Builds TAGE_Code_Explained.html (then printed to PDF with Chrome)."""
import html, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tage_diagrams as D

OUT = sys.argv[1]
parts = []
def h(s): parts.append(s)
def code(src, title=None):
    t = f'<div class="ctitle">{html.escape(title)}</div>' if title else ''
    parts.append(f'<div class="code">{t}<pre>{html.escape(src.strip(chr(10)))}</pre></div>')
def note(s, kind="note"):
    parts.append(f'<div class="{kind}">{s}</div>')

CSS = r"""
@page { size: A4; margin: 18mm 16mm 18mm 16mm; }
:root { --ink:#1d2330; --muted:#5b6475; --accent:#2457a6; --accent2:#b0462a; --line:#d7dce5;
        --soft:#f3f6fb; --code:#f6f7f9; --ok:#2f7d4f; }
* { box-sizing: border-box; }
body { font-family: "DejaVu Sans", "Liberation Sans", Arial, sans-serif; color: var(--ink);
       font-size: 10.3pt; line-height: 1.5; margin: 0; background: #fff; }
h1 { font-size: 22pt; color: var(--accent); margin: 0 0 4pt; }
h2 { font-size: 15pt; color: var(--accent); border-bottom: 2px solid var(--accent); padding-bottom: 3pt;
     margin: 0 0 8pt; page-break-after: avoid; }
h3 { font-size: 12pt; color: var(--ink); margin: 14pt 0 5pt; page-break-after: avoid; }
h4 { font-size: 10.5pt; color: var(--accent2); margin: 10pt 0 3pt; page-break-after: avoid; }
p { margin: 0 0 7pt; }
ul, ol { margin: 0 0 7pt 0; padding-left: 18pt; }
li { margin-bottom: 2pt; }
.chapter { page-break-before: always; }
.cover { height: 250mm; display: flex; flex-direction: column; justify-content: center; }
.cover .sub { font-size: 13pt; color: var(--muted); margin-bottom: 18pt; }
.cover .box { border-left: 4px solid var(--accent); padding: 8pt 12pt; background: var(--soft); max-width: 140mm; }
code, .mono { font-family: "DejaVu Sans Mono", "Liberation Mono", monospace; font-size: 9pt;
       background: var(--code); padding: 0 2pt; border-radius: 2pt; }
.code { border: 1px solid var(--line); border-radius: 4pt; margin: 4pt 0 9pt; background: var(--code);
        page-break-inside: avoid; }
.code .ctitle { font-size: 8.5pt; color: var(--muted); padding: 3pt 8pt; border-bottom: 1px solid var(--line);
        font-family: "DejaVu Sans Mono", monospace; }
.code pre { margin: 0; padding: 6pt 8pt; font-family: "DejaVu Sans Mono", "Liberation Mono", monospace;
        font-size: 8.3pt; line-height: 1.38; white-space: pre-wrap; word-break: break-word; }
table { border-collapse: collapse; width: 100%; margin: 4pt 0 10pt; font-size: 9.3pt; page-break-inside: avoid; }
th, td { border: 1px solid var(--line); padding: 3pt 6pt; text-align: left; vertical-align: top; }
th { background: var(--soft); }
.note { border-left: 4px solid var(--accent); background: var(--soft); padding: 6pt 10pt; margin: 6pt 0 10pt;
        page-break-inside: avoid; }
.warn { border-left: 4px solid var(--accent2); background: #fbf1ee; padding: 6pt 10pt; margin: 6pt 0 10pt;
        page-break-inside: avoid; }
.analogy { border-left: 4px solid var(--ok); background: #eef7f1; padding: 6pt 10pt; margin: 6pt 0 10pt;
        page-break-inside: avoid; }
.fig { text-align: center; margin: 6pt 0 10pt; page-break-inside: avoid; }
.fig svg { max-width: 100%; }
.cap { font-size: 8.8pt; color: var(--muted); text-align: center; margin-top: 2pt; }
.toc li { margin-bottom: 1pt; }
.tag { display:inline-block; font-size: 8pt; padding: 0 5pt; border-radius: 8pt; background: var(--accent); color:#fff; }
.tag.m2 { background:#6a4fb3; } .tag.m3 { background:#b0462a; } .tag.m4 { background:#2f7d4f; }
.tag.brd { background:#5b6475; }
.small { font-size: 9pt; color: var(--muted); }
.walk { font-size: 8.8pt; page-break-inside: auto; }
.walk tr { page-break-inside: avoid; }
.walk th.wt { font-family: "DejaVu Sans Mono", monospace; font-size: 8.5pt; color: var(--muted); font-weight: normal; }
.walk td.c { width: 50%; background: var(--code); padding: 3pt 6pt; }
.walk td.c pre { margin: 0; font-family: "DejaVu Sans Mono", "Liberation Mono", monospace; font-size: 7.6pt;
                 line-height: 1.33; white-space: pre-wrap; word-break: break-word; }
.walk td.e { line-height: 1.4; }
.ports { font-size: 8.8pt; }
.ports td:first-child { width: 28%; }
@page wide { size: A4 landscape; margin: 9mm 11mm; }
.landscape { page: wide; page-break-before: always; }
.landscape h2 { font-size: 13pt; margin-bottom: 3pt; }
.landscape .how { font-size: 8.8pt; line-height: 1.35; margin: 0 0 3pt; color: var(--ink); }
.landscape svg { width: 100%; height: 158mm; display: block; }
"""

h(f'<!doctype html><html><head><meta charset="utf-8"><title>TAGE Design and Code</title><style>{CSS}</style></head><body>')

# ============================================================ COVER
h('''<div class="cover">
<h1>The TAGE Branch Predictor:<br>Design and Code</h1>
<div class="sub">A short guide to how the predictor works and what each SystemVerilog file does</div>
<div class="box">
<p><b>Project:</b> TAGE branch predictor in SystemVerilog, running on the Digilent Nexys A7-100T FPGA board.</p>
<p><b>Contents</b></p>
<ol style="margin:0">
<li>How TAGE works</li>
<li>The design: block diagram and schematics (Fig. A, B, C)</li>
<li>Reading the code: a SystemVerilog cheat-sheet</li>
<li>The predictor code, line by line (inputs, outputs and every statement)</li>
<li>The board demo, line by line</li>
<li>Testing and results</li></ol>
</div>
<table style="margin-top:14pt;max-width:140mm"><tr><th>Member</th><th>Files</th></tr>
<tr><td><span class="tag">Member 1</span></td><td>tage_pkg.sv, tage_table.sv</td></tr>
<tr><td><span class="tag m2">Member 2</span></td><td>tage_hash.sv, tage_predict.sv</td></tr>
<tr><td><span class="tag m3">Member 3</span></td><td>tage_update.sv, tage_top.sv</td></tr>
<tr><td><span class="tag m4">Member 4</span></td><td>tage_ref.sv (reference model), testing</td></tr>
<tr><td><span class="tag brd">Board</span></td><td>nexys7_top.sv, trace_rom.sv, branch_trace.mem, perf_counters.sv, seg7_driver.sv</td></tr>
</table></div>''')

# ============================================================ CH1
h('<div class="chapter"><h2>1. How TAGE works</h2>')
h('''<h3>1.1 The problem</h3>
<p>A <b>branch</b> is an <code>if</code> or a loop check in a program: the CPU either jumps (<b>taken</b>) or
continues (<b>not taken</b>). The CPU only knows the answer a few cycles later, so it <b>guesses</b> to keep
working. A wrong guess wastes cycles. A <b>branch predictor</b> makes that guess, using the branch's address
(the <b>PC</b>) and what happened in the past.</p>

<h3>1.2 Building block 1: the saturating counter</h3>''')
h('''<div class="fig"><svg viewBox="0 0 640 120" width="560" xmlns="http://www.w3.org/2000/svg" font-family="DejaVu Sans" font-size="12">
<defs><marker id="ar" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#2457a6"/></marker>
<marker id="ar2" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#b0462a"/></marker></defs>
<g>
<rect x="20" y="40" width="110" height="44" rx="8" fill="#fbf1ee" stroke="#b0462a"/><text x="75" y="58" text-anchor="middle" font-weight="bold">0 (00)</text><text x="75" y="75" text-anchor="middle" font-size="10.5">strongly NOT taken</text>
<rect x="180" y="40" width="110" height="44" rx="8" fill="#fbf1ee" stroke="#b0462a"/><text x="235" y="58" text-anchor="middle" font-weight="bold">1 (01)</text><text x="235" y="75" text-anchor="middle" font-size="10.5">weakly NOT taken</text>
<rect x="340" y="40" width="110" height="44" rx="8" fill="#eef3fb" stroke="#2457a6"/><text x="395" y="58" text-anchor="middle" font-weight="bold">2 (10)</text><text x="395" y="75" text-anchor="middle" font-size="10.5">weakly taken</text>
<rect x="500" y="40" width="110" height="44" rx="8" fill="#eef3fb" stroke="#2457a6"/><text x="555" y="58" text-anchor="middle" font-weight="bold">3 (11)</text><text x="555" y="75" text-anchor="middle" font-size="10.5">strongly taken</text>
<path d="M130,50 L178,50" stroke="#2457a6" fill="none" marker-end="url(#ar)"/><path d="M290,50 L338,50" stroke="#2457a6" fill="none" marker-end="url(#ar)"/><path d="M450,50 L498,50" stroke="#2457a6" fill="none" marker-end="url(#ar)"/>
<path d="M178,76 L132,76" stroke="#b0462a" fill="none" marker-end="url(#ar2)"/><path d="M338,76 L292,76" stroke="#b0462a" fill="none" marker-end="url(#ar2)"/><path d="M498,76 L452,76" stroke="#b0462a" fill="none" marker-end="url(#ar2)"/>
<text x="320" y="22" text-anchor="middle" fill="#2457a6">taken: move right (+1)</text>
<text x="320" y="110" text-anchor="middle" fill="#b0462a">not taken: move left (&#8722;1)</text>
</g></svg><div class="cap">A 2-bit saturating counter. The left bit (the MSB) is the prediction: 0 = not taken, 1 = taken.</div></div>''')
h('''<p>Taken: +1, not taken: &minus;1, but it never goes past the ends. The top bit (MSB) is the prediction.
One surprise doesn't flip it, so a loop that is taken 99 times and then not taken once is still predicted
well. TAGE's tagged tables use the same idea with 3-bit counters (0&ndash;3 = not taken, 4&ndash;7 = taken).</p>

<h3>1.3 Building block 2: global history (GHR)</h3>
<p>Many branches depend on what earlier branches did, e.g. <code>if (x) ... if (x) ...</code>. The
<b>global history register</b> is a 32-bit shift register holding the last 32 outcomes (1 = taken). After
every branch the newest outcome is shifted in at bit 0 and the oldest drops out.</p>
<p>The problem: some branches need only a little history, others need a lot. Too little and you miss the
pattern; too much and learning is slow. <b>TAGE uses several tables, each with a different amount of
history, and picks the best one for each branch.</b></p>

<h3>1.4 The five tables</h3>
<table><tr><th>Table</th><th>Entries</th><th>History used</th><th>Each entry holds</th></tr>
<tr><td><b>T0</b> (base)</td><td>1024</td><td>none (PC only)</td><td>2-bit counter</td></tr>
<tr><td><b>T1</b></td><td>256</td><td>last 4 outcomes</td><td rowspan="4"><b>valid</b>: entry in use?<br>
<b>tag</b> (8 bits): fingerprint of which branch + history owns this entry<br>
<b>ctr</b> (3 bits): prediction counter<br>
<b>u</b>: "useful" bit, protects good entries</td></tr>
<tr><td><b>T2</b></td><td>256</td><td>last 8</td></tr>
<tr><td><b>T3</b></td><td>256</td><td>last 16</td></tr>
<tr><td><b>T4</b></td><td>256</td><td>last 32</td></tr></table>
<p>History lengths 4, 8, 16, 32 double each time (a geometric series). Total storage:
1024&times;2 + 4&times;256&times;13 = <b>15,360 bits</b>.</p>
<p><b>Why tags?</b> Only 256 entries but many more (branch, history) combinations, so several land on the same
entry. The tag is checked on every read: the entry is used only if it is valid <i>and</i> its tag matches
(a <b>hit</b>). Otherwise that table is ignored.</p>

<h3>1.5 The hash: PC + history &rarr; index and tag</h3>''')
code('''f       = xor_fold(ghr[L-1:0], 8)     // squeeze the last L history bits into 8 bits
idx[i]  = pc[9:2]   XOR  f            // which of the 256 entries to read
tag[i]  = pc[17:10] XOR  rotl(f, 1)   // fingerprint to compare with the stored tag''', "Hash for tagged table i (history length L)")
h('''<p><b>XOR fold</b>: cut the history into 8-bit pieces and XOR them together. <b>rotl</b> = rotate left by one bit,
so the index and the tag are different mixes of the same bits. Example: PC = 0x1A3C and GHR = 0xB6CE5D36 give
T3 (L = 16): f = 0x5D ^ 0x36 = 0x6B, idx = 0x8F ^ 0x6B = <b>0xE4</b>, tag = 0x06 ^ 0xD6 = <b>0xD0</b> (Fig. B shows this as gates).</p>

<h3>1.6 Predicting</h3>
<ol><li>Read all five tables at once, each at its own index.</li>
<li><b>Provider</b> = the hitting table with the <b>longest</b> history (T4 &gt; T3 &gt; T2 &gt; T1). No hit &rarr; T0.</li>
<li><b>Prediction</b> = MSB of the provider's counter.</li>
<li><b>Alternate</b> = the second-longest hit (or T0): what we would have predicted without the provider.</li>
<li>Save everything used (provider, alternate, indices, tags, both predictions) in the <b>meta</b> bundle,
a "receipt" so the update knows which entries to change.</li></ol>

<h3>1.7 Learning: the four update rules</h3>
<ol><li><b>Counter:</b> provider's counter +1 if taken, &minus;1 if not (stops at 7 / 0). If the provider was T0, train T0.</li>
<li><b>Useful bit:</b> if the provider was right and the alternate was wrong, set the provider's <code>u = 1</code>.</li>
<li><b>Allocate on a mistake:</b> if the prediction was wrong and the provider is not T4, take the <i>first</i>
longer table whose entry has <code>u = 0</code> and write a new entry there (valid = 1, new tag, counter 4 if taken /
3 if not, u = 0). If all longer entries have <code>u = 1</code>, write nothing but clear their u bits so there is room next time.</li>
<li><b>History:</b> shift the real outcome into the GHR.</li></ol>
<div class="note"><b>The idea in one line:</b> every branch starts in T0; each time it is mispredicted it gets an
entry in a table with more history, so it climbs until it reaches the smallest history that predicts it right.</div>
''')
h('</div>')

# ============================================================ CH2
h('<div class="chapter"><h2>2. The design</h2>')
h('''<p>One branch takes <b>two clock cycles</b>:</p>
<table><tr><th>Cycle</th><th>What happens</th></tr>
<tr><td><b>A: predict</b></td><td><code>pc_i</code> goes in; hash &rarr; table reads &rarr; tag compare &rarr; provider choice, all in
one cycle. <code>pred_o</code> and <code>meta_o</code> come out and are saved in a register.</td></tr>
<tr><td><b>B: update</b></td><td>The real outcome and the saved meta go back in. At the clock edge the tables and the GHR are written.</td></tr></table>''')
h('''<div class="fig"><svg viewBox="0 0 700 400" width="640" xmlns="http://www.w3.org/2000/svg" font-family="DejaVu Sans" font-size="12">
<defs><marker id="a" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#1d2330"/></marker></defs>
<rect x="10" y="10" width="680" height="380" rx="10" fill="none" stroke="#2457a6" stroke-dasharray="5,4"/>
<text x="22" y="30" fill="#2457a6" font-weight="bold">tage_top.sv  (the whole predictor)</text>
<text x="20" y="62" font-weight="bold">pc_i</text><path d="M55,58 L95,58" stroke="#1d2330" marker-end="url(#a)"/>
<rect x="100" y="40" width="160" height="70" rx="6" fill="#efe9fa" stroke="#6a4fb3"/>
<text x="180" y="62" text-anchor="middle" font-weight="bold">tage_hash</text>
<text x="180" y="80" text-anchor="middle" font-size="10.5">owns the 32-bit GHR</text>
<text x="180" y="96" text-anchor="middle" font-size="10.5">computes idx[1..4], tag[1..4]</text>
<rect x="320" y="40" width="200" height="150" rx="6" fill="#eef3fb" stroke="#2457a6"/>
<text x="420" y="60" text-anchor="middle" font-weight="bold">tage_table x 4</text>
<text x="420" y="78" text-anchor="middle" font-size="10.5">T1 (L=4)  T2 (L=8)</text>
<text x="420" y="94" text-anchor="middle" font-size="10.5">T3 (L=16) T4 (L=32)</text>
<text x="420" y="112" text-anchor="middle" font-size="10.5">256 x {valid, tag, ctr, u}</text>
<text x="420" y="134" text-anchor="middle" font-size="10.5">read port A: predict</text>
<text x="420" y="150" text-anchor="middle" font-size="10.5">read port B: update</text>
<text x="420" y="166" text-anchor="middle" font-size="10.5">write port</text>
<rect x="320" y="210" width="200" height="50" rx="6" fill="#eef3fb" stroke="#2457a6"/>
<text x="420" y="231" text-anchor="middle" font-weight="bold">T0 base table</text>
<text x="420" y="248" text-anchor="middle" font-size="10.5">1024 x 2-bit, index pc[11:2]</text>
<path d="M260,75 L318,75" stroke="#1d2330" marker-end="url(#a)"/><text x="270" y="68" font-size="10">idx</text>
<rect x="100" y="290" width="200" height="80" rx="6" fill="#efe9fa" stroke="#6a4fb3"/>
<text x="200" y="312" text-anchor="middle" font-weight="bold">tage_predict</text>
<text x="200" y="330" text-anchor="middle" font-size="10.5">tag compare, pick provider</text>
<text x="200" y="346" text-anchor="middle" font-size="10.5">and alternate, build meta</text>
<path d="M330,190 L250,288" stroke="#1d2330" marker-end="url(#a)"/><text x="215" y="240" font-size="10">valid,tag,ctr</text>
<path d="M330,255 L300,300" stroke="#1d2330" marker-end="url(#a)"/>
<path d="M150,110 L150,288" stroke="#1d2330" marker-end="url(#a)"/><text x="155" y="200" font-size="10">tag (expected)</text>
<path d="M100,330 L40,330" stroke="#1d2330" marker-end="url(#a)"/><text x="20" y="320" font-weight="bold">pred_o</text><text x="20" y="350" font-weight="bold">meta_o</text>
<rect x="560" y="140" width="120" height="120" rx="6" fill="#fbf1ee" stroke="#b0462a"/>
<text x="620" y="162" text-anchor="middle" font-weight="bold">tage_update</text>
<text x="620" y="182" text-anchor="middle" font-size="10.5">ctr +/-1</text>
<text x="620" y="198" text-anchor="middle" font-size="10.5">u = 1 rule</text>
<text x="620" y="214" text-anchor="middle" font-size="10.5">allocate /</text>
<text x="620" y="230" text-anchor="middle" font-size="10.5">clear u</text>
<path d="M560,180 L522,150" stroke="#b0462a" marker-end="url(#a)"/><text x="525" y="140" font-size="10" fill="#b0462a">writes</text>
<path d="M560,240 L522,240" stroke="#b0462a" marker-end="url(#a)"/>
<text x="590" y="330" text-anchor="middle" font-size="10" font-weight="bold">update_valid_i, update_pc_i,</text>
<text x="590" y="345" text-anchor="middle" font-size="10" font-weight="bold">update_taken_i, update_meta_i</text>
<path d="M620,318 L620,262" stroke="#1d2330" marker-end="url(#a)"/>
<path d="M500,326 C 420,330 300,160 262,104" stroke="#6a4fb3" fill="none" stroke-dasharray="4,3" marker-end="url(#a)"/>
<text x="345" y="355" font-size="10" fill="#6a4fb3">taken: shift GHR (dashed)</text>
</svg><div class="cap">Inside tage_top: who talks to whom. Purple = Member 2, blue = Member 1, red = Member 3.</div></div>''')
h('''<table><tr><th>File</th><th>Job</th></tr>
<tr><td><code>tage_pkg.sv</code></td><td>shared constants, the meta type, <code>xor_fold</code> / <code>rotl</code></td></tr>
<tr><td><code>tage_table.sv</code></td><td>one table: 2 read ports + 1 write port</td></tr>
<tr><td><code>tage_hash.sv</code></td><td>GHR + index/tag hash for T1..T4</td></tr>
<tr><td><code>tage_predict.sv</code></td><td>hits, provider, alternate, prediction, meta</td></tr>
<tr><td><code>tage_update.sv</code></td><td>the four rules &rarr; what to write into each table</td></tr>
<tr><td><code>tage_top.sv</code></td><td>the whole predictor: connects all of the above + T0</td></tr></table>''')
h('</div>')
# ============================================================ CIRCUIT DIAGRAMS (landscape)
h('''<div class="landscape"><h2>Fig. A: the complete TAGE datapath</h2>
<p class="how"><b>How to read it:</b> signals flow left to right. <b>Black</b> = the prediction (all in one clock cycle):
pc_i goes into tage_hash, which produces an index and a tag for each table. Each table is read at its index, its stored tag is
compared (<b>=</b>) with the computed tag, and the AND gate gives <i>hit</i>. The priority encoders pick the provider and alternate;
the muxes (<b>M</b>) select their counter MSBs. Everything is packed into <i>meta</i>. The <b>pipeline register</b> keeps pc, meta and
the real outcome for one cycle. Then <span style="color:#c0561f"><b>orange</b></span> = tage_update writes the tables,
<span style="color:#6a4fb3"><b>purple</b></span> = the entries being updated are read back first,
<span style="color:#2f7d4f"><b>green</b></span> = the real outcome is shifted into the GHR.</p>
''' + D.fig_datapath() + '</div>')

h('''<div class="landscape"><h2>Fig. B: inside one table lookup, at gate level (T3, history length 16)</h2>
<p class="how"><b>How to read it:</b> top: the 16 newest history bits (red = the worked example). The two bytes are
XORed bit by bit by 8 XOR gates (the "fold"), giving <b>f</b>. f XOR pc[9:2] (another 8 XOR gates) selects the table row.
f rotated by one place (only wires crossing, no gates) XOR pc[17:10] gives the expected tag. The selected row's stored tag
is compared with it; hit = valid AND equal; the direction is the counter's top bit. T1, T2 and T4 have the same circuit,
folding 4 bits, 1 byte or 4 bytes instead.</p>
''' + D.fig_hash_zoom() + '</div>')

h('''<div class="landscape"><h2>Fig. C: the update logic (tage_update) at gate level</h2>
<p class="how"><b>How to read it:</b> this is all combinational logic that decides <i>what to write</i>; the tables store it at the
next clock edge. <b>Rule 1</b>: the counter is incremented or decremented, but a comparator keeps it from going past 7 or 0; the
<i>taken</i> mux chooses up or down. <b>Rule 2</b>: XNOR/XOR gates check "provider right, alternate wrong" to set u.
<b>Rule 3</b>: on a misprediction, table j is a candidate if it is longer than the provider and its u = 0; the priority gates
(inverted input = bubble) make sure only the <i>first</i> candidate is allocated; if there is no candidate, u is cleared instead.</p>
''' + D.fig_update() + '</div>')

# ============================================================ CH3
def ports(rows):
    t = '<table class="ports"><tr><th>Name</th><th>In / Out</th><th>Bits</th><th>What it carries</th></tr>'
    for n, d, w, m in rows:
        t += f'<tr><td><code>{html.escape(n)}</code></td><td>{d}</td><td>{w}</td><td>{m}</td></tr>'
    h(t + '</table>')
def walk(title, rows):
    t = f'<table class="walk"><tr><th colspan="2" class="wt">{html.escape(title)}</th></tr>'
    for c, e in rows:
        t += f'<tr><td class="c"><pre>{html.escape(c.strip(chr(10)))}</pre></td><td class="e">{e}</td></tr>'
    h(t + '</table>')

h('<div class="chapter"><h2>3. Reading the code: a cheat-sheet</h2>')
h('''<p>Everything you need to read the files. Remember: this code describes <b>hardware</b>. All lines exist at the
same time as wires and flip-flops; they are not run one after another like C.</p>
<table style="page-break-inside:auto"><tr><th style="width:38%">You see</th><th>It means</th></tr>
<tr><td><code>module name ( ... ); ... endmodule</code></td><td>A circuit block. The list in brackets are its pins (ports).</td></tr>
<tr><td><code>input logic [7:0] x</code></td><td>An input pin <code>x</code> that is 8 wires wide (bits 7 down to 0). No <code>[ ]</code> = 1 wire.</td></tr>
<tr><td><code>output logic y</code></td><td>An output pin.</td></tr>
<tr><td><code>logic [7:0] s;</code> / <code>wire</code> / <code>reg</code></td><td>An internal signal (a bundle of wires). <code>wire</code> and <code>reg</code> are older names for the same thing.</td></tr>
<tr><td><code>logic [255:0][2:0] mem;</code></td><td>An array: 256 items of 3 bits each. <code>mem[5]</code> is item number 5.</td></tr>
<tr><td><code>parameter int N = 8</code></td><td>A constant, fixed when the circuit is built. Can be changed per copy of the module.</td></tr>
<tr><td><code>assign a = b &amp; c;</code></td><td>A permanent connection: <code>a</code> always equals <code>b AND c</code>. Pure logic, no clock.</td></tr>
<tr><td><code>always_comb begin ... end</code><br><code>always @* begin ... end</code></td><td>Logic written with if/case/for. Still pure logic (no memory): outputs change as soon as inputs change.</td></tr>
<tr><td><code>always_ff @(posedge clk ...)</code></td><td><b>Flip-flops</b> (memory). The values inside change only at the rising edge of the clock.</td></tr>
<tr><td><code>... or negedge rst_n</code> + <code>if (!rst_n)</code></td><td>Reset: when the reset wire goes to 0, the memory is cleared immediately. <code>_n</code> means "active when 0".</td></tr>
<tr><td><code>a &lt;= b;</code> &nbsp; vs &nbsp; <code>a = b;</code></td><td><code>&lt;=</code> is used for flip-flops (stored at the clock edge). <code>=</code> is used in combinational logic.</td></tr>
<tr><td><code>8'b0000_0011</code>, <code>3'd4</code>, <code>8'hA5</code>, <code>'0</code>, <code>'1</code></td><td>Numbers: bits'base value (b = binary, d = decimal, h = hex). <code>'0</code> = all bits 0, <code>'1</code> = all bits 1.</td></tr>
<tr><td><code>{a, b}</code></td><td>Glue signals side by side into a wider one. <code>{4{1'b1}}</code> = 1111 (repeat).</td></tr>
<tr><td><code>x[9:2]</code> &nbsp; <code>x[2 +: 8]</code></td><td>Pick bits 9 down to 2. <code>+:</code> = "8 bits starting at bit 2" (the same thing).</td></tr>
<tr><td><code>^</code> &nbsp; <code>&amp;</code> &nbsp; <code>|</code> &nbsp; <code>~</code> &nbsp; <code>!</code> &nbsp; <code>&amp;&amp;</code></td><td>XOR, AND, OR, NOT (bitwise), NOT (true/false), logical AND.</td></tr>
<tr><td><code>c ? x : y</code></td><td>A multiplexer: if <code>c</code> then <code>x</code> else <code>y</code>.</td></tr>
<tr><td><code>name #(.P(4)) u_name ( .pin(signal), ... );</code></td><td>Place a copy (instance) of module <code>name</code> called <code>u_name</code>, set its parameter <code>P</code> to 4, and connect its pin <code>pin</code> to our <code>signal</code>.</td></tr>
<tr><td><code>generate for (...)</code></td><td>Build several copies of hardware with a loop (decided when the circuit is built).</td></tr>
<tr><td><code>for</code> inside always blocks</td><td>Not a loop in time: the tool copies the body once per value ("unrolls" it) into parallel hardware.</td></tr>
<tr><td><code>package ... import pkg::*;</code></td><td>A shared file of constants/types, and the line that lets a module use them.</td></tr>
<tr><td><code>typedef struct packed {...} t;</code></td><td>A named bundle of fields stored as one long bit-vector (like a C struct).</td></tr></table>''')
h('</div>')

h('<div class="chapter"><h2>4. The predictor code, file by file</h2>')

# ---------------- tage_pkg
h('<h3>4.1 tage_pkg.sv: shared definitions <span class="tag">Member 1</span></h3>')
h('<p><b>Job:</b> holds the numbers and types that every other file uses. It has no inputs or outputs and builds no hardware by itself.</p>')
walk("rtl/tage_pkg.sv", [
("package tage_pkg;", "Start of the shared package. Other files use it with <code>import tage_pkg::*;</code>"),
("parameter int NUM_T       = 4;", "There are 4 tagged tables (T1..T4)."),
("parameter int HIST_LEN[4] = '{4, 8, 16, 32};", "How many history bits each tagged table uses: T1 = 4, T2 = 8, T3 = 16, T4 = 32."),
("parameter int IDX_W       = 8;", "An index into a tagged table is 8 bits, so each tagged table has 2<sup>8</sup> = 256 entries."),
("parameter int TAG_W       = 8;", "Each stored tag is 8 bits."),
("parameter int CTR_W       = 3;", "Each tagged counter is 3 bits (values 0..7)."),
("parameter int BASE_IDX_W  = 10;", "T0's index is 10 bits, so T0 has 2<sup>10</sup> = 1024 entries."),
("""typedef struct packed {
  logic [2:0]      prov;
  logic [2:0]      alt;
  logic [4:1][7:0] idx;
  logic [4:1][7:0] tag;
  logic            pred;
  logic            alt_pred;
} tage_meta_t;""", """Defines the <b>meta</b> bundle (the "receipt" of a prediction), 72 bits in total:<br>
<code>prov</code>: which table gave the prediction (0 = T0, 1..4 = T1..T4)<br>
<code>alt</code>: the alternate table<br>
<code>idx[1..4]</code>: the 4 table indices that were used<br>
<code>tag[1..4]</code>: the 4 tags that were computed<br>
<code>pred</code>: the prediction (1 = taken)<br>
<code>alt_pred</code>: what the alternate table predicted"""),
("""function automatic [7:0] xor_fold(
    input logic [31:0] data, input int length);
  logic [7:0] folded;
  folded = '0;""", "A helper that squeezes the first <code>length</code> bits of <code>data</code> into 8 bits. Starts with 8 zeros."),
("""  for (int i = 0; i < length; i++) begin
    folded[i % 8] ^= data[i];
  end
  return folded;""", "For every history bit i: XOR it into output bit <code>i % 8</code> (the remainder of i / 8). So bits 0, 8, 16, 24 all land on output bit 0, bits 1, 9, 17, 25 on bit 1, and so on. In hardware this is just XOR gates."),
("""function automatic [7:0] rotl(
    input logic [7:0] val, input int shift);
  logic [15:0] dbl;
  dbl = {val, val} << (shift % 8);
  return dbl[15:8];""", "Rotate an 8-bit value left. Two copies are glued together (16 bits) and shifted left; the top 8 bits are then the rotated value (bits that fall off the left come back on the right). <code>rotl(1000_0001, 1) = 0000_0011</code>."),
])

# ---------------- tage_table
h('<h3>4.2 tage_table.sv: one predictor table <span class="tag">Member 1</span></h3>')
h('<p><b>Job:</b> a memory of 256 entries, each <code>{valid, tag, ctr, u}</code>. It can show two entries at the same time (read ports A and B) and change one entry per clock (write port). T1..T4 are 4 copies of this module.</p>')
ports([
("clk", "in", "1", "the clock"),
("rst_n", "in", "1", "reset: 0 = clear the whole table"),
("ra_idx", "in", "8", "<b>Port A</b> (predict): which entry to look at"),
("ra_valid, ra_tag, ra_ctr, ra_u", "out", "1, 8, 3, 1", "the contents of entry <code>ra_idx</code>"),
("rb_idx", "in", "8", "<b>Port B</b> (update): which entry to look at"),
("rb_valid, rb_tag, rb_ctr, rb_u", "out", "1, 8, 3, 1", "the contents of entry <code>rb_idx</code>"),
("we", "in", "1", "write enable: 1 = write at the next clock edge"),
("w_idx", "in", "8", "which entry to write"),
("w_valid, w_tag, w_ctr, w_u", "in", "1, 8, 3, 1", "the new contents for that entry"),
])
walk("rtl/tage_table.sv: parameters", [
("""module tage_table #(
  parameter int IDX_W = 8,
  parameter int TAG_W = 8,
  parameter int CTR_W = 3,""", "Sizes of the table, with default values. <code>tage_top</code> uses the defaults."),
("parameter logic [CTR_W-1:0] CTR_INIT = {1'b0, {(CTR_W-1){1'b1}}},", "Counter value after reset: a 0 followed by ones = <code>011</code> = 3 = \"weakly not taken\"."),
("localparam int TW = (TAG_W > 0) ? TAG_W : 1", "Width of the tag pins. A pin cannot be 0 bits wide, so if the table has no tag (TAG_W = 0) it is 1 bit and unused."),
("localparam int DEPTH = 1 << IDX_W;", "Number of entries: 1 shifted left 8 times = 256."),
])
walk("rtl/tage_table.sv: the counters", [
("logic [DEPTH-1:0][CTR_W-1:0] ctr_mem;", "The counter memory: 256 counters of 3 bits."),
("always_ff @(posedge clk or negedge rst_n) begin", "Flip-flops: change at the clock edge, or immediately when reset goes to 0."),
("""  if (!rst_n) begin
    for (int k = 0; k < DEPTH; k++)
      ctr_mem[k] <= CTR_INIT;""", "During reset: set <b>all 256</b> counters to 011."),
("""  end else if (we) begin
    ctr_mem[w_idx] <= w_ctr;
  end""", "Otherwise, if write enable is 1: entry number <code>w_idx</code> gets the new counter <code>w_ctr</code>. All other entries keep their value."),
("""assign ra_ctr = ctr_mem[ra_idx];
assign rb_ctr = ctr_mem[rb_idx];""", "Reading: port A always shows the counter at <code>ra_idx</code>, port B the counter at <code>rb_idx</code>. This is a big multiplexer, no clock: the output changes as soon as the index changes."),
])
walk("rtl/tage_table.sv: valid, tag and u bits", [
("""generate
  if (TAG_W > 0) begin : g_tagged""", "Only if the table has tags (true for T1..T4), build the following hardware. Decided when the circuit is built."),
("""logic [DEPTH-1:0]         valid_mem;
logic [DEPTH-1:0]         u_mem;
logic [DEPTH-1:0][TW-1:0] tag_mem;""", "256 valid bits, 256 useful bits, 256 tags of 8 bits."),
("""always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    for (int k = 0; k < DEPTH; k++) begin
      valid_mem[k] <= 1'b0;
      u_mem[k]     <= 1'b0;
      tag_mem[k]   <= '0;
    end""", "Reset: every entry becomes empty (valid = 0, u = 0, tag = 0)."),
("""  end else if (we) begin
    valid_mem[w_idx] <= w_valid;
    u_mem[w_idx]     <= w_u;
    tag_mem[w_idx]   <= w_tag;
  end""", "Write: same as the counter: the entry at <code>w_idx</code> gets the new valid, u and tag. So one write changes the whole entry {valid, tag, ctr, u} at once."),
("""assign ra_valid = valid_mem[ra_idx];
assign ra_tag   = tag_mem[ra_idx];
assign ra_u     = u_mem[ra_idx];
assign rb_valid = valid_mem[rb_idx];  ...""", "Read ports A and B for valid, tag and u, the same way as the counter."),
("""end else begin : g_base
  assign ra_valid = 1'b1;
  assign ra_tag   = '0;
  assign ra_u     = 1'b0;  ...""", "If the table has no tags (TAG_W = 0, a base table): no memory is built for them. Valid always reads 1, tag 0, u 0."),
])

# ---------------- tage_hash
h('<h3>4.3 tage_hash.sv: history register and hash <span class="tag m2">Member 2</span></h3>')
h('<p><b>Job:</b> stores the global history (GHR) and computes, for T1..T4, which entry to read (<code>idx</code>) and which tag to expect (<code>tag</code>).</p>')
ports([
("clk, rst_n", "in", "1, 1", "clock and reset"),
("pc", "in", "32", "address of the branch being predicted"),
("idx", "out", "32", "4 indices glued together: bits 7..0 = T1, 15..8 = T2, 23..16 = T3, 31..24 = T4"),
("tag", "out", "32", "4 expected tags, same order"),
("update_en", "in", "1", "1 = a branch finished: shift its outcome into the history"),
("actual_taken", "in", "1", "the real outcome of that branch (1 = taken)"),
])
walk("rtl/tage_hash.sv", [
("""localparam GHR_W      = 32;
localparam FOLD_W     = 8;
localparam PC_IDX_LSB = 2;
localparam PC_TAG_LSB = PC_IDX_LSB + IDX_W;""", "Constants: history is 32 bits, folds are 8 bits, the index uses PC bits starting at bit 2 (<code>pc[9:2]</code>), the tag uses PC bits starting at bit 10 (<code>pc[17:10]</code>). Bits 1..0 are skipped because instructions are 4 bytes apart, so they are always 0."),
("reg [GHR_W-1:0] ghr;", "The 32-bit global history register."),
("""always @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    ghr <= {GHR_W{1'b0}};""", "Reset: history = 32 zeros."),
("""  else if (update_en)
    ghr <= {ghr[GHR_W-2:0], actual_taken};""", "When a branch finishes: keep bits 30..0, move them one place left, put the new outcome at bit 0. The oldest bit (31) drops out. So <code>ghr[0]</code> is always the newest outcome."),
("""function [FOLD_W-1:0] xor_fold(input [GHR_W-1:0] h,
                               input integer len);
  ...
  for (b = 0; b < GHR_W; b = b + 1)
    if (b < len)
      xor_fold[b % FOLD_W] = xor_fold[b % FOLD_W] ^ h[b];""", "Member 2's own copy of the fold (same result as the package one): XOR history bit b into output bit b % 8, for the first <code>len</code> bits."),
("""wire [FOLD_W-1:0] fold1 = xor_fold(ghr, HIST_LEN_1);
wire [FOLD_W-1:0] fold2 = xor_fold(ghr, HIST_LEN_2);
wire [FOLD_W-1:0] fold3 = xor_fold(ghr, HIST_LEN_3);
wire [FOLD_W-1:0] fold4 = xor_fold(ghr, HIST_LEN_4);""", "Four 8-bit summaries of the history: of the last 4, 8, 16 and 32 outcomes. Each one becomes a fixed tree of XOR gates (Fig. B)."),
("""wire [IDX_W-1:0] pc_idx = pc[PC_IDX_LSB +: IDX_W];
wire [TAG_W-1:0] pc_tag = pc[PC_TAG_LSB +: TAG_W];""", "Take 8 PC bits for the index (<code>pc[9:2]</code>) and the next 8 for the tag (<code>pc[17:10]</code>)."),
("""assign idx = { pc_idx ^ fold4,
               pc_idx ^ fold3,
               pc_idx ^ fold2,
               pc_idx ^ fold1 };""", "The 4 indices: PC bits XOR the fold of each table. Glued together, T4 on the left (top bits), T1 on the right."),
("""assign tag = { pc_tag ^ {fold4[FOLD_W-2:0], fold4[FOLD_W-1]},
               ... ,
               pc_tag ^ {fold1[FOLD_W-2:0], fold1[FOLD_W-1]} };""", "The 4 tags: PC tag bits XOR the fold rotated left by 1. <code>{f[6:0], f[7]}</code> moves bit 7 to the right end, which is the rotation (just wires crossing, no gates)."),
("""// synthesis translate_off
initial begin
  if (IDX_W != FOLD_W ...) $display("ERROR ...");
...
// synthesis translate_on""", "Simulation only, not hardware: prints an error if someone sets wrong sizes."),
])

# ---------------- tage_predict
h('<h3>4.4 tage_predict.sv: making the prediction <span class="tag m2">Member 2</span></h3>')
h('<p><b>Job:</b> pure logic (no clock, no memory). Looks at what the tables returned, finds which tables hit, picks the provider and alternate, and outputs the prediction and the meta bundle.</p>')
ports([
("t0_ctr_msb", "in", "1", "top bit of T0's counter = T0's prediction"),
("t_valid", "in", "4", "valid bit read from T1..T4 (port A)"),
("t_tag", "in", "32", "stored tags read from T1..T4 (8 bits each)"),
("t_ctr", "in", "12", "counters read from T1..T4 (3 bits each)"),
("t_u", "in", "4", "useful bits (not used here; kept so the ports match the plan)"),
("hash_idx, hash_tag", "in", "32, 32", "the indices and expected tags from <code>tage_hash</code>"),
("pred", "out", "1", "the prediction: 1 = taken"),
("meta", "out", "72", "the receipt: {prov, alt, idx, tag, pred, alt_pred}"),
])
walk("rtl/tage_predict.sv", [
("""function [2:0] highest_hit(input [4:1] v);
  casez (v)
    4'b1???: highest_hit = 3'd4;
    4'b01??: highest_hit = 3'd3;
    4'b001?: highest_hit = 3'd2;
    4'b0001: highest_hit = 3'd1;
    default: highest_hit = 3'd0;
  endcase""", "Given 4 hit bits (T4..T1), return the number of the highest table that hit. <code>?</code> means \"don't care\". If T4 hit, answer 4 whatever the others are; else if T3 hit, 3; and so on; if none hit, 0 (= T0). In hardware this is a <b>priority encoder</b>."),
("""reg [4:1] hit;
reg [4:1] hit_below;
reg [4:0] dir;""", "<code>hit[t]</code>: did table t hit? <code>dir[t]</code>: what does table t predict (dir[0] is T0)? <code>hit_below</code>: the hits without the provider."),
("""always @* begin
  dir[0] = t0_ctr_msb;""", "Combinational logic. T0's prediction is its counter's top bit."),
("""  for (t = 1; t <= 4; t = t + 1) begin
    hit[t] = t_valid[t] &&
      (t_tag[(t-1)*TAG_W +: TAG_W] == hash_tag[(t-1)*TAG_W +: TAG_W]);""", "For each table: <b>hit = valid AND (stored tag == expected tag)</b>. <code>(t-1)*TAG_W +: TAG_W</code> picks table t's 8 bits out of the 32-bit bus (T1 = bits 7..0, T2 = 15..8, ...). Hardware: an 8-bit comparator and an AND gate per table."),
("""    dir[t] = t_ctr[(t-1)*CTR_W + CTR_W - 1];""", "Table t's prediction = the top bit of its 3-bit counter (1 if the counter is 4..7)."),
("assign prov = highest_hit(hit);", "<b>Provider</b> = the highest table that hit."),
("""always @* begin
  hit_below = hit;
  if (prov != 3'd0)
    hit_below[prov] = 1'b0;
end
assign alt = highest_hit(hit_below);""", "<b>Alternate</b>: copy the hits, erase the provider's hit, and take the highest again. That is the second-longest hit (or 0 = T0 if there is none)."),
("""assign pred     = dir[prov];
assign alt_pred = dir[alt];""", "The prediction is the provider's direction; alt_pred is the alternate's. If prov = 0, <code>dir[0]</code> = T0 is used automatically. Hardware: two multiplexers."),
("assign meta = {prov, alt, hash_idx, hash_tag, pred, alt_pred};", "Glue everything into the 72-bit receipt, in the same order as <code>tage_meta_t</code>."),
])

# ---------------- tage_update
h('<h3>4.5 tage_update.sv: the learning rules <span class="tag m3">Member 3</span></h3>')
h('<p><b>Job:</b> pure logic. When a branch finishes, it decides <b>what to write</b> into T0..T4. It stores nothing; the tables do the writing at the next clock edge.</p>')
ports([
("update_valid", "in", "1", "1 = a branch finished, apply the rules"),
("update_pc", "in", "32", "the address of that branch (to find its T0 entry)"),
("taken", "in", "1", "its real outcome"),
("meta", "in", "72", "the receipt saved when it was predicted"),
("rd_valid, rd_tag, rd_ctr, rd_u", "in", "4, 4&times;8, 4&times;3, 4", "current contents of T1..T4 at the indices in the receipt (from read port B)"),
("t0_ctr", "in", "2", "current T0 counter of that branch"),
("t0_we, t0_waddr, t0_wctr", "out", "1, 10, 2", "write to T0: enable, which entry, new counter"),
("t_we", "out", "4", "write enable for T1..T4 (one bit each)"),
("t_waddr", "out", "4&times;8", "which entry to write in each table"),
("t_wvalid, t_wtag, t_wctr, t_wu", "out", "4, 4&times;8, 4&times;3, 4", "the new entry contents for each table"),
])
walk("rtl/tage_update.sv: defaults", [
("""always_comb begin
  prov = int'(meta.prov);""", "Combinational logic. <code>prov</code> = the provider table number from the receipt."),
("""  t0_we    = 1'b0;
  t0_waddr = update_pc[BASE_IDX_W+1:2];
  t0_wctr  = t0_ctr;""", "Default for T0: do not write. If it is written, the address is the branch's T0 entry (<code>pc[11:2]</code>) and the value stays the same unless a rule changes it."),
("""  for (int i = 1; i <= 4; i++) begin
    t_we[i]     = 1'b0;
    t_waddr[i]  = meta.idx[i];
    t_wvalid[i] = rd_valid[i];
    t_wtag[i]   = rd_tag[i];
    t_wctr[i]   = rd_ctr[i];
    t_wu[i]     = rd_u[i];
  end
  found = 1'b0;""", "Defaults for T1..T4: no write; the address is the same entry the prediction used; the new values = the current values. So when a rule only changes, say, the counter, the other fields are rewritten unchanged (<b>read-modify-write</b>). <code>found</code> is cleared (used by rule 3)."),
("  if (update_valid) begin", "Everything below only happens when a branch actually finished."),
])
walk("rtl/tage_update.sv: rules 1 and 2", [
("""if (prov != 0) begin
  t_we[prov] = 1'b1;""", "<b>Rule 1.</b> If a tagged table was the provider: write to it."),
("""  if (taken) begin
    if (rd_ctr[prov] != {CTR_W{1'b1}})
      t_wctr[prov] = rd_ctr[prov] + 1'b1;""", "Taken: counter + 1, unless it is already 111 (= 7, the maximum)."),
("""  end else begin
    if (rd_ctr[prov] != {CTR_W{1'b0}})
      t_wctr[prov] = rd_ctr[prov] - 1'b1;
  end""", "Not taken: counter &minus; 1, unless it is already 000 (the minimum). This is the <b>saturating</b> counter."),
("""  if (meta.pred == taken && meta.alt_pred != taken)
    t_wu[prov] = 1'b1;""", "<b>Rule 2.</b> The provider was right and the alternate would have been wrong: mark the entry useful (u = 1)."),
("""end else begin
  t0_we = 1'b1;
  if (taken) begin
    if (t0_ctr != 2'b11) t0_wctr = t0_ctr + 2'd1;
  end else begin
    if (t0_ctr != 2'b00) t0_wctr = t0_ctr - 2'd1;
  end
end""", "No tagged provider (prov = 0): train T0's 2-bit counter the same way (limits 3 and 0)."),
])
walk("rtl/tage_update.sv: rule 3 (allocation)", [
("if (meta.pred != taken && prov < 4) begin", "<b>Rule 3.</b> Only if the prediction was <b>wrong</b> and there is a longer table than the provider (provider is not T4)."),
("""  for (int i = 1; i <= 4; i++) begin
    if (i > prov && !found && !rd_u[i]) begin""", "Go through T1..T4. Pick table i if it is longer than the provider, nothing was picked yet (<code>!found</code>) and its entry is not useful (u = 0). So the <b>first</b> (shortest) free longer table is picked."),
("""      found       = 1'b1;
      t_we[i]     = 1'b1;
      t_wvalid[i] = 1'b1;
      t_wtag[i]   = meta.tag[i];
      t_wctr[i]   = taken ? 3'b100 : 3'b011;
      t_wu[i]     = 1'b0;""", "Take over that entry: valid = 1, tag = the tag this branch had, counter = weakly towards the real outcome (100 = 4 if taken, 011 = 3 if not), u = 0. <code>found = 1</code> stops other tables from being picked."),
("""  if (!found) begin
    for (int i = 1; i <= 4; i++)
      if (i > prov) begin
        t_we[i] = 1'b1;
        t_wu[i] = 1'b0;
      end""", "If every longer table's entry was useful (nothing free): do not take any entry, but clear u in all of them, so that next time one is free."),
("(rule 4 is in tage_hash)", "<b>Rule 4</b> (shift the outcome into the GHR) happens in <code>tage_hash</code>, which receives the same update signals."),
])

# ---------------- tage_top
h('<h3>4.6 tage_top.sv: the complete predictor <span class="tag m3">Member 3</span></h3>')
h('<p><b>Job:</b> places the hash, the base table T0, four tagged tables, the predict logic and the update logic, and connects them (see the block diagram in chapter 2).</p>')
ports([
("clk, rst_n", "in", "1, 1", "clock and reset"),
("pc_i", "in", "32", "<b>predict:</b> the address of the branch to predict"),
("pred_o", "out", "1", "<b>predict:</b> the guess (1 = taken), in the same cycle"),
("meta_o", "out", "72", "<b>predict:</b> the receipt; the user must keep it until the branch finishes"),
("update_valid_i", "in", "1", "<b>update:</b> 1 = a branch finished this cycle"),
("update_pc_i", "in", "32", "<b>update:</b> its address"),
("update_taken_i", "in", "1", "<b>update:</b> its real outcome"),
("update_meta_i", "in", "72", "<b>update:</b> the receipt that was given out when it was predicted"),
])
walk("rtl/tage_top.sv", [
("""logic [4*IDX_W-1:0] hash_idx;
logic [4*TAG_W-1:0] hash_tag;
tage_hash #( ... ) u_hash (
  .clk(clk), .rst_n(rst_n), .pc(pc_i),
  .idx(hash_idx), .tag(hash_tag),
  .update_en(update_valid_i),
  .actual_taken(update_taken_i) );""", "Place the hash. It gets the PC to predict and gives back 4 indices and 4 tags. It also gets the update signals, so the real outcome is shifted into the GHR (rule 4)."),
("logic [(1<<BASE_IDX_W)-1:0][1:0] T0;", "The base table T0: 1024 counters of 2 bits, built right here (not with tage_table)."),
("""assign t0_ctr_a = T0[pc_i[BASE_IDX_W+1:2]];
assign t0_ctr_b = T0[update_pc_i[BASE_IDX_W+1:2]];""", "Two reads of T0: <code>_a</code> for the branch being predicted (index <code>pc_i[11:2]</code>), <code>_b</code> for the branch being updated."),
("""always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n)
    for (int k = 0; k < (1<<BASE_IDX_W); k++) T0[k] <= 2'b10;
  else if (t0_we)
    T0[t0_waddr] <= t0_wctr;
end""", "T0's flip-flops. Reset: all 1024 counters = 10 (weakly taken). Otherwise, when tage_update says so, write one counter."),
("""logic [4:1] a_valid, b_valid, a_u, b_u;
logic [4:1][TAG_W-1:0] a_tag, b_tag;
logic [4:1][CTR_W-1:0] a_ctr, b_ctr;
logic [4:1] t_we, t_wvalid, t_wu; ...""", "Wires between the parts: <code>a_*</code> = what the 4 tables show on port A, <code>b_*</code> = port B, <code>t_w*</code> = the write commands from tage_update."),
("""generate
  for (g = 1; g <= 4; g++) begin : g_tab
    tage_table #( ... ) u_tab (""", "Build 4 copies of tage_table: T1, T2, T3, T4."),
("""      .ra_idx  (hash_idx[(g-1)*IDX_W +: IDX_W]),
      .ra_valid(a_valid[g]), .ra_tag(a_tag[g]),
      .ra_ctr(a_ctr[g]), .ra_u(a_u[g]),""", "Port A of table g reads at the index from the hash (the <b>new</b> branch being predicted). Its contents go to <code>a_*[g]</code>."),
("""      .rb_idx  (update_meta_i.idx[g]),
      .rb_valid(b_valid[g]), ... ,""", "Port B reads at the index saved in the receipt (the <b>old</b> branch being updated). Its contents go to <code>b_*[g]</code>."),
("""      .we(t_we[g]), .w_idx(t_waddr[g]),
      .w_valid(t_wvalid[g]), .w_tag(t_wtag[g]),
      .w_ctr(t_wctr[g]), .w_u(t_wu[g]) );""", "The write port is driven by tage_update."),
("""tage_predict #( ... ) u_predict (
  .t0_ctr_msb(t0_ctr_a[1]),
  .t_valid(a_valid), .t_tag(a_tag),
  .t_ctr(a_ctr), .t_u(a_u),
  .hash_idx(hash_idx), .hash_tag(hash_tag),
  .pred(pred_o), .meta(meta_flat) );""", "Place the predict logic. Inputs: T0's top bit and the port A contents of T1..T4, plus the hash results. Outputs: the prediction (directly to <code>pred_o</code>) and the 72-bit meta."),
("assign meta_o = tage_meta_t'(meta_flat);", "Turn the 72 plain bits into the <code>tage_meta_t</code> struct (same order, so nothing changes in hardware)."),
("""tage_update u_update (
  .update_valid(update_valid_i), .update_pc(update_pc_i),
  .taken(update_taken_i), .meta(update_meta_i),
  .rd_valid(b_valid), .rd_tag(b_tag),
  .rd_ctr(b_ctr), .rd_u(b_u),
  .t0_ctr(t0_ctr_b),
  .t0_we(t0_we), ... , .t_wu(t_wu) );""", "Place the update logic. Inputs: the update pins, port B contents of T1..T4 and T0's counter for the old branch. Outputs: the write commands for T0..T4."),
])
h('''<div class="note"><b>Why prediction and update can happen in the same cycle:</b> port A looks at the entry for the new
branch, port B at the entry for the old branch. Each table has two read ports exactly for this.</div>''')
h('</div>')

# ============================================================ CH5 board
h('<div class="chapter"><h2>5. The board demo, file by file</h2>')
h('''<p>The FPGA has no CPU, so the board feeds the predictor test branches from a text file, counts the mistakes
and shows them on the 7-segment display.</p>''')
h('''<div class="fig"><svg viewBox="0 0 700 200" width="640" xmlns="http://www.w3.org/2000/svg" font-family="DejaVu Sans" font-size="12">
<defs><marker id="b" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 z" fill="#1d2330"/></marker></defs>
<rect x="10" y="20" width="110" height="40" rx="6" fill="#f3f6fb" stroke="#5b6475"/><text x="65" y="44" text-anchor="middle">CPU_RESETN</text>
<rect x="10" y="80" width="110" height="40" rx="6" fill="#f3f6fb" stroke="#5b6475"/><text x="65" y="104" text-anchor="middle">BTNC, SW[1:0]</text>
<rect x="150" y="20" width="100" height="100" rx="6" fill="#fff" stroke="#5b6475"/><text x="200" y="65" text-anchor="middle">2-FF sync</text><text x="200" y="82" text-anchor="middle" font-size="10">+ edge detect</text>
<rect x="280" y="20" width="120" height="100" rx="6" fill="#fff" stroke="#1d2330"/><text x="340" y="60" text-anchor="middle" font-weight="bold">run FSM</text><text x="340" y="78" text-anchor="middle" font-size="10">IDLE INIT PRED UPD</text><text x="340" y="92" text-anchor="middle" font-size="10">DONE</text>
<rect x="280" y="140" width="120" height="44" rx="6" fill="#fff" stroke="#5b6475"/><text x="340" y="167" text-anchor="middle">trace_rom</text>
<rect x="430" y="80" width="110" height="60" rx="6" fill="#eef3fb" stroke="#2457a6"/><text x="485" y="114" text-anchor="middle" font-weight="bold">tage_top</text>
<rect x="430" y="150" width="110" height="40" rx="6" fill="#fff" stroke="#5b6475"/><text x="485" y="174" text-anchor="middle">perf_counters</text>
<rect x="570" y="100" width="120" height="60" rx="6" fill="#fff" stroke="#5b6475"/><text x="630" y="126" text-anchor="middle">seg7_driver</text><text x="630" y="144" text-anchor="middle" font-size="10">8-digit display</text>
<path d="M120,40 L148,40" stroke="#1d2330" marker-end="url(#b)"/><path d="M120,100 L148,100" stroke="#1d2330" marker-end="url(#b)"/>
<path d="M250,70 L278,70" stroke="#1d2330" marker-end="url(#b)"/>
<path d="M400,162 L428,120" stroke="#1d2330" marker-end="url(#b)"/><text x="402" y="140" font-size="10">pc, taken</text>
<path d="M400,90 L428,100" stroke="#1d2330" marker-end="url(#b)"/>
<path d="M485,140 L485,148" stroke="#1d2330" marker-end="url(#b)"/>
<path d="M540,170 L568,140" stroke="#1d2330" marker-end="url(#b)"/>
</svg><div class="cap">The board design (nexys7_top.sv).</div></div>''')

h('<h3>5.1 branch_trace.mem: the test branches</h3>')
walk("rtl/board/branch_trace.mem", [
("// ---- SW = 00 : loop  (28 lines)", "Lines starting with <code>//</code> are comments."),
("@00", "\"Put the next lines from memory address 0 on\". The 4 patterns start at <code>@00</code>, <code>@20</code>, <code>@40</code>, <code>@60</code> (hex: 0, 32, 64, 96)."),
("1_00001040", "One branch: <code>1</code> = taken, <code>00001040</code> = its address (pc) in hex. The <code>_</code> is only for readability; the line is the 33-bit number {taken, pc}."),
("0_00001040", "Same branch, not taken (the inner loop ends)."),
])

h('<h3>5.2 trace_rom.sv: plays the branches</h3>')
ports([
("clk, rst", "in", "1, 1", "clock; reset (1 = go back to the first line)"),
("mode", "in", "2", "which pattern (SW1 SW0)"),
("adv", "in", "1", "1 = go to the next line at the next clock edge"),
("valid", "out", "1", "1 once out of reset"),
("pc, taken", "out", "32, 1", "the current branch"),
])
walk("rtl/board/trace_rom.sv", [
("localparam logic [LEN_W:0] PAT_LEN [4] = '{28, 2, 20, 31};", "How many lines each pattern has (SW = 00, 01, 10, 11)."),
("""logic [32:0] rom [4 << LEN_W];
initial $readmemh(MEM_FILE, rom);""", "A memory of 128 lines of 33 bits. <code>$readmemh</code> fills it from the text file when the FPGA is programmed."),
("""always_comb begin
  if (rst)        pos_next = '0;
  else if (!adv)  pos_next = pos;
  else if ({1'b0, pos} == PAT_LEN[mode] - 1'b1)
                  pos_next = '0;
  else            pos_next = pos + 1'b1;
end""", "Which line comes next: after reset line 0; if not advancing, the same line; after the last line of the pattern, back to line 0; otherwise the next line."),
("""always_ff @(posedge clk) begin
  if (rst) begin pos <= '0; valid <= 1'b0; end
  else     begin pos <= pos_next; valid <= 1'b1; end
end""", "Store the line number at each clock edge."),
("""always_ff @(posedge clk) q <= rom[{mode, pos_next}];
assign {taken, pc} = q;""", "Read the line. The address is <code>{mode, pos}</code>: the 2 switch bits choose the block of 32 lines, <code>pos</code> the line in it. The 33 bits are split into <code>taken</code> (top bit) and <code>pc</code>."),
])

h('<h3>5.3 nexys7_top.sv: the board controller</h3>')
ports([
("CLK100MHZ", "in", "1", "the board's 100 MHz clock"),
("CPU_RESETN", "in", "1", "red reset button (0 when pressed)"),
("BTNC", "in", "1", "centre button: start a run"),
("SW", "in", "16", "switches; SW[1:0] select the pattern"),
("LED", "out", "16", "LEDs (done, last prediction, progress bar, ...)"),
("CA..CG, DP, AN", "out", "7, 1, 8", "7-segment display: segments, dot, which digit is on"),
])
walk("rtl/board/nexys7_top.sv: clock and inputs", [
("""MMCME2_BASE #(.CLKIN1_PERIOD(10.0),
  .CLKFBOUT_MULT_F(10.0), .CLKOUT0_DIVIDE_F(20.0))
  u_mmcm ( ... .LOCKED(mmcm_locked) ... );
BUFG u_bufg (.I(clk_mmcm), .O(clk));""", "A clock generator built into the FPGA: 100 MHz &times; 10 / 20 = <b>50 MHz</b>. The predictor needs about 16 ns per cycle, more than the 10 ns of 100 MHz. <code>BUFG</code> spreads the clock over the chip."),
("lock_sync <= {lock_sync[0], 1'b1};", "Waits until the clock generator is stable (<code>LOCKED</code>); until then everything stays in reset."),
("""resetn_s <= {resetn_s[0], CPU_RESETN};
btnc_s   <= {btnc_s[0],   BTNC};
sw_s1    <= SW[1:0];
sw_s2    <= sw_s1;""", "Each button/switch goes through 2 flip-flops (a <b>synchroniser</b>), because they change at random times compared to the clock."),
("assign rst = ~resetn_s[1] | ~lock_sync[1];", "Reset everything while the button is pressed or the clock is not ready."),
("""btnc_q <= btnc_s[1];
assign start = btnc_s[1] & ~btnc_q;""", "<code>start</code> is 1 for one clock when BTNC changes from 0 to 1 (now 1, one clock ago 0)."),
])
walk("rtl/board/nexys7_top.sv: the run state machine", [
("""S_IDLE, S_DONE: if (start) begin
    soft_rst <= 1'b1;
    mode_q   <= sw_s2;
    state    <= S_INIT;
  end""", "Waiting. On BTNC: reset the predictor, trace and counters (<code>soft_rst</code>), remember the switches, go to S_INIT."),
("""S_INIT: if (!soft_rst && tage_ready && tg_valid)
          state <= S_PRED;""", "Wait one clock for the reset to finish, then start."),
("""S_PRED: if (done) state <= S_DONE;
  else begin
    p_tage  <= tage_pred;
    p_meta  <= tage_meta;
    p_pc    <= tg_pc;
    p_taken <= tg_taken;
    state   <= S_UPD;
  end""", "<b>Cycle A (predict).</b> The trace's pc goes into <code>tage_top</code>. Save the prediction, the receipt, the pc and the real outcome in registers (the pipeline register in Fig. A). After 40,000 branches go to S_DONE."),
("S_UPD: state <= S_PRED;", "<b>Cycle B (update).</b> Lasts one clock, then the next branch."),
("assign in_upd = (state == S_UPD);", "1 during cycle B. It drives the update, the counters and the trace advance."),
])
walk("rtl/board/nexys7_top.sv: connections", [
("""trace_rom #(.MEM_FILE(TRACE_FILE)) u_tg (
  .clk(clk), .rst(core_rst), .mode(mode_q),
  .adv(in_upd), .valid(tg_valid),
  .pc(tg_pc), .taken(tg_taken) );""", "The trace moves to the next line in every update cycle."),
("""(* dont_touch = "true" *)
tage_top u_tage (
  .pc_i(tg_pc), .pred_o(tage_pred), .meta_o(tage_meta),
  .update_valid_i(in_upd), .update_pc_i(p_pc),
  .update_taken_i(p_taken), .update_meta_i(p_meta), ... );""", "The predictor. Predict side: the trace's pc. Update side: the saved values, in cycle B. <code>dont_touch</code> tells Vivado not to remove table entries that the few test PCs never use, so the size report is honest."),
("""perf_counters u_perf (
  .br_valid(in_upd),
  .tage_miss(p_tage != p_taken),
  .tage_cnt(tage_cnt), .br_cnt(br_cnt), .done(done) );""", "In every update cycle: count one branch, and one mistake if the saved prediction differs from the real outcome."),
("""seg7_driver u_seg (.value({tage_cnt, br_cnt}), ... );""", "Display: left 4 digits = mistakes, right 4 = branches (hex)."),
])

h('<h3>5.4 perf_counters.sv and seg7_driver.sv</h3>')
walk("rtl/board/perf_counters.sv", [
("""always_ff @(posedge clk) begin
  if (rst) begin
    tage_cnt <= '0; br_cnt <= '0; done <= 1'b0;""", "Reset: both counts 0, not done."),
("""  end else if (br_valid && !done) begin
    br_cnt   <= br_cnt + 16'd1;
    tage_cnt <= tage_cnt + {15'd0, tage_miss};""", "For every branch (until done): branches + 1, and mistakes + 1 if <code>tage_miss</code> is 1."),
("    if (br_cnt == 16'(RUN_LEN - 1)) done <= 1'b1;", "After 40,000 branches: done, the counts freeze."),
])
walk("rtl/board/seg7_driver.sv", [
("""end else if (div == DW'(DIGIT_CYCLES - 1)) begin
  div   <= '0;
  digit <= digit + 3'd1;
end else div <= div + 1'b1;""", "The 8 digits share their segment wires, so only one digit is lit at a time. <code>div</code> counts 6,250 clocks (0.125 ms), then the next digit (0..7, then wraps). Too fast for the eye to see, so all 8 look lit."),
("assign nib = value[{digit, 2'b00} +: 4];", "The 4 bits (one hex digit) for the current digit: digit 0 = bits 3..0, digit 1 = bits 7..4, ..."),
("""case (nib)
  4'h0: seg = 7'h3F;
  4'h1: seg = 7'h06;  ...""", "Which segments to light for each hex digit 0..F (e.g. <code>3F</code> = segments a..f = \"0\")."),
("""an_n  <= ~(8'b1 << digit);
seg_n <= ~seg;""", "Turn on only the current digit, and its segments. <code>~</code> because the board's display is on when the wire is 0."),
])
h('</div>')

# ============================================================ CH5
h('<div class="chapter"><h2>6. Testing and results</h2>')
h('''<h3>6.1 How it is tested</h3>
<ul><li><b>tage_ref.sv</b> <span class="tag m4">Member 4</span>: a second, independent model of TAGE written in plain
behavioural code: the "answer key".</li>
<li><b>tb_tage.sv</b>: runs <code>tage_top</code> and <code>tage_ref</code> side by side on many traces (loops, correlated
branches, random branches, the 4 board patterns). On <b>every branch</b> the prediction and meta must match, and after
every trace <b>every table entry</b> and the GHR must match.</li>
<li><b>tb/unit/</b>: one small test per module (table, hash, predict, update, counters).</li></ul>''')
code('''make sim      # all tests in Verilator   (make xsim: same in Vivado)
make build    # synthesis + bitstream -> bitstream/nexys7_top.bit''', "Terminal")
h('''<h3>6.2 Results on the board</h3>
<table><tr><th>SW1 SW0</th><th>Pattern</th><th>Display</th><th>Meaning</th></tr>
<tr><td>00</td><td>loop</td><td class="mono">000B 9C40</td><td>11 mistakes in 40,000</td></tr>
<tr><td>01</td><td>alternating</td><td class="mono">0002 9C40</td><td>2 mistakes</td></tr>
<tr><td>10</td><td>correlated</td><td class="mono">000C 9C40</td><td>12 mistakes</td></tr>
<tr><td>11</td><td>mixed</td><td class="mono">000E 9C40</td><td>14 mistakes</td></tr></table>
<p>All mistakes happen at the start, while the tables are still empty. After that every branch is predicted correctly.
A simple counter without history could not learn the alternating or correlated patterns.</p>
<h3>6.3 Hardware cost (Artix-7 xc7a100t)</h3>
<table><tr><th>Resource</th><th>Used</th><th>%</th></tr>
<tr><td>LUTs</td><td>10,186</td><td>16%</td></tr>
<tr><td>Flip-flops</td><td>15,587</td><td>12%</td></tr>
<tr><td>Clock</td><td colspan="2">50 MHz, timing met (3.72 ns spare)</td></tr></table>
<p>The spec requires every table entry to be cleared in one reset, which FPGA RAM blocks cannot do, so the tables are
built from flip-flops. That is why the flip-flop count is high and the clock is 50 MHz.</p>''')
h('</div>')

h('</body></html>')
open(OUT, 'w').write('\n'.join(parts))
print("wrote", OUT)
