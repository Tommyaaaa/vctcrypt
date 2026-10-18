#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate the 5-language Policies & Terms for VCTCrypt (v2.3.0).

Reads the English + Chinese section lists out of policy_screen.dart, then
translates each string with the free MyMemory API:
  * fr / de : en -> target directly
  * hn      : en -> vi (Vietnamese), then transcribed to Chu Nom with the
              same longest-match lexicon the Dart pipeline uses.

Writes a fresh policy_screen.dart with switch(s.lang) branches.
Run:  python3 tool/gen_policies.py
"""
import json
import re
import subprocess
import sys
import time
import urllib.parse

ROOT = 'lib/screens/policy_screen.dart'
MAP = 'tool/chunom_map.dart'


# ------------------------------------------------------------------ API
def translate(text, target, tries=4):
    q = urllib.parse.quote(text)
    url = f'https://api.mymemory.translated.net/get?q={q}&langpair=en|{target}'
    for _ in range(tries):
        try:
            out = subprocess.run(
                ['curl', '-s', '--max-time', '30', url],
                capture_output=True, text=True).stdout
            j = json.loads(out)
            if j.get('responseStatus') == 200 and not j.get('quotaFinished'):
                t = (j.get('responseData') or {}).get('translatedText') or ''
                if t:
                    return decode_entities(t)
        except Exception:
            pass
        time.sleep(1.0)
    return ''


def decode_entities(s):
    s = (s.replace('&lt;', '<').replace('&gt;', '>')
         .replace('&quot;', '"').replace('&#39;', "'").replace('&amp;', '&'))
    s = re.sub(r'&#x([0-9A-Fa-f]+);', lambda m: chr(int(m.group(1), 16)), s)
    s = re.sub(r'&#(\d+);', lambda m: chr(int(m.group(1))), s)
    return s.replace('\r', '').replace('\n', ' ')


# ---------------------------------------------------- Chu Nom lexicon
def load_lexicon():
    src = open(MAP, encoding='utf-8').read()
    lex = {}
    for m in re.finditer(r"'([^']+)':\s*'([^']+)'", src):
        lex[m.group(1).lower()] = m.group(2)
    return lex


LEX = load_lexicon()
LEX_KEYS = sorted(LEX.keys(), key=len, reverse=True)
WORD_RE = re.compile(r"[\w'\u0300-\u036f]+", re.UNICODE)


def transcribe(vi):
    tokens, word_set = [], set()
    last = 0
    for m in WORD_RE.finditer(vi):
        if m.start() > last:
            tokens.append(vi[last:m.start()])
        tokens.append(m.group(0))
        word_set.add(len(tokens) - 1)
        last = m.end()
    if last < len(vi):
        tokens.append(vi[last:])

    out, i = [], 0
    while i < len(tokens):
        if i not in word_set:
            out.append(tokens[i]); i += 1; continue
        matched = False
        for w in range(6, 0, -1):
            if i + w > len(tokens):
                continue
            if any((i + k) not in word_set for k in range(w)):
                continue
            key = ' '.join(tokens[i + k].lower() for k in range(w))
            if key in LEX:
                out.append(LEX[key]); i += w; matched = True; break
        if not matched:
            out.append(tokens[i]); i += 1
    return ''.join(out)


# -------------------------------------------------- parse current file
SEC_RE = re.compile(r"_Section\(\s*'((?:[^'\\]|\\.)*)'\s*,\s*\[")


def unescape(s):
    return s.replace("\\'", "'").replace('\\\\', '\\')


def parse_list(block):
    """block is the text inside `return [ ... ]`."""
    sections = []
    i = 0
    while True:
        m = SEC_RE.search(block, i)
        if not m:
            break
        heading = unescape(m.group(1))
        # paragraph list starts right after the '['
        j = m.end() - 1  # at '['
        depth = 0
        paras = []
        k = j
        while k < len(block):
            c = block[k]
            if c == '[':
                depth += 1
            elif c == ']':
                depth -= 1
                if depth == 0:
                    break
            elif c == "'" and depth == 1:
                # read string literal
                k += 1
                buf = []
                while k < len(block):
                    if block[k] == '\\' and k + 1 < len(block):
                        buf.append(block[k:k + 2]); k += 2; continue
                    if block[k] == "'":
                        break
                    buf.append(block[k]); k += 1
                paras.append(unescape(''.join(buf)))
            k += 1
        sections.append([heading, paras])
        i = k + 1
    return sections


def parse_functions(src):
    """Return (zh_privacy, en_privacy, zh_terms, en_terms)."""
    def fn_body(name):
        start = src.index('List<_Section> ' + name)
        b = src.index('{', start)
        depth, end = 0, b
        for i in range(b, len(src)):
            if src[i] == '{':
                depth += 1
            elif src[i] == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        return src[start:end]

    result = []
    for name in ('_privacySections', '_termsSections'):
        body = fn_body(name)
        rets = [m.start() for m in re.finditer(r'return \[', body)]
        # first return = Chinese block, second = English block
        r1, r2 = rets[0], rets[1]
        zh_block = body[r1 + len('return ['):body.index('];', r1)]
        en_block = body[r2 + len('return ['):body.index('];', r2)]
        result.append(parse_list(zh_block))
        result.append(parse_list(en_block))
    return result


# --------------------------------------------------------------- emit
def esc(s):
    return s.replace('\\', '\\\\').replace("'", "\\'")


def emit_list(sections, indent):
    buf = ['[\n']
    for heading, paras in sections:
        buf.append(f"{indent}_Section('{esc(heading)}', [\n")
        for p in paras:
            buf.append(f"{indent}  '{esc(p)}',\n")
        buf.append(f"{indent}]),\n")
    buf.append(f"{indent}]")
    return ''.join(buf)


def emit_fn(name, en, zh, fr, de, hn):
    return (
        f"List<_Section> {name}(AppStrings s) {{\n"
        f"  switch (s.lang) {{\n"
        f"    case AppLanguage.english:\n"
        f"      return {emit_list(en, '        ')};\n"
        f"    case AppLanguage.french:\n"
        f"      return {emit_list(fr, '        ')};\n"
        f"    case AppLanguage.german:\n"
        f"      return {emit_list(de, '        ')};\n"
        f"    case AppLanguage.hannom:\n"
        f"      return {emit_list(hn, '        ')};\n"
        f"    default:\n"
        f"      return {emit_list(zh, '        ')};\n"
        f"  }}\n"
        f"}}\n"
    )


def translate_sections(en_sections, target):
    out = []
    for heading, paras in en_sections:
        if target == 'hn':
            vi = translate(heading, 'vi')
            h = transcribe(vi) if vi else heading
            ps = []
            for p in paras:
                vp = translate(p, 'vi')
                ps.append(transcribe(vp) if vp else p)
        else:
            h = translate(heading, target)
            h = h or heading
            ps = []
            for p in paras:
                t = translate(p, target)
                ps.append(t or p)
        out.append([h, ps])
    return out


def main():
    src = open(ROOT, encoding='utf-8').read()
    zhP, enP, zhT, enT = parse_functions(src)
    print(f'parsed: privacy zh={len(zhP)} en={len(enP)}; '
          f'terms zh={len(zhT)} en={len(enT)}')

    results = {}
    for lang in ('fr', 'de', 'hn'):
        results[lang + '_p'] = translate_sections(enP, lang)
        print(f'  {lang} privacy done')
        results[lang + '_t'] = translate_sections(enT, lang)
        print(f'  {lang} terms done')

    newP = emit_fn('_privacySections', enP, zhP,
                   results['fr_p'], results['de_p'], results['hn_p'])
    newT = emit_fn('_termsSections', enT, zhT,
                   results['fr_t'], results['de_t'], results['hn_t'])

    def fn_range(name):
        start = src.index('List<_Section> ' + name)
        b = src.index('{', start)
        depth, end = 0, b
        for i in range(b, len(src)):
            if src[i] == '{':
                depth += 1
            elif src[i] == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        return start, end

    ts, te = fn_range('_termsSections')
    ps, pe = fn_range('_privacySections')
    out = src[:ts] + newT + src[te:]
    out = out[:ps] + newP + out[pe:]
    open(ROOT, 'w', encoding='utf-8').write(out)
    print('wrote', ROOT)


if __name__ == '__main__':
    main()
