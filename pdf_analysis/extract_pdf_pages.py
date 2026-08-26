#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Extract text from GD25LF256F.pdf in real page order.

Compared with the first version, this version also recursively decodes
Form XObjects referenced by each page (waveform diagrams are often stored
in /Subtype/Form streams and are invisible to a top-level content-stream scan).
"""
import re, zlib, json, os

SRC = 'GD25LF256F.pdf'
OUT_TXT = 'pdf_analysis/GD25LF256F_extracted_by_page.txt'
OUT_JSON = 'pdf_analysis/GD25LF256F_extracted_by_page.json'

data = open(SRC, 'rb').read()
objs = {}
for m in re.finditer(rb'(\d+)\s+(\d+)\s+obj\b(.*?)endobj', data, re.S):
    objs[int(m.group(1))] = m.group(3)

def decode_stream(body):
    m = re.search(rb'stream\r?\n(.*?)endstream', body, re.S)
    if not m:
        return b''
    raw = m.group(1)
    if raw.endswith(b'\r\n'):
        raw = raw[:-2]
    elif raw.endswith(b'\n'):
        raw = raw[:-1]
    elif raw.endswith(b'\r'):
        raw = raw[:-1]
    try:
        return zlib.decompress(raw)
    except Exception:
        return raw

def extract_text(dec):
    parts = []
    for tm in re.finditer(rb'\((?:[^()\\]|\\.)*\)\s*Tj', dec):
        st = re.search(rb'\((.*)\)\s*Tj', tm.group(0), re.S)
        if st:
            parts.append(st.group(1))
    for tm in re.finditer(rb'\[(.*?)\]\s*TJ', dec, re.S):
        for sm in re.finditer(rb'\((?:[^()\\]|\\.)*\)', tm.group(1)):
            parts.append(sm.group(0)[1:-1])
    out = b' | '.join(parts)
    out = out.replace(b'\\(', b'(').replace(b'\\)', b')').replace(b'\\\\', b'\\')
    return out.decode('latin1', 'ignore')

def page_xobject_refs(page_body):
    refs = []
    m = re.search(rb'/Resources\s*<<(.*?)>>/MediaBox', page_body, re.S)
    res = m.group(1) if m else page_body
    xm = re.search(rb'/XObject\s*<<(.*?)>>', res, re.S)
    if xm:
        for mm in re.finditer(rb'/([A-Za-z0-9_.]*)\s*(\d+)\s+\d+\s+R', xm.group(1)):
            refs.append((mm.group(1).decode('latin1', 'ignore'), int(mm.group(2))))
    return refs

def page_contents(page_body):
    refs = []
    cm = re.search(rb'/Contents\s+((?:\[[^\]]*\]|\d+\s+\d+\s+R))', page_body)
    if cm:
        g = cm.group(1)
        if g.startswith(b'['):
            refs = [int(x) for x in re.findall(rb'(\d+)\s+\d+\s+R', g)]
        else:
            mm = re.match(rb'(\d+)\s+\d+\s+R', g)
            if mm:
                refs = [int(mm.group(1))]
    return refs

def form_texts(page_body):
    """Recursively extract text from Form XObjects referenced by a page."""
    out = []
    seen = set()

    def walk(num, depth=0):
        if num in seen or depth > 12:
            return
        seen.add(num)
        body = objs.get(num, b'')
        if b'/Subtype/Form' not in body:
            return
        txt = extract_text(decode_stream(body)).strip()
        if txt:
            out.append(f'[XObject-{num}] {txt}')
        for _, child in page_xobject_refs(body):
            walk(child, depth + 1)
        # Form content may also directly invoke other XObjects without resource dict regex match;
        # fallback: resolve /Name num 0 R pairs in whole body.
        for mm in re.finditer(rb'/([A-Za-z0-9_.]*)\s*(\d+)\s+\d+\s+R', body):
            name = mm.group(1)
            child = int(mm.group(2))
            if name in (b'Type', b'Subtype', b'Filter', b'Length', b'Matrix', b'BBox', b'Resources', b'FormType'):
                continue
            walk(child, depth + 1)

    for name, num in page_xobject_refs(page_body):
        walk(num)
    return out

def extract_page(page_body):
    parts = []
    for r in page_contents(page_body):
        parts.append(extract_text(decode_stream(objs.get(r, b''))))
    parts.extend(form_texts(page_body))
    return ' '.join(p for p in parts if p.strip())

# real page order from Pages /Kids
m = re.search(rb'/Kids\[([^\]]*)\]', objs[2])
refs = [int(x) for x in re.findall(rb'(\d+)\s+\d+\s+R', m.group(1))]
pages = [extract_page(objs[r]) for r in refs]

os.makedirs('pdf_analysis', exist_ok=True)
with open(OUT_TXT, 'w') as f:
    for i, t in enumerate(pages, 1):
        f.write(f'\n===== PAGE {i} =====\n{t}\n')
with open(OUT_JSON, 'w') as f:
    json.dump(pages, f, ensure_ascii=False, indent=0)
print(f'pages: {len(pages)}')
print(f'wrote {OUT_TXT} and {OUT_JSON}')
