#!/usr/bin/env python3
"""
Components Bay - Weekly Slide Generator
Generates Component_Bay_Slide.pptx from Supabase data
Run every Wednesday after the EFS sync
"""

import requests
import json
import zipfile
import shutil
import os
import sys
from datetime import datetime, timedelta
from copy import deepcopy
import xml.etree.ElementTree as ET

# ============================================================
# CONFIGURATION
# ============================================================
SUPABASE_URL = "https://nwidtkiteamvnomewjux.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im53aWR0a2l0ZWFtdm5vbWV3anV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzEzMTM3MDAsImV4cCI6MjA4Njg4OTcwMH0.fvKwq5B8Bdr2Hv67yvB6JRKA2Gu3xTIEgPmcmJj0nvI"

# Template PPTX path (same folder as this script)
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
TEMPLATE_PATH = os.path.join(SCRIPT_DIR, "Component_Bay_Slide_Template.pptx")

# Output path - Desktop
OUTPUT_PATH = os.path.join(r"C:\Users\jpellegrini\Desktop\APP 5.5",
    f"Component_Bay_Slide_{datetime.now().strftime('%Y-%m-%d')}.pptx")

# Colors (EMU units, hex)
RED     = "FF0000"
ORANGE  = "E8A000"
GRAY_H  = "D9D9D9"  # header row background
WHITE   = "FFFFFF"
BLACK   = "000000"
ORANGE_H= "E8A000"  # table header bg
LIGHT   = "F5F5F5"  # alternating row

# ============================================================
# NAMESPACES
# ============================================================
NS = {
    'a':  'http://schemas.openxmlformats.org/drawingml/2006/main',
    'p':  'http://schemas.openxmlformats.org/presentationml/2006/main',
    'r':  'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'pkg':'http://schemas.openxmlformats.org/package/2006/relationships',
}
for prefix, uri in NS.items():
    ET.register_namespace(prefix, uri)
ET.register_namespace('', 'http://schemas.openxmlformats.org/drawingml/2006/main')

# ============================================================
# SUPABASE HELPER
# ============================================================
def fetch_table(table):
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json"
    }
    resp = requests.get(f"{SUPABASE_URL}/rest/v1/{table}?select=*", headers=headers)
    resp.raise_for_status()
    items = []
    for row in resp.json():
        d = row.get('data', {})
        if isinstance(d, str):
            d = json.loads(d)
        items.append(d)
    return items

# ============================================================
# DATE HELPERS
# ============================================================
def days_left(date_str):
    if not date_str:
        return None
    try:
        dt = datetime.strptime(date_str[:10], '%Y-%m-%d')
        return (dt.date() - datetime.now().date()).days
    except:
        return None

def within_90(date_str):
    d = days_left(date_str)
    return d is not None and 0 <= d <= 90

# ============================================================
# XML TABLE BUILDER
# ============================================================
def emu(cm):
    """Convert cm to EMU"""
    return int(cm * 360000)

def clr_elem(hex_color):
    clr = ET.Element('{http://schemas.openxmlformats.org/drawingml/2006/main}solidFill')
    srgb = ET.SubElement(clr, '{http://schemas.openxmlformats.org/drawingml/2006/main}srgbClr')
    srgb.set('val', hex_color)
    return clr

def make_tc(text, bold=False, font_size=1400, fg_color=BLACK, bg_color=None, align='l', italic=False):
    """Make a table cell <a:tc>"""
    tc = ET.Element('{http://schemas.openxmlformats.org/drawingml/2006/main}tc')
    txBody = ET.SubElement(tc, '{http://schemas.openxmlformats.org/drawingml/2006/main}txBody')
    bodyPr = ET.SubElement(txBody, '{http://schemas.openxmlformats.org/drawingml/2006/main}bodyPr')
    ET.SubElement(txBody, '{http://schemas.openxmlformats.org/drawingml/2006/main}lstStyle')
    p = ET.SubElement(txBody, '{http://schemas.openxmlformats.org/drawingml/2006/main}p')
    pPr = ET.SubElement(p, '{http://schemas.openxmlformats.org/drawingml/2006/main}pPr')
    pPr.set('algn', align)

    if text:
        r = ET.SubElement(p, '{http://schemas.openxmlformats.org/drawingml/2006/main}r')
        rPr = ET.SubElement(r, '{http://schemas.openxmlformats.org/drawingml/2006/main}rPr')
        rPr.set('lang', 'en-US')
        rPr.set('sz', str(font_size))
        if bold:
            rPr.set('b', '1')
        if italic:
            rPr.set('i', '1')
        rPr.set('dirty', '0')
        fill = clr_elem(fg_color)
        rPr.append(fill)
        t = ET.SubElement(r, '{http://schemas.openxmlformats.org/drawingml/2006/main}t')
        t.text = str(text)
    else:
        ET.SubElement(p, '{http://schemas.openxmlformats.org/drawingml/2006/main}endParaRPr').set('lang','en-US')

    # Cell properties
    tcPr = ET.SubElement(tc, '{http://schemas.openxmlformats.org/drawingml/2006/main}tcPr')
    if bg_color:
        tcPr.append(clr_elem(bg_color))
    else:
        ET.SubElement(tcPr, '{http://schemas.openxmlformats.org/drawingml/2006/main}noFill')

    return tc

