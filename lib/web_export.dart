import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'pokepc_local_repository.dart';
import 'profiles.dart';
import 'progress.dart';
import 'settings.dart';
import 'widgets.dart';

/// URL pública (repositorio de sprites de PokéAPI) del sprite de una entrada.
/// Devuelve null si no se conoce (la página muestra solo el texto).
String? _publicSpriteUrl(String? path) {
  if (path == null) return null;
  final legacy = path.startsWith('pokepc') ? AnimatedSprites.legacyPath(path) : path;
  if (legacy == null) return null;
  final m = RegExp(r'^(shiny_)?(female_)?(\d+)\.png$').firstMatch(legacy.split('/').last);
  if (m == null) return null;
  return 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/'
      '${m.group(1) != null ? 'shiny/' : ''}${m.group(2) != null ? 'female/' : ''}${m.group(3)}.png';
}

/// Datos de una Pokédex en el formato compacto que lee la página.
Map<String, dynamic> _gameData(Game g, Progress p, bool spanish) {
  final all = g.allEntries;
  final shinyTotal = g.shinyTotal(all);
  final sections = <Map<String, dynamic>>[];
  Map<String, dynamic>? current;
  String? currentTitle;
  for (final gs in g.species) {
    final title = gs.section ?? '';
    if (current == null || title != currentTitle) {
      current = {'t': title, 'sp': <Map<String, dynamic>>[]};
      currentTitle = title;
      sections.add(current);
    }
    final entries = <Map<String, dynamic>>[];
    for (final e in gs.entries) {
      final key = g.key(e);
      entries.add({
        'l': e.label,
        'i': _publicSpriteUrl(e.sprite) ?? '',
        'h': g.shinyFor(e) ? (_publicSpriteUrl(e.shiny) ?? '') : '',
        'c': p.has(key) ? 1 : 0,
        's': g.shinyFor(e) ? (p.has(key, shiny: true) ? 1 : 0) : -1,
      });
    }
    (current['sp'] as List).add({
      'n': gs.no,
      'nm': gs.displayName(spanish),
      'e': entries,
    });
  }
  return {
    'id': g.id,
    'name': g.name,
    'total': all.length,
    'caught': p.count(g, all),
    'shinyTotal': shinyTotal,
    'shinyCaught': shinyTotal > 0 ? p.count(g, all, shiny: true) : 0,
    'sections': sections,
  };
}

/// Genera la página web de seguimiento y devuelve el archivo creado.
Future<File> writeTrackingPage({
  required List<Game> games,
  required Progress progress,
  required String profileName,
  required bool spanish,
}) async {
  final data = {
    'profile': profileName,
    'generated': DateTime.now().toIso8601String(),
    'games': [for (final g in games) _gameData(g, progress, spanish)],
  };
  // Evita cerrar el <script> por accidente.
  final json = jsonEncode(data).replaceAll('<', '\\u003c').replaceAll('\u2028', '\\u2028').replaceAll('\u2029', '\\u2029');
  final title = 'Seguimiento Pokédex · $profileName';
  final html = _template
      .replaceFirst('__TITLE__', const HtmlEscape().convert(title))
      .replaceFirst('__DATA__', json);

  final dir = Directory('${PokepcLocalRepository.root.parent.path}${Platform.pathSeparator}exports');
  await dir.create(recursive: true);
  final safe = profileName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  final file = File('${dir.path}${Platform.pathSeparator}seguimiento-${safe.isEmpty ? 'perfil' : safe}.html');
  await file.writeAsString(html, flush: true);
  return file;
}

/// Ajustes → «Exportar seguimiento (página web)».
Future<void> exportTrackingPage(
  BuildContext context, {
  required List<Game> games,
  required Progress progress,
  required ProfileStore profiles,
  required AppSettings settings,
}) async {
  final chosen = await showDialog<List<Game>>(
    context: context,
    builder: (_) => _ExportDialog(games: games, progress: progress),
  );
  if (chosen == null || chosen.isEmpty || !context.mounted) return;
  try {
    final file = await writeTrackingPage(
      games: chosen,
      progress: progress,
      profileName: profiles.active.name,
      spanish: settings.spanish,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _ResultDialog(file: file, count: chosen.length),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se ha podido crear la página: $e')));
    }
  }
}

class _ExportDialog extends StatefulWidget {
  final List<Game> games;
  final Progress progress;
  const _ExportDialog({required this.games, required this.progress});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  late final Map<String, int> _caught = {
    for (final g in widget.games) g.id: widget.progress.count(g, g.allEntries),
  };
  late final Set<String> _selected = {
    for (final g in widget.games)
      if ((_caught[g.id] ?? 0) > 0) g.id,
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AlertDialog(
      title: const Text('Exportar seguimiento'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Elige las Pokédex que aparecerán en la página. Por defecto, las que ya tienen algún Pokémon marcado.',
                style: t.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              TextButton(
                  onPressed: () => setState(() => _selected
                    ..clear()
                    ..addAll(widget.games.map((g) => g.id))),
                  child: const Text('Todas')),
              TextButton(
                  onPressed: () => setState(() => _selected
                    ..clear()
                    ..addAll([
                      for (final g in widget.games)
                        if ((_caught[g.id] ?? 0) > 0) g.id
                    ])),
                  child: const Text('Con progreso')),
              TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('Ninguna')),
            ]),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final g in widget.games)
                    CheckboxListTile(
                      dense: true,
                      value: _selected.contains(g.id),
                      title: Text(g.name),
                      subtitle: Text('${_caught[g.id]} / ${g.allEntries.length}'),
                      onChanged: (v) => setState(() {
                        if (v == true) {
                          _selected.add(g.id);
                        } else {
                          _selected.remove(g.id);
                        }
                      }),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar')),
        FilledButton(
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context,
                  [for (final g in widget.games) if (_selected.contains(g.id)) g]),
          child: const Text('Generar página'),
        ),
      ],
    );
  }
}

