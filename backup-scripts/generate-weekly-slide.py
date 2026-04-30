#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Components Bay - Weekly Slide Generator
Generates Component_Bay_Slide.pptx from Supabase data
"""

import sys, io
# Force UTF-8 output to avoid Windows cp1252 encoding errors
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

import requests, json, zipfile, shutil, os, sys
from datetime import datetime
import xml.etree.ElementTree as ET

SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

SCRIPT_DIR   = os.path.dirname(os.path.abspath(__file__))
TEMPLATE     = os.path.join(SCRIPT_DIR, "Component_Bay_Slide_Template.pptx")
OUTPUT_DIR   = r"C:\Users\jpellegrini\Desktop\APP 5.5"
if not os.path.exists(OUTPUT_DIR):
    OUTPUT_DIR = r"C:\ComponentsBay_Logs"
OUTPUT_PATH  = os.path.join(OUTPUT_DIR,
                f"Component_Bay_Slide_{datetime.now().strftime('%Y-%m-%d')}.pptx")

# Namespaces
A = 'http://schemas.openxmlformats.org/drawingml/2006/main'
P = 'http://schemas.openxmlformats.org/presentationml/2006/main'

for prefix, uri in [('a',A),('p',P)]:
    ET.register_namespace(prefix, uri)

# Colors
RED     = "C0392B"
ORANGE  = "E8A000"
WHITE   = "FFFFFF"
BLACK   = "1A1A1A"
GRAY_ROW= "F5F5F5"
HEADER_COL = "E8A000"

def fetch(table):
    hdrs = {"apikey": SUPABASE_KEY, "Authorization": f"Bearer {SUPABASE_KEY}"}
    r = requests.get(f"{SUPABASE_URL}/rest/v1/{table}?select=*", headers=hdrs)
    r.raise_for_status()
    items = []
    for row in r.json():
        d = row.get('data', {})
        if isinstance(d, str): d = json.loads(d)
        items.append(d)
    return items

def days_left(s):
    if not s: return None
    try:
        dt = datetime.strptime(str(s)[:10], '%Y-%m-%d')
        return (dt.date() - datetime.now().date()).days
    except: return None

def tc(text, bold=False, sz=900, fg=BLACK, bg=None, align='l'):
    el = ET.Element(f'{{{A}}}tc')
    tb = ET.SubElement(el, f'{{{A}}}txBody')
    bp = ET.SubElement(tb, f'{{{A}}}bodyPr')
    bp.set('anchor','ctr')
    # Normalize spacing to prevent PowerPoint from auto-expanding row height
    ET.SubElement(bp, f'{{{A}}}spAutoFit')
    ET.SubElement(tb, f'{{{A}}}lstStyle')
    para = ET.SubElement(tb, f'{{{A}}}p')
    pp = ET.SubElement(para, f'{{{A}}}pPr'); pp.set('algn', align)
    if str(text).strip():
        run = ET.SubElement(para, f'{{{A}}}r')
        rp = ET.SubElement(run, f'{{{A}}}rPr')
        rp.set('lang','en-US'); rp.set('sz',str(sz)); rp.set('dirty','0')
        if bold: rp.set('b','1')
        sf = ET.SubElement(rp, f'{{{A}}}solidFill')
        ET.SubElement(sf, f'{{{A}}}srgbClr').set('val', fg)
        t = ET.SubElement(run, f'{{{A}}}t'); t.text = str(text)
    else:
        ET.SubElement(para, f'{{{A}}}endParaRPr').set('lang','en-US')
    pr = ET.SubElement(el, f'{{{A}}}tcPr')
    pr.set('marL','91440'); pr.set('marR','91440')
    pr.set('marT','45720'); pr.set('marB','45720')
    if bg:
        sf = ET.SubElement(pr, f'{{{A}}}solidFill')
        ET.SubElement(sf, f'{{{A}}}srgbClr').set('val', bg)
    else:
        ET.SubElement(pr, f'{{{A}}}noFill')
    return el

def build_table(headers, rows, col_widths, row_h=380000,
                hdr_bg=HEADER_COL, days_col=None, us_col=None):
    tbl = ET.Element(f'{{{A}}}tbl')
    tp = ET.SubElement(tbl, f'{{{A}}}tblPr')
    tp.set('firstRow','1'); tp.set('bandRow','0')
    gr = ET.SubElement(tbl, f'{{{A}}}tblGrid')
    for w in col_widths:
        gc = ET.SubElement(gr, f'{{{A}}}gridCol'); gc.set('w', str(w))

    # Header row
    tr = ET.SubElement(tbl, f'{{{A}}}tr'); tr.set('h', str(row_h))
    for h in headers:
        tr.append(tc(h, bold=True, sz=950, fg=WHITE, bg=hdr_bg))

    # Data rows
    for ri, row in enumerate(rows):
        tr = ET.SubElement(tbl, f'{{{A}}}tr'); tr.set('h', str(row_h))
        bg = GRAY_ROW if ri % 2 == 0 else None
        for ci, cell in enumerate(row):
            fg = BLACK
            # Color days left column
            if days_col is not None and ci == days_col and cell:
                try:
                    d = int(str(cell).replace(' days','').strip())
                    fg = RED if d <= 30 else (ORANGE if d <= 60 else '2E7D32')
                except: pass
            tr.append(tc(str(cell) if cell else '', sz=850, fg=fg, bg=bg))
    return tbl

def graphicFrame(tbl, x, y, cx, cy, fid=100):
    gf = ET.Element(f'{{{P}}}graphicFrame')
    nv = ET.SubElement(gf, f'{{{P}}}nvGraphicFramePr')
    cp = ET.SubElement(nv, f'{{{P}}}cNvPr')
    cp.set('id', str(fid)); cp.set('name', f'Table{fid}')
    ET.SubElement(nv, f'{{{P}}}cNvGraphicFramePr')
    ET.SubElement(nv, f'{{{P}}}nvPr')
    xf = ET.SubElement(gf, f'{{{P}}}xfrm')
    off = ET.SubElement(xf, f'{{{A}}}off'); off.set('x',str(x)); off.set('y',str(y))
    ext = ET.SubElement(xf, f'{{{A}}}ext'); ext.set('cx',str(cx)); ext.set('cy',str(cy))
    gr = ET.SubElement(gf, f'{{{A}}}graphic')
    gd = ET.SubElement(gr, f'{{{A}}}graphicData')
    gd.set('uri','http://schemas.openxmlformats.org/drawingml/2006/table')
    gd.append(tbl)
    return gf

def header_bar(title, count, x, y, cx, cy, bg=RED, fid=200):
    sp = ET.Element(f'{{{P}}}sp')
    nv = ET.SubElement(sp, f'{{{P}}}nvSpPr')
    cp = ET.SubElement(nv, f'{{{P}}}cNvPr'); cp.set('id',str(fid)); cp.set('name',f'Bar{fid}')
    ET.SubElement(nv, f'{{{P}}}cNvSpPr')
    ET.SubElement(nv, f'{{{P}}}nvPr')
    spr = ET.SubElement(sp, f'{{{P}}}spPr')
    xf = ET.SubElement(spr, f'{{{A}}}xfrm')
    off = ET.SubElement(xf, f'{{{A}}}off'); off.set('x',str(x)); off.set('y',str(y))
    ext = ET.SubElement(xf, f'{{{A}}}ext'); ext.set('cx',str(cx)); ext.set('cy',str(cy))
    pg = ET.SubElement(spr, f'{{{A}}}prstGeom'); pg.set('prst','rect')
    ET.SubElement(pg, f'{{{A}}}avLst')
    sf = ET.SubElement(spr, f'{{{A}}}solidFill')
    ET.SubElement(sf, f'{{{A}}}srgbClr').set('val', bg)
    tb = ET.SubElement(sp, f'{{{P}}}txBody')
    bp = ET.SubElement(tb, f'{{{A}}}bodyPr'); bp.set('anchor','ctr')
    ET.SubElement(tb, f'{{{A}}}lstStyle')
    para = ET.SubElement(tb, f'{{{A}}}p')
    pp = ET.SubElement(para, f'{{{A}}}pPr'); pp.set('algn','l')
    # Icon + title
    run = ET.SubElement(para, f'{{{A}}}r')
    rp = ET.SubElement(run, f'{{{A}}}rPr'); rp.set('lang','en-US'); rp.set('sz','1000'); rp.set('b','1'); rp.set('dirty','0')
    sf2 = ET.SubElement(rp, f'{{{A}}}solidFill'); ET.SubElement(sf2, f'{{{A}}}srgbClr').set('val', WHITE)
    t = ET.SubElement(run, f'{{{A}}}t'); t.text = f"  \u26a0  {title.upper()}"
    # Count right
    run2 = ET.SubElement(para, f'{{{A}}}r')
    rp2 = ET.SubElement(run2, f'{{{A}}}rPr'); rp2.set('lang','en-US'); rp2.set('sz','1000'); rp2.set('b','1'); rp2.set('dirty','0')
    sf3 = ET.SubElement(rp2, f'{{{A}}}solidFill'); ET.SubElement(sf3, f'{{{A}}}srgbClr').set('val', WHITE)
    t2 = ET.SubElement(run2, f'{{{A}}}t'); t2.text = f"{'':>60}{count}"
    return sp

def patch_slide(xml_bytes, bars_frames, remove_sp_names=None):
    root = ET.fromstring(xml_bytes)
    tree = root.find(f'.//{{{P}}}spTree')
    # Remove old images
    for pic in list(tree.findall(f'{{{P}}}pic')):
        tree.remove(pic)
    # Remove old graphic frames (previously generated tables)
    for gf in list(tree.findall(f'{{{P}}}graphicFrame')):
        tree.remove(gf)
    # Remove specific named shapes (old bars, title placeholders, stale rects)
    if remove_sp_names:
        for sp in list(tree.findall(f'{{{P}}}sp')):
            cNvPr = sp.find(f'.//{{{P}}}cNvPr')
            if cNvPr is None:
                continue
            name = cNvPr.get('name', '')
            if any(name.startswith(n) for n in remove_sp_names):
                tree.remove(sp)
    for el in bars_frames:
        tree.append(el)
    return ET.tostring(root, encoding='utf-8', xml_declaration=True)


def hexagon_shape(title_line1, title_line2, highlight_color="8B1A1A"):
    """Build the dark arrow/hexagon shape with title text (left side of slides 1 & 2)."""
    P_NS = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    A_NS = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    # Arrow shape (rotated down arrow = hexagon-like)
    arrow = ET.Element(f'{{{P_NS}}}sp')
    nv = ET.SubElement(arrow, f'{{{P_NS}}}nvSpPr')
    cp = ET.SubElement(nv, f'{{{P_NS}}}cNvPr'); cp.set('id','14'); cp.set('name','Down Arrow 7')
    csp = ET.SubElement(nv, f'{{{P_NS}}}cNvSpPr')
    sl = ET.SubElement(csp, f'{{{A_NS}}}spLocks')
    for attr in ['noGrp','noRot','noChangeAspect','noMove','noResize',
                 'noEditPoints','noAdjustHandles','noChangeArrowheads','noChangeShapeType','noTextEdit']:
        sl.set(attr,'1')
    ET.SubElement(nv, f'{{{P_NS}}}nvPr')
    spr = ET.SubElement(arrow, f'{{{P_NS}}}spPr')
    xf = ET.SubElement(spr, f'{{{A_NS}}}xfrm'); xf.set('rot','16200000')
    off = ET.SubElement(xf, f'{{{A_NS}}}off'); off.set('x','800100'); off.set('y','1491343')
    ext = ET.SubElement(xf, f'{{{A_NS}}}ext'); ext.set('cx','3333749'); ext.set('cy','3499103')
    pg = ET.SubElement(spr, f'{{{A_NS}}}prstGeom'); pg.set('prst','downArrow')
    avl = ET.SubElement(pg, f'{{{A_NS}}}avLst')
    gd1 = ET.SubElement(avl, f'{{{A_NS}}}gd'); gd1.set('name','adj1'); gd1.set('fmla','val 100000')
    gd2 = ET.SubElement(avl, f'{{{A_NS}}}gd'); gd2.set('name','adj2'); gd2.set('fmla','val 15788')
    sf = ET.SubElement(spr, f'{{{A_NS}}}solidFill')
    ET.SubElement(sf, f'{{{A_NS}}}srgbClr').set('val','404040')
    ln = ET.SubElement(spr, f'{{{A_NS}}}ln'); ln.set('w','53975')
    ET.SubElement(ln, f'{{{A_NS}}}noFill')
    # Title text box (positioned over arrow)
    title_sp = ET.Element(f'{{{P_NS}}}sp')
    nv2 = ET.SubElement(title_sp, f'{{{P_NS}}}nvSpPr')
    cp2 = ET.SubElement(nv2, f'{{{P_NS}}}cNvPr'); cp2.set('id','2'); cp2.set('name','Title 1')
    csp2 = ET.SubElement(nv2, f'{{{P_NS}}}cNvSpPr')
    ET.SubElement(csp2, f'{{{A_NS}}}spLocks').set('noGrp','1')
    ph = ET.SubElement(ET.SubElement(nv2, f'{{{P_NS}}}nvPr'), f'{{{P_NS}}}ph'); ph.set('type','title')
    spr2 = ET.SubElement(title_sp, f'{{{P_NS}}}spPr')
    xf2 = ET.SubElement(spr2, f'{{{A_NS}}}xfrm')
    off2 = ET.SubElement(xf2, f'{{{A_NS}}}off'); off2.set('x','1028700'); off2.set('y','1967266')
    ext2 = ET.SubElement(xf2, f'{{{A_NS}}}ext'); ext2.set('cx','2628900'); ext2.set('cy','2547257')
    ET.SubElement(spr2, f'{{{A_NS}}}noFill')
    tb = ET.SubElement(title_sp, f'{{{P_NS}}}txBody')
    bp = ET.SubElement(tb, f'{{{A_NS}}}bodyPr'); bp.set('anchor','ctr')
    ET.SubElement(bp, f'{{{A_NS}}}spAutoFit')
    ET.SubElement(tb, f'{{{A_NS}}}lstStyle')
    para = ET.SubElement(tb, f'{{{A_NS}}}p')
    pp = ET.SubElement(para, f'{{{A_NS}}}pPr'); pp.set('algn','ctr')
    for line in [title_line1, None, None, title_line2]:
        if line is not None:
            run = ET.SubElement(para, f'{{{A_NS}}}r')
            rp = ET.SubElement(run, f'{{{A_NS}}}rPr')
            rp.set('lang','en-US'); rp.set('sz','3600'); rp.set('dirty','0')
            sf2 = ET.SubElement(rp, f'{{{A_NS}}}solidFill')
            ET.SubElement(sf2, f'{{{A_NS}}}srgbClr').set('val','FFFFFF')
            hl = ET.SubElement(rp, f'{{{A_NS}}}highlight')
            ET.SubElement(hl, f'{{{A_NS}}}srgbClr').set('val', highlight_color)
            t = ET.SubElement(run, f'{{{A_NS}}}t'); t.text = line
        else:
            br = ET.SubElement(para, f'{{{A_NS}}}br')
            rp_br = ET.SubElement(br, f'{{{A_NS}}}rPr')
            rp_br.set('lang','en-US'); rp_br.set('sz','3600'); rp_br.set('dirty','0')
    return [arrow, title_sp]

def main():
    print("="*55)
    print("  Components Bay - Weekly Slide Generator")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print("="*55)

    if not os.path.exists(TEMPLATE):
        print(f"ERREUR: Template introuvable:\n  {TEMPLATE}")
        sys.exit(1)

    print("\nChargement Supabase...")
    try:
        efs       = fetch('efs')
        efs_cyl   = fetch('efs_cylinders')
        liferafts = fetch('liferafts')
        maint     = fetch('maintenance')
        comp      = fetch('composite')
        avio      = fetch('avionic')
        eng       = fetch('engine')
        rotor     = fetch('rotorbay')
        iaft      = fetch('iafteaft')
        pol       = fetch('pol')
        tools     = fetch('tools')
        troop     = fetch('troopseats')
    except Exception as e:
        print(f"ERREUR Supabase: {e}"); sys.exit(1)

    def trunc(s, n=28):
        """Truncate long strings to avoid row height expansion."""
        s = str(s)
        return s[:n] + '…' if len(s) > n else s

    # ---- Slide 1: Other Parts U/S ----
    s1_rows = []
    for mod_name, items in [
        ('Maintenance',maint),('Composite',comp),('Avionic',avio),
        ('Engine',eng),('Rotor Bay',rotor),('IAFT/EAFT',iaft),
        ('POL',pol),('Tools',tools),('Troop Seat',troop),
        ('EFS Float',efs),('EFS Cyl.',efs_cyl)]:
        for it in items:
            if it.get('serviceability') == 'Unserviceable':
                pn = it.get('pnWheel') or it.get('partNumber','')
                s1_rows.append([mod_name, trunc(it.get('designation','')), pn,
                                 it.get('serialNumber',''), trunc(it.get('reason','Unserviceable'), 30)])

    # ---- Slide 2: Life Raft U/S ----
    s2_rows = []
    for it in liferafts:
        if it.get('serviceability') == 'Unserviceable':
            s2_rows.append(['Life Raft', it.get('partNumber',''),
                            it.get('serialNumber',''), it.get('reason','Unserviceable')])

    # ---- Slide 3: EFS within 90d ----
    s3_rows = []
    for it in efs:
        if it.get('serviceability') == 'Unserviceable': continue
        best = 999
        for f in ['next18M','next36M']:
            d = days_left(it.get(f))
            if d is not None and 0 <= d <= 90 and d < best: best = d
        if best < 999:
            s3_rows.append([it.get('hc',''), it.get('designation',''),
                            it.get('partNumber',''), it.get('serialNumber',''),
                            it.get('next18M',''), it.get('next36M',''), f"{best} days"])
    s3_rows.sort(key=lambda r: int(r[6].replace(' days','')))

    # ---- Slide 4: EFS Cylinders within 90d ----
    s4_rows = []
    for it in efs_cyl:
        if it.get('serviceability') == 'Unserviceable': continue
        best = 999
        for f in ['next18M','next60M']:
            d = days_left(it.get(f))
            if d is not None and 0 <= d <= 90 and d < best: best = d
        if best < 999:
            s4_rows.append([it.get('hc',''), it.get('designation',''),
                            it.get('partNumber',''), it.get('serialNumber',''),
                            it.get('next18M',''), it.get('next60M',''), f"{best} days"])
    s4_rows.sort(key=lambda r: int(r[6].replace(' days','')))

    print(f"  Slide 1 (Other Parts U/S): {len(s1_rows)} items")
    print(f"  Slide 2 (Life Raft U/S):   {len(s2_rows)} items")
    print(f"  Slide 3 (EFS 90d):         {len(s3_rows)} items")
    print(f"  Slide 4 (EFS Cyl. 90d):    {len(s4_rows)} items")

    # ---- Slide dimensions: 12192000 x 6858000 EMU ----
    # Slides 1-4 share the same right-side table area (hexagon on left)
    # matching the layout of slides 3 & 4:
    #   table area: x=4911094, y=643466, cx=6513144, total height ~6214534
    BAR_H = 500000
    ROW_H = 130000   # compact rows so all items fit on one slide

    TABLE_X  = 4911094
    TABLE_Y  = 643466
    TABLE_CX = 6513144
    SLIDE_H  = 6858000
    # Table content starts at TABLE_Y + BAR_H; leave 80k bottom margin
    TABLE_START_Y = TABLE_Y + BAR_H   # 1143466
    TABLE_AVAIL   = SLIDE_H - TABLE_START_Y - 80000  # 5634534

    def calc_row_h(n_rows, max_rh=ROW_H):
        """Row height that fits all rows + header below the bar."""
        rh = TABLE_AVAIL // max(n_rows + 1, 1)
        return min(rh, max_rh)

    print("\nGeneration PPTX...")
    shutil.copy2(TEMPLATE, OUTPUT_PATH)
    with zipfile.ZipFile(OUTPUT_PATH,'r') as z:
        files = {n: z.read(n) for n in z.namelist()}

    patches = {}

    # === SLIDE 1 ===
    rh1 = calc_row_h(len(s1_rows))
    # MODULE | DESIGNATION | P/N | S/N | REASON  (total = TABLE_CX = 6513144)
    cw1 = [893231, 1302628, 1256106, 632705, 2428474]
    bar1 = header_bar('ALL UNSERVICEABLE ITEMS (ORDERED)', len(s1_rows),
                      TABLE_X, TABLE_Y, TABLE_CX, BAR_H, bg=RED, fid=200)
    tbl1 = build_table(['MODULE','DESIGNATION','P/N','S/N','REASON'], s1_rows, cw1, rh1,
                       hdr_bg=ORANGE)
    gf1  = graphicFrame(tbl1, TABLE_X, TABLE_Y+BAR_H, TABLE_CX, rh1*(len(s1_rows)+1), fid=100)
    hex1 = hexagon_shape('Other Parts', 'NEED TO BE C/OUT', highlight_color='8B1A1A')
    patches['ppt/slides/slide1.xml'] = patch_slide(files['ppt/slides/slide1.xml'],
                                                         hex1 + [bar1, gf1],
                                                         remove_sp_names=['Bar200', 'Bar', 'Down Arrow', 'Title'])

    # === SLIDE 2 ===
    rh2 = calc_row_h(len(s2_rows))
    # MODULE | P/N | S/N | REASON  (total = TABLE_CX = 6513144)
    cw2 = [900000, 1500000, 2000000, 2113144]
    bar2 = header_bar('LIFE RAFT — NEED TO BE C/OUT', len(s2_rows),
                      TABLE_X, TABLE_Y, TABLE_CX, BAR_H, bg=RED, fid=201)
    tbl2 = build_table(['MODULE','P/N','S/N','REASON'], s2_rows, cw2, rh2, hdr_bg=ORANGE)
    gf2  = graphicFrame(tbl2, TABLE_X, TABLE_Y+BAR_H, TABLE_CX, rh2*(len(s2_rows)+1), fid=101)
    hex2 = hexagon_shape('Life Raft', 'NEED TO BE C/OUT', highlight_color='8B1A1A')
    patches['ppt/slides/slide2.xml'] = patch_slide(files['ppt/slides/slide2.xml'],
                                                         hex2 + [bar2, gf2],
                                                         remove_sp_names=['Bar201', 'Bar', 'Rectangle', 'Title', 'Down Arrow'])

    # === SLIDE 3 ===
    rh3 = calc_row_h(len(s3_rows))
    cw3 = [900000,1100000,1300000,500000,980000,980000,753144]
    bar3 = header_bar('SERVICEABLE EFS — DUE WITHIN 90 DAYS', len(s3_rows),
                      TABLE_X, TABLE_Y, TABLE_CX, BAR_H, bg=ORANGE, fid=202)
    tbl3 = build_table(['H/C','DESIGNATION','P/N','S/N','NEXT 18M','NEXT 36M','DAYS LEFT'],
                       s3_rows, cw3, rh3, hdr_bg=ORANGE, days_col=6)
    gf3  = graphicFrame(tbl3, TABLE_X, TABLE_Y+BAR_H, TABLE_CX, rh3*(len(s3_rows)+1), fid=102)
    patches['ppt/slides/slide3.xml'] = patch_slide(files['ppt/slides/slide3.xml'], [bar3, gf3])

    # === SLIDE 4 ===
    rh4 = calc_row_h(len(s4_rows))
    cw4 = [900000,1200000,1300000,500000,980000,980000,753144]
    bar4 = header_bar('SERVICEABLE EFS CYLINDERS — DUE WITHIN 90 DAYS', len(s4_rows),
                      TABLE_X, TABLE_Y, TABLE_CX, BAR_H, bg=ORANGE, fid=203)
    tbl4 = build_table(['H/C','DESIGNATION','P/N','S/N','NEXT 18M','NEXT 60M','DAYS LEFT'],
                       s4_rows, cw4, rh4, hdr_bg=ORANGE, days_col=6)
    gf4  = graphicFrame(tbl4, TABLE_X, TABLE_Y+BAR_H, TABLE_CX, rh4*(len(s4_rows)+1), fid=103)
    patches['ppt/slides/slide4.xml'] = patch_slide(files['ppt/slides/slide4.xml'], [bar4, gf4])

    # Write
    with zipfile.ZipFile(OUTPUT_PATH,'w',zipfile.ZIP_DEFLATED) as z:
        for name, data in files.items():
            z.writestr(name, patches.get(name, data))

    print(f"\n Fichier gnr:")
    print(f"   {OUTPUT_PATH}")
    print("="*55)

if __name__ == '__main__':
    main()