def make_table_xml(headers, rows, col_widths, row_height,
                   header_bg=ORANGE_H, header_fg=WHITE,
                   alt_row_bg=LIGHT, days_col_idx=None):
    """Build a complete <a:tbl> element"""
    a = 'http://schemas.openxmlformats.org/drawingml/2006/main'

    tbl = ET.Element(f'{{{a}}}tbl')
    tblPr = ET.SubElement(tbl, f'{{{a}}}tblPr')
    tblPr.set('firstRow', '1')
    tblPr.set('bandRow', '0')

    # Column grid
    tblGrid = ET.SubElement(tbl, f'{{{a}}}tblGrid')
    for w in col_widths:
        gc = ET.SubElement(tblGrid, f'{{{a}}}gridCol')
        gc.set('w', str(w))

    # Header row
    tr = ET.SubElement(tbl, f'{{{a}}}tr')
    tr.set('h', str(row_height))
    for i, h in enumerate(headers):
        tr.append(make_tc(h, bold=True, font_size=1100, fg_color=header_fg,
                          bg_color=header_bg if i == 0 else header_bg))

    # Data rows
    for ri, row in enumerate(rows):
        tr = ET.SubElement(tbl, f'{{{a}}}tr')
        tr.set('h', str(row_height))
        row_bg = None if ri % 2 == 0 else alt_row_bg
        for ci, cell in enumerate(row):
            fg = BLACK
            if days_col_idx is not None and ci == days_col_idx and cell:
                try:
                    d = int(str(cell).replace(' days','').replace('d',''))
                    if d <= 30:
                        fg = RED
                    elif d <= 60:
                        fg = ORANGE_H
                except:
                    pass
            tr.append(make_tc(str(cell) if cell else '', font_size=1000,
                               fg_color=fg, bg_color=row_bg))
    return tbl

def wrap_table_in_graphicFrame(tbl, x, y, cx, cy):
    """Wrap a table in a <p:graphicFrame>"""
    p = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    a = 'http://schemas.openxmlformats.org/drawingml/2006/main'
    r = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'

    gf = ET.Element(f'{{{p}}}graphicFrame')

    nvGraphicFramePr = ET.SubElement(gf, f'{{{p}}}nvGraphicFramePr')
    cNvPr = ET.SubElement(nvGraphicFramePr, f'{{{p}}}cNvPr')
    cNvPr.set('id', '100')
    cNvPr.set('name', 'DataTable')
    ET.SubElement(nvGraphicFramePr, f'{{{p}}}cNvGraphicFramePr')
    ET.SubElement(nvGraphicFramePr, f'{{{p}}}nvPr')

    xfrm = ET.SubElement(gf, f'{{{p}}}xfrm')
    off = ET.SubElement(xfrm, f'{{{a}}}off')
    off.set('x', str(x)); off.set('y', str(y))
    ext = ET.SubElement(xfrm, f'{{{a}}}ext')
    ext.set('cx', str(cx)); ext.set('cy', str(cy))

    graphic = ET.SubElement(gf, f'{{{a}}}graphic')
    graphicData = ET.SubElement(graphic, f'{{{a}}}graphicData')
    graphicData.set('uri', 'http://schemas.openxmlformats.org/drawingml/2006/table')
    graphicData.append(tbl)

    return gf