class _ResultDialog extends StatelessWidget {
  final File file;
  final int count;
  const _ResultDialog({required this.file, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return AlertDialog(
      title: const Text('Página generada'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se ha creado la página con $count Pokédex en:'),
            const SizedBox(height: 6),
            SelectableText(file.path, style: t.textTheme.bodySmall),
            const SizedBox(height: 14),
            Text('Cómo conseguir un enlace', style: t.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Sube ese archivo a un alojamiento web estático gratuito (por ejemplo '
              'Netlify Drop, GitHub Pages o Cloudflare Pages) y te darán una dirección '
              'que puedes compartir. Para actualizarla, vuelve a generar la página y '
              'súbela de nuevo.\n\n'
              'Ojo: cualquiera que tenga el enlace verá tu progreso.',
              style: t.textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: file.path));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ruta copiada')));
            }
          },
          child: const Text('Copiar ruta'),
        ),
        TextButton(
          onPressed: () => launchUrl(Uri.file(file.parent.path)),
          child: const Text('Abrir carpeta'),
        ),
        FilledButton(
          onPressed: () => launchUrl(Uri.file(file.path)),
          child: const Text('Abrir en el navegador'),
        ),
      ],
    );
  }
}

const _template = r'''<!doctype html>
<html lang="es">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>__TITLE__</title>
<style>
:root{color-scheme:light dark;--bg:#f4f6fb;--card:#fff;--text:#1b2230;--muted:#667085;--line:#dfe4ee;--accent:#e53935;--ok:#2e9e5b;--bar:#e6e9f2}
@media (prefers-color-scheme:dark){:root{--bg:#10141d;--card:#1a2030;--text:#eef1f8;--muted:#9aa4b8;--line:#2a3247;--bar:#2a3247}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}
header{padding:22px 16px 10px;max-width:1200px;margin:0 auto}
h1{margin:0;font-size:24px}
.sub{color:var(--muted);font-size:13px;margin-top:2px}
main{max-width:1200px;margin:0 auto;padding:8px 16px 40px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(260px,1fr));gap:12px}
.card{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:14px}
.game{cursor:pointer;text-align:left;color:inherit;font:inherit}
.game:hover{border-color:var(--accent)}
.game b{display:block;margin-bottom:6px}
.bar{height:8px;border-radius:6px;background:var(--bar);overflow:hidden;margin:6px 0}
.bar>i{display:block;height:100%;background:var(--accent)}
.bar.sh>i{background:#f0b429}
.small{font-size:12px;color:var(--muted)}
.tools{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:12px 0}
input,select,button.back{font:inherit;padding:8px 10px;border-radius:10px;border:1px solid var(--line);background:var(--card);color:var(--text)}
input{flex:1;min-width:180px}
h2{font-size:17px;margin:22px 0 8px}
.mons{display:grid;grid-template-columns:repeat(auto-fill,minmax(150px,1fr));gap:10px}
.mon{background:var(--card);border:1px solid var(--line);border-radius:12px;padding:8px;text-align:center}
.mon.done{border-color:var(--ok)}
.mon img{width:84px;height:84px;object-fit:contain;image-rendering:auto}
.mon.none img{opacity:.35;filter:grayscale(1)}
.nm{font-weight:600;font-size:13px}
.no{color:var(--muted);font-size:11px}
.pills{display:flex;flex-wrap:wrap;gap:4px;justify-content:center;margin-top:6px}
.pill{font-size:11px;border-radius:999px;padding:1px 7px;border:1px solid var(--line);color:var(--muted)}
.pill.on{background:var(--ok);border-color:var(--ok);color:#fff}
.pill.sh.on{background:#f0b429;border-color:#f0b429;color:#1b2230}
footer{max-width:1200px;margin:0 auto;padding:0 16px 30px;color:var(--muted);font-size:12px}
</style>
</head>
<body>
<header><h1 id="title"></h1><div class="sub" id="sub"></div></header>
<main id="app"></main>
<footer id="foot"></footer>
<script id="data" type="application/json">__DATA__</script>
<script>
const D=JSON.parse(document.getElementById('data').textContent);
const $=(s,r=document)=>r.querySelector(s);
const el=(t,c,h)=>{const e=document.createElement(t);if(c)e.className=c;if(h!==undefined)e.innerHTML=h;return e};
const esc=s=>String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const pct=(a,b)=>b?Math.round(a*100/b):0;
$('#title').textContent='Seguimiento Pokédex · '+D.profile;
$('#sub').textContent='Actualizado el '+new Date(D.generated).toLocaleString('es-ES');
$('#foot').textContent='Generado con PokeTracker.';
const app=$('#app');
let filter='all',query='';
function overview(){
  document.title=D.profile+' · Pokédex';
  app.innerHTML='';
  const tot=D.games.reduce((a,g)=>a+g.total,0),got=D.games.reduce((a,g)=>a+g.caught,0);
  app.appendChild(el('div','small','Total registrado: <b>'+got+'</b> de '+tot+' entradas en '+D.games.length+' Pokédex'));
  const grid=el('div','grid');grid.style.marginTop='10px';
  D.games.forEach(g=>{
    const c=el('button','card game');
    let h='<b>'+esc(g.name)+'</b><div class="bar"><i style="width:'+pct(g.caught,g.total)+'%"></i></div><div class="small">'+g.caught+' / '+g.total+' · '+pct(g.caught,g.total)+' %</div>';
    if(g.shinyTotal){h+='<div class="bar sh"><i style="width:'+pct(g.shinyCaught,g.shinyTotal)+'%"></i></div><div class="small">✨ '+g.shinyCaught+' / '+g.shinyTotal+'</div>';}
    c.innerHTML=h;c.onclick=()=>{location.hash=g.id};grid.appendChild(c);
  });
  app.appendChild(grid);
}
function monCard(sp){
  const es=sp.e;
  const allN=es.every(e=>e.c),anyN=es.some(e=>e.c||e.s===1);
  const allS=es.every(e=>e.s!==0);
  const done=allN&&allS;
  const first=es.find(e=>e.c)||es[0];
  const c=el('div','mon'+(done?' done':'')+(anyN?'':' none'));
  const img=first.i?'<img loading="lazy" decoding="async" alt="" src="'+esc(first.i)+'" onerror="this.style.display=\'none\'">':'<div style="height:84px"></div>';
  let h=img+'<div class="no">#'+String(sp.n).padStart(3,'0')+'</div><div class="nm">'+esc(sp.nm)+'</div><div class="pills">';
  es.forEach(e=>{
    const lab=(es.length>1)?esc(e.l)+' ':'';
    h+='<span class="pill'+(e.c?' on':'')+'">'+lab+(e.c?'✓':'—')+'</span>';
    if(e.s>=0)h+='<span class="pill sh'+(e.s?' on':'')+'">✨'+(es.length>1?' '+esc(e.l):'')+'</span>';
  });
  c.innerHTML=h+'</div>';return c;
}
function matches(sp){
  if(query&&!(sp.nm.toLowerCase().includes(query)||String(sp.n)===query))return false;
  const es=sp.e,allN=es.every(e=>e.c),allS=es.every(e=>e.s!==0);
  if(filter==='caught')return allN;
  if(filter==='missing')return !allN||!allS;
  if(filter==='complete')return allN&&allS;
  return true;
}
function detail(g){
  document.title=g.name+' · '+D.profile;
  app.innerHTML='';
  const tools=el('div','tools');
  const back=el('button','back','← Todas las Pokédex');back.onclick=()=>{location.hash=''};
  const q=el('input');q.placeholder='Buscar por nombre o número';q.value=query;
  const f=el('select','',
    '<option value="all">Todos</option><option value="caught">Capturados</option><option value="missing">Me faltan</option><option value="complete">Completos</option>');
  f.value=filter;
  tools.append(back,q,f);app.appendChild(tools);
  const head=el('div','card');
  let hh='<b>'+esc(g.name)+'</b><div class="bar"><i style="width:'+pct(g.caught,g.total)+'%"></i></div><div class="small">'+g.caught+' / '+g.total+' · '+pct(g.caught,g.total)+' %</div>';
  if(g.shinyTotal)hh+='<div class="bar sh"><i style="width:'+pct(g.shinyCaught,g.shinyTotal)+'%"></i></div><div class="small">✨ '+g.shinyCaught+' / '+g.shinyTotal+'</div>';
  head.innerHTML=hh;app.appendChild(head);
  const body=el('div');app.appendChild(body);
  const render=()=>{
    body.innerHTML='';
    g.sections.forEach(s=>{
      const list=s.sp.filter(matches);if(!list.length)return;
      if(s.t)body.appendChild(el('h2','',esc(s.t)+' <span class="small">('+list.length+')</span>'));
      const grid=el('div','mons');list.forEach(sp=>grid.appendChild(monCard(sp)));body.appendChild(grid);
    });
    if(!body.children.length)body.appendChild(el('p','small','No hay Pokémon que coincidan.'));
  };
  q.oninput=()=>{query=q.value.trim().toLowerCase();render()};
  f.onchange=()=>{filter=f.value;render()};
  render();window.scrollTo(0,0);
}
function route(){
  const id=decodeURIComponent(location.hash.slice(1));
  const g=D.games.find(x=>x.id===id);
  if(g)detail(g);else overview();
}
addEventListener('hashchange',route);route();
</script>
</body>
</html>
''';
