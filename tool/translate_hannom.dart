/// VCTCrypt - Han-Nom translation pipeline (v2.3.0)
///
/// Rebuilds the 𡸨喃 (Chữ Nôm) UI strings the right way:
///   1. extract every English UI string from lib/i18n/strings.dart,
///   2. translate it to Vietnamese with a free API (MyMemory, with a
///      Google gtx fallback) - so the grammar and word order are real
///      Vietnamese, never a Chinese translation,
///   3. transcribe as much as possible into Chữ Nôm via chunom_map.dart,
///      leaving unmatched words in quốc ngữ,
///   4. write the new Han-Nom strings back into strings.dart.
///
/// Run:  dart run tool/translate_hannom.dart
///       dart run tool/translate_hannom.dart --dry-run

import 'dart:convert';
import 'dart:io';

import 'chunom_map.dart';

bool dryRun = false;

// ---------------------------------------------------------------------
// helpers
// ---------------------------------------------------------------------

Future<String> curl(String url) async {
  final p = await Process.run(
    'curl',
    ['-s', '--max-time', '30', '--retry', '1', url],
  );
  if (p.exitCode != 0) throw Exception('curl failed: ${p.stderr}');
  return (p.stdout as String).trim();
}

final _interpRe = RegExp(r'\$\{?([A-Za-z_]\w*)\}?');

/// Protect Dart interpolations and literal \n so the MT engine keeps them.
String protect(String s) {
  var out = s.replaceAll(r'\n', '⟦NL⟧');
  var i = 0;
  out = out.replaceAllMapped(_interpRe, (m) => '⟦${i++}⟧');
  return out;
}

String restore(String s) {
  var out = s.replaceAll('⟦NL⟧', r'\n');
  var i = 0;
  out = out.replaceAllMapped(RegExp(r'⟦(\d+)⟧'), (m) => '⟦X${m.group(1)}⟧');
  // second pass with sequential counter to undo renumbering by MT
  out = out.replaceAllMapped(RegExp(r'⟦X(\d+)⟧'), (m) => '\$${_order[m.group(1)] ?? m.group(1)}');
  return out;
}

/// MyMemory returns HTML entities (e.g. &#x0D;, &amp;); decode the common
/// ones back to plain characters before writing.
String decodeEntities(String s) {
  var out = s
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAllMapped(RegExp(r'&#x([0-9A-Fa-f]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)))
      .replaceAllMapped(RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)));
  return out;
}

// maps the original placeholder number -> the order it was found, used to
// rebuild `$name` style interpolation after MT may reorder placeholders.
Map<String, String> _order = {};

Future<String> translate(String text, String target) async {
  final q = Uri.encodeComponent(text);
  // 1) MyMemory (free, no key)
  try {
    final body = await curl(
        'https://api.mymemory.translated.net/get?q=$q&langpair=en|$target');
    final j = jsonDecode(body) as Map<String, dynamic>;
    if (j['responseStatus'] == 200) {
      final t = (j['responseData'] as Map<String, dynamic>?)?['translatedText']
          as String?;
      if (t != null && t.isNotEmpty && j['quotaFinished'] != true) {
        return t;
      }
    }
  } catch (_) {}
  // 2) Google gtx (free endpoint, no key)
  try {
    final body = await curl(
        'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$target&dt=t&q=$q');
    final j = jsonDecode(body) as List;
    final parts = (j[0] as List).map((e) => (e as List)[0] as String).join();
    if (parts.isNotEmpty) return parts;
  } catch (_) {}
  return '';
}

// ---------------------------------------------------------------------
// Chữ Nôm transcription (longest-match on words)
// ---------------------------------------------------------------------

final _wordRe = RegExp(r"[\p{L}\p{N}\u0300-\u036f']+", unicode: true);

String transcribe(String vi) {
  // split into word tokens + separators
  final tokens = <String>[];
  final wordSet = <int>{};
  var last = 0;
  for (final m in _wordRe.allMatches(vi)) {
    if (m.start > last) tokens.add(vi.substring(last, m.start));
    tokens.add(m.group(0)!);
    wordSet.add(tokens.length - 1);
    last = m.end;
  }
  if (last < vi.length) tokens.add(vi.substring(last));

  final lexicon = kChuNomLexicon.entries
      .map((e) => (key: e.key.toLowerCase(), value: e.value))
      .toList()
    ..sort((a, b) => b.key.length.compareTo(a.key.length));
  final maxWords = 6;

  final out = <String>[];
  var i = 0;
  while (i < tokens.length) {
    if (!wordSet.contains(i)) {
      out.add(tokens[i]);
      i++;
      continue;
    }
    var matched = false;
    for (var w = maxWords; w >= 1; w--) {
      if (i + w > tokens.length) continue;
      var ok = true;
      final phrase = <String>[];
      for (var k = 0; k < w; k++) {
        if (!wordSet.contains(i + k)) {
          ok = false;
          break;
        }
        phrase.add(tokens[i + k].toLowerCase());
      }
      if (!ok) continue;
      final key = phrase.join(' ');
      for (final e in lexicon) {
        if (e.key == key) {
          out.add(e.value);
          i += w;
          matched = true;
          break;
        }
      }
      if (matched) break;
    }
    if (!matched) {
      out.add(tokens[i]);
      i++;
    }
  }
  return out.join();
}