def make_header_bar(title, count, x, y, cx, cy, bg_color=RED):
    """Orange/red header bar above table"""
    p = 'http://schemas.openxmlformats.org/presentationml/2006/main'
    a = 'http://schemas.openxmlformats.org/drawingml/2006/main'

    sp = ET.Element(f'{{{p}}}sp')
    nvSpPr = ET.SubElement(sp, f'{{{p}}}nvSpPr')
    cNvPr = ET.SubElement(nvSpPr, f'{{{p}}}cNvPr')
    cNvPr.set('id', '101'); cNvPr.set('name', 'HeaderBar')
    ET.SubElement(nvSpPr, f'{{{p}}}cNvSpPr')
    ET.SubElement(nvSpPr, f'{{{p}}}nvPr')

    spPr = ET.SubElement(sp, f'{{{p}}}spPr')
    xfrm = ET.SubElement(spPr, f'{{{a}}}xfrm')
    off = ET.SubElement(xfrm, f'{{{a}}}off'); off.set('x', str(x)); off.set('y', str(y))
    ext = ET.SubElement(xfrm, f'{{{a}}}ext'); ext.set('cx', str(cx)); ext.set('cy', str(cy))
    prstGeom = ET.SubElement(spPr, f'{{{a}}}prstGeom'); prstGeom.set('prst','rect')
    ET.SubElement(prstGeom, f'{{{a}}}avLst')
    sf = ET.SubElement(spPr, f'{{{a}}}solidFill')
    ET.SubElement(sf, f'{{{a}}}srgbClr').set('val', bg_color)

    txBody = ET.SubElement(sp, f'{{{p}}}txBody')
    bodyPr = ET.SubElement(txBody, f'{{{a}}}bodyPr')
    bodyPr.set('anchor','ctr')
    ET.SubElement(txBody, f'{{{a}}}lstStyle')
    para = ET.SubElement(txBody, f'{{{a}}}p')
    pPr = ET.SubElement(para, f'{{{a}}}pPr'); pPr.set('algn','l')
    run = ET.SubElement(para, f'{{{a}}}r')
    rPr = ET.SubElement(run, f'{{{a}}}rPr')
    rPr.set('lang','en-US'); rPr.set('sz','1100'); rPr.set('b','1'); rPr.set('dirty','0')
    fill = ET.SubElement(rPr, f'{{{a}}}solidFill')
    ET.SubElement(fill, f'{{{a}}}srgbClr').set('val', WHITE)
    t = ET.SubElement(run, f'{{{a}}}t')
    t.text = f"  ⚠  {title.upper()}"

    # Count badge on right
    run2 = ET.SubElement(para, f'{{{a}}}r')
    rPr2 = ET.SubElement(run2, f'{{{a}}}rPr')
    rPr2.set('lang','en-US'); rPr2.set('sz','1100'); rPr2.set('b','1'); rPr2.set('dirty','0')
    fill2 = ET.SubElement(rPr2, f'{{{a}}}solidFill')
    ET.SubElement(fill2, f'{{{a}}}srgbClr').set('val', WHITE)
    t2 = ET.SubElement(run2, f'{{{a}}}t')
    t2.text = f"{'':>50}{count}"

    return sp

