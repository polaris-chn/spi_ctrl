#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Improved GD25LF256F.pdf text extractor.

Differences vs v1:
- Handles hex-string text <...> and <...>TJ (v1 only handled literal strings).
- Resolves Type0 (Identity-H) fonts via /ToUnicode CMaps.
- Recursively decodes Form XObjects and applies the same font-aware parsing.
- Keeps original ( )Tj parsing too.
"""
import re, zlib, json, os

SRC = 'GD25LF256F.pdf'
OUT_TXT = 'pdf_analysis/GD25LF256F_extracted_v2_by_page.txt'
OUT_JSON = 'pdf_analysis/GD25LF256F_extracted_v2_by_page.json'

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

# ---------- ToUnicode CMap cache ----------
cmap_cache = {}

def get_cmap(oid):
    if not oid:
        return {}
    if oid in cmap_cache:
        return cmap_cache[oid]
    body = objs.get(oid, b'')
    txt = decode_stream(body).decode('latin1', 'ignore')
    if not txt.strip():
        txt = body.decode('latin1', 'ignore')
    mapping = {}
    for m in re.finditer(r'beginbfchar\s*(.*?)endbfchar', txt, re.S):
        for pair in re.finditer(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>', m.group(1)):
            mapping[int(pair.group(1), 16)] = int(pair.group(2), 16)
    for m in re.finditer(r'beginbfrange\s*(.*?)endbfrange', txt, re.S):
        for r in re.finditer(r'<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>\s*<([0-9A-Fa-f]+)>', m.group(1)):
            a = int(r.group(1), 16); b = int(r.group(2), 16); s = int(r.group(3), 16)
            for code in range(a, b + 1):
                mapping[code] = s + (code - a)
    cmap_cache[oid] = mapping
    return mapping

def font_to_unicode_oid(font_oid):
    body = objs.get(font_oid, b'')
    m = re.search(rb'/ToUnicode\s+(\d+)\s+\d+\s+R', body)
    return int(m.group(1)) if m else None

def font_is_type0(font_oid):
    body = objs.get(font_oid, b'')
    return b'/Subtype/Type0' in body or b'/Subtype /Type0' in body

# ---------- string decoding ----------
def parse_text_array(s):
    """Split a TJ array body into ('lit'|'hex'|'num', value) tokens."""
    parts = []
    i = 0
    n = len(s)
    while i < n:
        c = s[i:i+1]
        if c == b'(':
            depth = 1; j = i + 1
            while j < n and depth > 0:
                if s[j:j+1] == b'\\':
                    j += 2; continue
                elif s[j:j+1] == b'(':
                    depth += 1
                elif s[j:j+1] == b')':
                    depth -= 1
                j += 1
            parts.append(('lit', s[i+1:j-1]))
            i = j
        elif c == b'<':
            j = s.find(b'>', i)
            if j == -1:
                break
            parts.append(('hex', s[i+1:j].strip()))
            i = j + 1
        elif c.isdigit() or c in b'+-':
            m = re.match(rb'[-+]?\d+', s[i:])
            if m:
                parts.append(('num', m.group(0)))
                i = m.end()
            else:
                i += 1
        else:
            i += 1
    return parts

def decode_literal(raw):
    out = bytearray()
    i = 0
    while i < len(raw):
        b = raw[i:i+1]
        if b == b'\\':
            nxt = raw[i+1:i+2]
            if nxt in (b'(', b')', b'\\'):
                out += nxt; i += 2
            elif nxt == b'n':
                out += b'\n'; i += 2
            elif nxt == b'r':
                out += b'\r'; i += 2
            elif nxt == b't':
                out += b'\t'; i += 2
            elif nxt.isdigit():
                m = re.match(rb'\\(\d{1,3})', raw[i:])
                if m:
                    out.append(int(m.group(1), 8) & 0xff); i = m.end()
                else:
                    i += 1
            else:
                out += nxt; i += 2
        else:
            out.append(raw[i]); i += 1
    return out.decode('latin1', 'ignore')

def decode_hex(hexs, cmap):
    hx = hexs.replace(b' ', b'')
    out = []
    for k in range(0, len(hx) - 1, 4):
        code = int(hx[k:k+4], 16)
        cp = cmap.get(code)
        if cp is None:
            # identity fallback for latin-ish codes
            if 32 <= code <= 126:
                out.append(chr(code))
            elif code < 0x20 and code != 0:
                out.append(' ')
            else:
                out.append(f'<{code:04X}>')
        else:
            out.append(chr(cp))
    return ''.join(out)

def text_from_block(b, font_refs):
    """Given a BT...ET block bytes and page font table, return text."""
    fm = re.search(rb'/([A-Za-z0-9_.]*)\s+([\d.]+)\s+Tf', b)
    if not fm:
        return ''
    fname = fm.group(1).decode('latin1', 'ignore')
    font_oid = font_refs.get(fname)
    cmap = {}
    if font_oid and font_is_type0(font_oid):
        cmap = get_cmap(font_to_unicode_oid(font_oid))
    parts_out = []
    tjm = re.search(rb'\[(.*?)\]\s*TJ', b, re.S)
    if tjm:
        for typ, val in parse_text_array(tjm.group(1)):
            if typ == 'lit':
                parts_out.append(decode_literal(val))
            elif typ == 'hex':
                parts_out.append(decode_hex(val, cmap))
            elif typ == 'num':
                try:
                    if int(val) < -100:
                        parts_out.append(' ')
                except ValueError:
                    pass
    else:
        m = re.search(rb'\((.*?)\)\s*Tj', b, re.S)
        if m:
            parts_out.append(decode_literal(m.group(1)))
        else:
            m = re.search(rb'<([0-9A-Fa-f]+)>\s*Tj', b)
            if m:
                parts_out.append(decode_hex(m.group(1), cmap))
    text = ''.join(parts_out)
    # cleanup escape leftovers
    text = text.replace('\x00', '')
    return text

# ---------- page tree ----------
def get_kids(oid):
    body = objs.get(oid, b'')
    m = re.search(rb'/Kids\s*\[(.*?)\]', body, re.S)
    if m:
        return [int(k) for k in re.findall(rb'(\d+)\s+\d+\s+R', m.group(1))]
    return []

def resolve_pages(oid):
    out = []
    for k in get_kids(oid):
        kb = objs.get(k, b'')
        if kb and b'/Type/Pages' in kb:
            out += resolve_pages(k)
        else:
            out.append(k)
    return out

pages = resolve_pages(2)

def page_resources(page_body):
    m = re.search(rb'/Resources\s*<<(.*?)>>/MediaBox', page_body, re.S)
    res = m.group(1) if m else page_body
    return res

def font_refs_from_res(res):
    refs = {}
    m = re.search(rb'/Font\s*<<(.*?)>>', res, re.S)
    if m:
        for mm in re.finditer(rb'/([A-Za-z0-9_.]*)\s*(\d+)\s+\d+\s+R', m.group(1)):
            refs[mm.group(1).decode('latin1', 'ignore')] = int(mm.group(2))
    return refs

def xobject_refs_from_res(res):
    refs = []
    m = re.search(rb'/XObject\s*<<(.*?)>>', res, re.S)
    if m:
        for mm in re.finditer(rb'/([A-Za-z0-9_.]*)\s*(\d+)\s+\d+\s+R', m.group(1)):
            refs.append((mm.group(1).decode('latin1', 'ignore'), int(mm.group(2))))
    return refs

def content_stream_ids(page_body):
    ids = []
    for m in re.finditer(rb'/Contents\s*(\d+)\s+\d+\s+R', page_body):
        ids.append(int(m.group(1)))
    return ids

def extract_stream_text(dec, font_refs):
    """Extract text from decoded content stream, following Form XObjects."""
    texts = []
    for block in re.finditer(rb'BT\s*(.*?)\s*ET', dec, re.S):
        t = text_from_block(block.group(1), font_refs)
        if t:
            texts.append(t)
    # Form XObjects
    for fm in re.finditer(rb'/Fm(\d+)\s+Do', dec):
        pass
    return texts

# ---------- main extraction ----------
page_texts = {}
for idx, pid in enumerate(pages, 1):
    body = objs.get(pid, b'')
    res = page_resources(body)
    font_refs = font_refs_from_res(res)
    xobjs = xobject_refs_from_res(res)
    all_texts = []
    for cid in content_stream_ids(body):
        dec = decode_stream(objs.get(cid, b''))
        if not dec:
            continue
        # parse text blocks and xobject Do names in order? For now: blocks then forms.
        all_texts += extract_stream_text(dec, font_refs)
    # Recursively decode Form XObjects referenced by this page (one level enough in practice)
    seen = set()
    queue = list(xobjs)
    while queue:
        xname, xid = queue.pop(0)
        if xid in seen:
            continue
        seen.add(xid)
        xbody = objs.get(xid, b'')
        xres = page_resources(xbody) if b'/Resources' in xbody else res
        xfont_refs = font_refs_from_res(xres)
        if not xfont_refs:
            xfont_refs = font_refs
        xdec = decode_stream(xbody)
        if xdec:
            all_texts += extract_stream_text(xdec, xfont_refs)
            # nested forms
            for name2, xid2 in xobject_refs_from_res(xres):
                if xid2 not in seen:
                    queue.append((name2, xid2))
    page_texts[idx] = all_texts

# write txt
with open(OUT_TXT, 'w', encoding='utf-8') as f:
    for idx in sorted(page_texts):
        f.write(f'\n===== PAGE {idx} =====\n')
        for t in page_texts[idx]:
            f.write('  | ' + t + '\n')

# write json
with open(OUT_JSON, 'w', encoding='utf-8') as f:
    json.dump(page_texts, f, ensure_ascii=False, indent=1)

print('done', len(page_texts), 'pages ->', OUT_TXT, OUT_JSON)