// ---------------------------------------------------------------------
// strings.dart parsing
// ---------------------------------------------------------------------

class _StrArg {
  final int start; // content offset (after opening quote)
  final int end; // content offset (at closing quote)
  final String content;
  const _StrArg(this.start, this.end, this.content);
}

class TrCall {
  final int hnStart;
  final int hnEnd;
  final String en;
  final String hn;
  const TrCall(this.hnStart, this.hnEnd, this.en, this.hn);
}

List<TrCall> parseTrCalls(String src) {
  final calls = <TrCall>[];
  final n = src.length;
  var i = 0;
  while (i < n) {
    final idx = src.indexOf('tr(', i);
    if (idx < 0) break;
    var p = idx + 3;
    final args = <_StrArg>[];
    var ok = true;
    for (var a = 0; a < 5; a++) {
      while (p < n &&
          (src[p] == ' ' ||
              src[p] == '\n' ||
              src[p] == '\r' ||
              src[p] == '\t' ||
              src[p] == ',')) {
        p++;
      }
      if (p >= n || src[p] != '\'') {
        ok = false;
        break;
      }
      p++;
      final contentStart = p;
      final buf = StringBuffer();
      while (p < n) {
        final c = src[p];
        if (c == '\\' && p + 1 < n) {
          final e = src[p + 1];
          if (e == '\'' || e == '\\' || e == 'n' || e == 't') {
            buf.write(c);
            buf.write(e);
            p += 2;
            continue;
          }
        }
        if (c == '\'') break;
        buf.write(c);
        p++;
      }
      if (p >= n || src[p] != '\'') {
        ok = false;
        break;
      }
      args.add(_StrArg(contentStart, p, buf.toString()));
      p++;
    }
    if (ok && args.length == 5) {
      calls.add(TrCall(args[4].start, args[4].end, args[0].content, args[4].content));
      i = args[4].end + 1;
    } else {
      i = idx + 3;
    }
  }
  return calls;
}

// ---------------------------------------------------------------------
// main
// ---------------------------------------------------------------------

Future<void> main(List<String> args) async {
  dryRun = args.contains('--dry-run');
  if (args.contains('--policies')) {
    await _runPolicies();
    return;
  }
  var limit = 1 << 30;
  final li = args.indexWhere((a) => a.startsWith('--limit'));
  if (li >= 0) limit = int.parse(args[li].split('=')[1]);
  // v2.3.0: default is fill-empty - only tr() calls whose Han-Nom slot is
  // still '' are translated, so re-runs never disturb existing strings.
  // Pass --all to re-translate every tr() call from scratch.
  final fillEmptyOnly = !args.contains('--all');
  final stringsPath = 'lib/i18n/strings.dart';
  final src = File(stringsPath).readAsStringSync();
  final calls = parseTrCalls(src);
  stdout.writeln('Found ${calls.length} tr() calls');

  // build the output by splicing new hn contents. Iterate from the END
  // of the file backwards: hnStart/hnEnd are offsets into `src`, and
  // replacing later text first keeps every earlier offset valid.
  var out = src;
  var done = 0;
  var failed = 0;
  var skipped = 0;
  for (final c in calls.reversed) {
    if (fillEmptyOnly && c.hn.isNotEmpty) {
      skipped++;
      continue;
    }
    final protected = protect(c.en);
    // rebuild interpolation order map
    _order = {};
    var idx = 0;
    protected.replaceAllMapped(_interpRe, (m) {
      _order['${idx++}'] = m.group(1)!;
      return m.group(0)!;
    });
    final vi = await translate(protected, 'vi');
    if (vi.isEmpty) {
      failed++;
      stdout.writeln('  ! FAILED: ${c.en.substring(0, min(50, c.en.length))}');
      continue;
    }
    final hn = transcribe(vi);
    final restored = decodeEntities(restore(hn));
    final escaped = restored
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'");
    if (!dryRun) {
      out = out.replaceRange(c.hnStart, c.hnEnd, escaped);
    }
    done++;
    stdout.writeln('  [${done.toString().padLeft(3)}] $vi');
    stdout.writeln('       -> $hn');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (done >= limit) break;
  }

  stdout.writeln('\nTranslated $done / ${calls.length} (${failed} failed, $skipped skipped)');
  if (!dryRun && failed == 0) {
    final bak = '/data/user/work/strings.dart.bak.2.2.5';
    File(bak).writeAsStringSync(src);
    File(stringsPath).writeAsStringSync(out);
    stdout.writeln('Backup:  $bak');
    stdout.writeln('Rewrote: $stringsPath');
  } else if (dryRun) {
    stdout.writeln('Dry run - no files changed');
  } else {
    stdout.writeln('NOT written because $failed strings failed.');
  }
}