# ============================================================
# SLIDE BUILDERS - replace image with real table
# ============================================================
def replace_image_with_table(slide_xml_str, graphicFrame):
    """Remove the pic element and insert a graphicFrame"""
    root = ET.fromstring(slide_xml_str)

    spTree = root.find('.//{http://schemas.openxmlformats.org/presentationml/2006/main}spTree')
    if spTree is None:
        return slide_xml_str

    # Remove all pic elements (screenshots)
    pics = spTree.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}pic')
    for pic in pics:
        spTree.remove(pic)

    # Add the table
    spTree.append(graphicFrame)

    ET.register_namespace('p', 'http://schemas.openxmlformats.org/presentationml/2006/main')
    ET.register_namespace('a', 'http://schemas.openxmlformats.org/drawingml/2006/main')
    ET.register_namespace('r', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships')

    return ET.tostring(root, encoding='unicode', xml_declaration=False)

# ============================================================
# MAIN
# ============================================================
def main():
    print("=" * 50)
    print("  Components Bay - Weekly Slide Generator")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print("=" * 50)

    if not os.path.exists(TEMPLATE_PATH):
        print(f"ERREUR: Template introuvable: {TEMPLATE_PATH}")
        print("Copiez Component_Bay_Slide.pptx dans backup-scripts/ et renommez-le Component_Bay_Slide_Template.pptx")
        sys.exit(1)

    print("\nChargement des données Supabase...")

    # Fetch all data
    try:
        efs_data      = fetch_table('efs')
        efs_cyl_data  = fetch_table('efs_cylinders')
        liferaft_data = fetch_table('liferafts')
        maintenance   = fetch_table('maintenance')
        composite     = fetch_table('composite')
        avionic       = fetch_table('avionic')
        engine        = fetch_table('engine')
        rotorbay      = fetch_table('rotorbay')
        iaft          = fetch_table('iafteaft')
        pol           = fetch_table('pol')
        tools         = fetch_table('tools')
        troopseats    = fetch_table('troopseats')
    except Exception as e:
        print(f"ERREUR Supabase: {e}")
        sys.exit(1)

    today = datetime.now().date()

    # ---- SLIDE 1: Other Parts U/S ----
    # All U/S except Life Raft and EFS
    us_modules = [
        ('Maintenance', maintenance),
        ('Composite',   composite),
        ('Avionic',     avionic),
        ('Engine',      engine),
        ('Rotor Bay',   rotorbay),
        ('IAFT/EAFT',   iaft),
        ('POL',         pol),
        ('Tools',       tools),
        ('Troop Seat',  troopseats),
        ('EFS Float',   efs_data),
        ('EFS Cyl.',    efs_cyl_data),
    ]
    slide1_rows = []
    for mod_name, items in us_modules:
        for item in items:
            if item.get('serviceability') == 'Unserviceable':
                pn = item.get('pnWheel') or item.get('partNumber','')
                slide1_rows.append([
                    mod_name,
                    item.get('designation',''),
                    pn,
                    item.get('serialNumber',''),
                    item.get('reason','Unserviceable')
                ])

    # ---- SLIDE 2: Life Raft U/S ----
    slide2_rows = []
    for item in liferaft_data:
        if item.get('serviceability') == 'Unserviceable':
            slide2_rows.append([
                'Life Raft',
                item.get('partNumber',''),
                item.get('serialNumber',''),
                item.get('reason','Unserviceable')
            ])

    # ---- SLIDE 3: EFS within 90 days ----
    slide3_rows = []
    for item in efs_data:
        if item.get('serviceability') == 'Unserviceable':
            continue
        soonest = None
        soonest_days = 999
        for field in ['next18M','next36M']:
            d = days_left(item.get(field,''))
            if d is not None and 0 <= d <= 90:
                if d < soonest_days:
                    soonest_days = d
                    soonest = field
        if soonest:
            slide3_rows.append([
                item.get('hc',''),
                item.get('designation',''),
                item.get('partNumber',''),
                item.get('serialNumber',''),
                item.get('next18M',''),
                item.get('next36M',''),
                f"{soonest_days} days"
            ])
    slide3_rows.sort(key=lambda r: int(r[6].replace(' days','')))

    # ---- SLIDE 4: EFS Cylinders within 90 days ----
    slide4_rows = []
    for item in efs_cyl_data:
        if item.get('serviceability') == 'Unserviceable':
            continue
        soonest_days = 999
        for field in ['next18M','next60M']:
            d = days_left(item.get(field,''))
            if d is not None and 0 <= d <= 90:
                if d < soonest_days:
                    soonest_days = d
        if soonest_days < 999:
            slide4_rows.append([
                item.get('hc',''),
                item.get('designation',''),
                item.get('partNumber',''),
                item.get('serialNumber',''),
                item.get('next18M',''),
                item.get('next60M',''),
                f"{soonest_days} days"
            ])
    slide4_rows.sort(key=lambda r: int(r[6].replace(' days','')))

    print(f"  Slide 1 (Other Parts U/S): {len(slide1_rows)} items")
    print(f"  Slide 2 (Life Raft U/S):   {len(slide2_rows)} items")
    print(f"  Slide 3 (EFS 90d):         {len(slide3_rows)} items")
    print(f"  Slide 4 (EFS Cyl 90d):     {len(slide4_rows)} items")

    # ---- Table dimensions (EMU) ----
    # Right side table area: x≈4777316, y≈1478384, cx≈6780700
    TX = 4777316;  TY = 1300000
    TCX = 6780700; ROW_H = 400000
    BAR_H = 500000

    def build_slide_xml(slide_num, headers, rows, col_w, days_col=None,
                        bar_title='', bar_color=RED):
        bar = make_header_bar(bar_title, len(rows),
                              TX, TY, TCX, BAR_H, bg_color=bar_color)
        tbl = make_table_xml(headers, rows, col_w, ROW_H,
                              days_col_idx=days_col)
        n_rows = len(rows) + 1  # +1 header
        table_cy = ROW_H * n_rows
        gf = wrap_table_in_graphicFrame(tbl,
                                        TX, TY + BAR_H,
                                        TCX, table_cy)
        return bar, gf

    # Column widths for each slide
    cw1 = [900000, 1500000, 1400000, 700000, 2280700]   # Module,Desig,P/N,S/N,Reason
    cw2 = [1000000, 1500000, 1000000, 3280700]           # Module,P/N,S/N,Reason
    cw3 = [800000, 1200000, 1400000, 500000, 1000000, 1000000, 880700]  # HC,Desig,P/N,SN,18M,36M,Days
    cw4 = [800000, 1400000, 1400000, 500000, 1000000, 1000000, 680700]  # HC,Desig,P/N,SN,18M,60M,Days

    # ---- Copy template and patch slides ----
    print("\nGénération du PPTX...")
    shutil.copy2(TEMPLATE_PATH, OUTPUT_PATH)

    with zipfile.ZipFile(OUTPUT_PATH, 'r') as zin:
        all_files = {name: zin.read(name) for name in zin.namelist()}

    # Build slide XMLs
    slide_patches = {}

    # Slide 1
    bar1, gf1 = build_slide_xml(1,
        ['MODULE','DESIGNATION','P/N','S/N','REASON'],
        slide1_rows, cw1, bar_title='ALL UNSERVICEABLE ITEMS (ORDERED)', bar_color='C0392B')
    s1 = all_files['ppt/slides/slide1.xml'].decode('utf-8')
    root1 = ET.fromstring(s1)
    spTree1 = root1.find('.//{http://schemas.openxmlformats.org/presentationml/2006/main}spTree')
    for pic in spTree1.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}pic'):
        spTree1.remove(pic)
    spTree1.append(bar1); spTree1.append(gf1)
    slide_patches['ppt/slides/slide1.xml'] = ET.tostring(root1, encoding='utf-8', xml_declaration=True)

    # Slide 2
    bar2, gf2 = build_slide_xml(2,
        ['MODULE','P/N','S/N','REASON'],
        slide2_rows, cw2, bar_title='LIFE RAFT — NEED TO BE C/OUT', bar_color='C0392B')
    s2 = all_files['ppt/slides/slide2.xml'].decode('utf-8')
    root2 = ET.fromstring(s2)
    spTree2 = root2.find('.//{http://schemas.openxmlformats.org/presentationml/2006/main}spTree')
    for pic in spTree2.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}pic'):
        spTree2.remove(pic)
    spTree2.append(bar2); spTree2.append(gf2)
    slide_patches['ppt/slides/slide2.xml'] = ET.tostring(root2, encoding='utf-8', xml_declaration=True)

    # Slide 3
    bar3, gf3 = build_slide_xml(3,
        ['H/C','DESIGNATION','P/N','S/N','NEXT 18M','NEXT 36M','DAYS LEFT'],
        slide3_rows, cw3, days_col=6,
        bar_title='SERVICEABLE EFS — INSPECTION DUE WITHIN 90 DAYS', bar_color='E8A000')
    s3 = all_files['ppt/slides/slide3.xml'].decode('utf-8')
    root3 = ET.fromstring(s3)
    spTree3 = root3.find('.//{http://schemas.openxmlformats.org/presentationml/2006/main}spTree')
    for pic in spTree3.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}pic'):
        spTree3.remove(pic)
    spTree3.append(bar3); spTree3.append(gf3)
    slide_patches['ppt/slides/slide3.xml'] = ET.tostring(root3, encoding='utf-8', xml_declaration=True)

    # Slide 4
    bar4, gf4 = build_slide_xml(4,
        ['H/C','DESIGNATION','P/N','S/N','NEXT 18M','NEXT 60M','DAYS LEFT'],
        slide4_rows, cw4, days_col=6,
        bar_title='SERVICEABLE EFS CYLINDERS — INSPECTION DUE WITHIN 90 DAYS', bar_color='E8A000')
    s4 = all_files['ppt/slides/slide4.xml'].decode('utf-8')
    root4 = ET.fromstring(s4)
    spTree4 = root4.find('.//{http://schemas.openxmlformats.org/presentationml/2006/main}spTree')
    for pic in spTree4.findall('{http://schemas.openxmlformats.org/presentationml/2006/main}pic'):
        spTree4.remove(pic)
    spTree4.append(bar4); spTree4.append(gf4)
    slide_patches['ppt/slides/slide4.xml'] = ET.tostring(root4, encoding='utf-8', xml_declaration=True)

    # Write patched PPTX
    with zipfile.ZipFile(OUTPUT_PATH, 'w', zipfile.ZIP_DEFLATED) as zout:
        for name, data in all_files.items():
            if name in slide_patches:
                zout.writestr(name, slide_patches[name])
            else:
                zout.writestr(name, data)

    print(f"\n✅ Fichier généré: {OUTPUT_PATH}")
    print("=" * 50)

if __name__ == '__main__':
    main()