int min(int a, int b) => a < b ? a : b;

// ---------------------------------------------------------------------
// Policies & Terms - build the fr / de / hn variants (zh/en kept)
// ---------------------------------------------------------------------

class _Section {
  String heading;
  List<String> paragraphs;
  _Section(this.heading, this.paragraphs);
}

List<_Section> _extractSections(String src, String fnName) {
  // anchor on the definition (with return type), not the first call site
  final fnStart = src.indexOf('List<_Section> $fnName');
  if (fnStart < 0) return const [];
  final bodyStart = src.indexOf('{', fnStart);
  final r1 = src.indexOf('return [', bodyStart);
  final r2 = src.indexOf('return [', r1 + 8);
  final n = src.length;
  var p = r2 + 8;
  final sections = <_Section>[];
  while (p < n) {
    final sIdx = src.indexOf('_Section(', p);
    if (sIdx < 0) break;
    // heading string
    var q = src.indexOf('\'', sIdx);
    if (q < 0) break;
    q++;
    final heading = _readString(src, q);
    // paragraphs list
    final lb = src.indexOf('[', q + heading.length + 2);
    var k = lb + 1;
    final paras = <String>[];
    while (k < n) {
      while (k < n && (src[k] == ' ' || src[k] == '\n' || src[k] == '\r' || src[k] == '\t' || src[k] == ',')) {
        k++;
      }
      if (k < n && src[k] == '\'') {
        k++;
        paras.add(_readString(src, k));
      } else if (k < n && src[k] == ']') {
        break;
      } else {
        break;
      }
    }
    sections.add(_Section(heading, paras));
    p = k + 1;
  }
  return sections;
}

String _readString(String src, int afterQuote) {
  final buf = StringBuffer();
  var p = afterQuote;
  while (p < src.length) {
    final c = src[p];
    if (c == '\\' && p + 1 < src.length) {
      final e = src[p + 1];
      if (e == '\'' || e == '\\' || e == 'n' || e == 't') {
        buf.write(c);
        buf.write(e);
        p += 2;
        continue;
      }
    }
    if (c == '\'') break;
    buf.write(c);
    p++;
  }
  return buf.toString();
}

String _esc(String s) => s.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

String _emitList(List<_Section> list, String indent) {
  final buf = StringBuffer('[\n');
  for (final s in list) {
    buf.writeln("${indent}_Section('${_esc(s.heading)}', [");
    for (final para in s.paragraphs) {
      buf.writeln("$indent  '${_esc(para)}',");
    }
    buf.writeln('$indent]),');
  }
  buf.write('$indent]');
  return buf.toString();
}

String _emitFunction(String fnName, List<_Section> en, List<_Section> zh,
    List<_Section> fr, List<_Section> de, List<_Section> hn) {
  final buf = StringBuffer('List<_Section> $fnName(AppStrings s) {\n');
  buf.writeln('  switch (s.lang) {');
  buf.writeln('    case AppLanguage.english:');
  buf.writeln('      return ${_emitList(en, '        ')};');
  buf.writeln('    case AppLanguage.french:');
  buf.writeln('      return ${_emitList(fr, '        ')};');
  buf.writeln('    case AppLanguage.german:');
  buf.writeln('      return ${_emitList(de, '        ')};');
  buf.writeln('    case AppLanguage.hannom:');
  buf.writeln('      return ${_emitList(hn, '        ')};');
  buf.writeln('    default:');
  buf.writeln('      return ${_emitList(zh, '        ')};');
  buf.writeln('  }');
  buf.writeln('}');
  return buf.toString();
}

(Range, Range) _fnRange(String src, String fnName) {
  final start = src.indexOf('List<_Section> $fnName');
  if (start < 0) return (const Range(0, 0), const Range(0, 0));
  final bodyStart = src.indexOf('{', start);
  var depth = 0;
  var end = bodyStart;
  for (var i = bodyStart; i < src.length; i++) {
    if (src[i] == '{') {
      depth++;
    } else if (src[i] == '}') {
      depth--;
      if (depth == 0) {
        end = i + 1;
        break;
      }
    }
  }
  return (Range(start, end), Range(start, end));
}

Future<void> _translateSectionList(List<_Section> list, String target) async {
  for (final s in list) {
    s.heading = await _t(s.heading, target);
    for (var i = 0; i < s.paragraphs.length; i++) {
      s.paragraphs[i] = await _t(s.paragraphs[i], target);
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
}

Future<String> _t(String en, String target) async {
  if (target == 'hn') {
    final vi = await translate(en, 'vi');
    return vi.isEmpty ? en : decodeEntities(transcribe(vi));
  }
  final out = await translate(en, target);
  return out.isEmpty ? en : decodeEntities(out);
}

Future<void> _runPolicies() async {
  final path = 'lib/screens/policy_screen.dart';
  final src = File(path).readAsStringSync();
  final bak = '/data/user/work/policy_screen.dart.bak.2.2.5';
  File(bak).writeAsStringSync(src);

  final enPrivacy = _extractSections(src, '_privacySections');
  final enTerms = _extractSections(src, '_termsSections');
  final zhPrivacy = _extractSections(src, '_privacySections'); // replaced below
  stdout.writeln(
      'Policies: ${enPrivacy.length} privacy / ${enTerms.length} terms sections');

  // translate copies for fr / de / hn
  final frPrivacy = _copyOf(enPrivacy);
  final dePrivacy = _copyOf(enPrivacy);
  final hnPrivacy = _copyOf(enPrivacy);
  final frTerms = _copyOf(enTerms);
  final deTerms = _copyOf(enTerms);
  final hnTerms = _copyOf(enTerms);

  await _translateSectionList(frPrivacy, 'fr');
  stdout.writeln('  fr privacy done');
  await _translateSectionList(dePrivacy, 'de');
  stdout.writeln('  de privacy done');
  await _translateSectionList(hnPrivacy, 'hn');
  stdout.writeln('  hn privacy done');
  await _translateSectionList(frTerms, 'fr');
  stdout.writeln('  fr terms done');
  await _translateSectionList(deTerms, 'de');
  stdout.writeln('  de terms done');
  await _translateSectionList(hnTerms, 'hn');
  stdout.writeln('  hn terms done');

  final zhP = _extractZh(src, '_privacySections');
  final zhT = _extractZh(src, '_termsSections');

  final newPrivacy = _emitFunction('_privacySections', enPrivacy, zhP, frPrivacy, dePrivacy, hnPrivacy);
  final newTerms = _emitFunction('_termsSections', enTerms, zhT, frTerms, deTerms, hnTerms);

  var out = src;
  final rp = _fnRange(src, '_privacySections');
  final rt = _fnRange(src, '_termsSections');
  // Replace the LATER function (terms) first: both ranges are offsets
  // into `src`, so touching terms first keeps the privacy offsets valid.
  out = out.replaceRange(rt.$1.start, rt.$2.end, newTerms);
  out = out.replaceRange(rp.$1.start, rp.$2.end, newPrivacy);

  if (!dryRun) {
    File(path).writeAsStringSync(out);
    stdout.writeln('Rewrote $path (backup: $bak)');
  } else {
    stdout.writeln('Dry run - not written');
  }
}

List<_Section> _copyOf(List<_Section> list) =>
    list.map((s) => _Section(s.heading, List.of(s.paragraphs))).toList();

/// extract the Chinese branch (the `if (!en) { return [...] }` block)
List<_Section> _extractZh(String src, String fnName) {
  final fnStart = src.indexOf('List<_Section> $fnName');
  if (fnStart < 0) return const [];
  final bodyStart = src.indexOf('{', fnStart);
  final r1 = src.indexOf('return [', bodyStart);
  final endBlock = src.indexOf('];', r1);
  final zhSrc = src.substring(r1 + 8, endBlock);
  // parse sections from this fragment
  final sections = <_Section>[];
  var p = 0;
  while (p < zhSrc.length) {
    final sIdx = zhSrc.indexOf('_Section(', p);
    if (sIdx < 0) break;
    var q = zhSrc.indexOf('\'', sIdx);
    if (q < 0) break;
    q++;
    final heading = _readString(zhSrc, q);
    final lb = zhSrc.indexOf('[', q + heading.length + 2);
    var k = lb + 1;
    final paras = <String>[];
    while (k < zhSrc.length) {
      while (k < zhSrc.length && ' \n\r\t,'.contains(zhSrc[k])) k++;
      if (zhSrc[k] == '\'') {
        k++;
        paras.add(_readString(zhSrc, k));
      } else if (zhSrc[k] == ']') {
        break;
      } else {
        break;
      }
    }
    sections.add(_Section(heading, paras));
    p = k + 1;
  }
  return sections;
}

class Range {
  final int start;
  final int end;
  const Range(this.start, this.end);
}
