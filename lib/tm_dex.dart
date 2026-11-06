import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'settings.dart';
import 'text_editor.dart';

/// Catálogo de máquinas por grupo de juegos. Se alimenta de PokéAPI:
/// los objetos máquina contienen sus correspondencias concretas por versión.
class TmDexScreen extends StatefulWidget {
  final bool spanish;
  final AppSettings settings;
  const TmDexScreen({super.key, required this.spanish, required this.settings});
  @override
  State<TmDexScreen> createState() => _TmDexScreenState();
}

class _GameSet {
  final String label;
  final List<String> groups;
  const _GameSet(this.label, this.groups);
}

const _gameSets = <_GameSet>[
  _GameSet('Rojo / Azul / Amarillo', ['red-blue', 'yellow']),
  _GameSet('Oro / Plata / Cristal', ['gold-silver', 'crystal']),
  _GameSet('Rubí / Zafiro / Esmeralda', ['ruby-sapphire', 'emerald']),
  _GameSet('Rojo Fuego / Verde Hoja', ['firered-leafgreen']),
  _GameSet('Diamante / Perla / Platino', ['diamond-pearl', 'platinum']),
  _GameSet('Blanco / Negro / Blanco 2 / Negro 2', ['black-white', 'black-2-white-2']),
  _GameSet('X / Y', ['x-y']),
  _GameSet('Rubí Omega / Zafiro Alfa', ['omega-ruby-alpha-sapphire']),
  _GameSet('Sol / Luna / Ultrasol / Ultraluna', ['sun-moon', 'ultra-sun-ultra-moon']),
  _GameSet("Let's Go Pikachu / Let's Go Eevee", ['lets-go-pikachu-lets-go-eevee']),
  _GameSet('Espada / Escudo (incluidos los DLC)', ['sword-shield', 'isle-of-armor', 'crown-tundra']),
  _GameSet('Leyendas Pokémon: Arceus', ['legends-arceus']),
  _GameSet('Diamante Brillante / Perla Reluciente', ['brilliant-diamond-shining-pearl']),
  _GameSet('Escarlata / Púrpura (incluidos los DLC)', ['scarlet-violet', 'the-teal-mask', 'the-indigo-disk']),
  _GameSet('Leyendas Pokémon: Z-A (incluido el DLC)', ['legends-z-a', 'legends-z-a-mega-dimension']),
];

class _MachineRow {
  final String item, move, moveUrl;
  final int number;
  final String kind;
  final String group;
  final _MoveInfo? info;
  const _MachineRow(this.item, this.move, this.moveUrl, this.number, this.kind, this.group, {this.info});
}

class _MoveInfo {
  final String name, type, category, effect;
  final int? power, accuracy, pp;
  const _MoveInfo(this.name, this.type, this.category, this.effect, this.power, this.accuracy, this.pp);
}

class _TmDexScreenState extends State<TmDexScreen> {
  static final Map<String, Future<List<_MachineRow>>> _cache = {};
  int _selected = 0;
  String _filter = 'Todas';
  String _query = '';
  late Future<List<_MachineRow>> _future = _load(_gameSets[0]);

  Future<List<_MachineRow>> _load(_GameSet set) => _cache.putIfAbsent(
      set.groups.join(','), () async {
        // Leyendas Z-A tiene un catálogo propio (107 MT base + 53 del DLC),
        // no compatible con los IDs de máquina de PokéAPI.
        if (set.groups.contains('legends-z-a')) {
          try {
            final raw = await rootBundle.loadString('assets/data/za_machines.json');
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final entries = (data['machines'] as List? ?? const []).cast<Map<String, dynamic>>();
            return entries.map((e) {
              final info = _MoveInfo(
                e['nameEs']?.toString() ?? 'Movimiento no disponible',
                e['typeEs']?.toString() ?? '—', e['categoryEs']?.toString() ?? '—',
                e['effectEs']?.toString() ?? 'Consultar descripción en el juego',
                e['power'] as int?, e['accuracy'] as int?, e['pp'] as int?,
              );
              return _MachineRow('za-tm-${e['number']}', e['move']?.toString() ?? 'za-tm-${e['number']}', '',
                e['number'] as int, 'MT', 'legends-z-a', info: info);
            }).toList();
          } catch (_) {
            throw Exception('Faltan los datos locales de Z-A. Ejecuta dart run tool/download_za_machines.dart');
          }
        }
        // Si se ejecutó tool/download_machines.dart, prioriza el catálogo local.
        // Al estar incluido en assets/data/, funciona también en Windows sin red.
        try {
          final raw = await rootBundle.loadString('assets/data/machines.json');
          final data = jsonDecode(raw) as Map<String, dynamic>;
          final moves = (data['moves'] as Map? ?? const {}).cast<String, dynamic>();
          final entries = (data['machines'] as List? ?? const []).cast<Map<String, dynamic>>();
          final localRows = <_MachineRow>[];
          for (final entry in entries) {
            final group = entry['group'] as String;
            if (!set.groups.contains(group)) continue;
            final slug = entry['move'] as String;
            final infoData = moves[slug] as Map<String, dynamic>?;
            _MoveInfo? info;
            if (infoData != null) {
              info = _MoveInfo(
                (widget.spanish ? infoData['nameEs'] : infoData['nameEn'])?.toString() ?? _pretty(slug),
                (widget.spanish ? infoData['typeEs'] : infoData['typeEn'])?.toString() ?? '—',
                (widget.spanish ? infoData['categoryEs'] : infoData['categoryEn'])?.toString() ?? '—',
                infoData['effect']?.toString() ?? 'Descripción no disponible.',
                infoData['power'] as int?, infoData['accuracy'] as int?, infoData['pp'] as int?,
              );
            }
            localRows.add(_MachineRow(entry['item'] as String, slug,
              entry['moveUrl'] as String, entry['number'] as int,
              entry['kind'] as String, group, info: info));
          }
          localRows.sort((a,b) {
            final g=set.groups.indexOf(a.group).compareTo(set.groups.indexOf(b.group));
            if(g!=0)return g;
            final k=['MT','MO','DT'].indexOf(a.kind).compareTo(['MT','MO','DT'].indexOf(b.kind));
            return k!=0?k:a.number.compareTo(b.number);
          });
          return localRows;
        } catch (_) {
          // Compatibilidad con instalaciones antiguas: consulta online si aún
          // no se ha generado el archivo local.
          return _fetchMachines(set.groups);
        }
      });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('MT/MO/DT')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 8), child: DropdownButtonFormField<int>(
        value: _selected, isExpanded: true,
        decoration: const InputDecoration(labelText: 'Grupo de juegos', border: OutlineInputBorder()),
        items: [for (var i=0; i<_gameSets.length; i++) DropdownMenuItem(value:i, child: Text(_gameSets[i].label, overflow: TextOverflow.ellipsis))],
        onChanged: (v) { if (v == null) return; setState(() { _selected=v; _filter='Todas'; _query=''; _future=_load(_gameSets[v]); }); },
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:6), child: TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Buscar MT, MO, DT o movimiento', border: OutlineInputBorder(), isDense: true),
        onChanged: (v)=>setState(()=>_query=v),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal:16, vertical:4), child: SegmentedButton<String>(
        segments: const [ButtonSegment(value:'Todas',label:Text('Todas')), ButtonSegment(value:'MT',label:Text('MT')), ButtonSegment(value:'MO',label:Text('MO')), ButtonSegment(value:'DT',label:Text('DT'))],
        selected: {_filter}, onSelectionChanged:(v)=>setState(()=>_filter=v.first),
      )),
      Expanded(child: FutureBuilder<List<_MachineRow>>(future:_future, builder:(context,s) {
        if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
        if(s.hasError) return Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('No se han podido cargar las MT/MO/DT. Comprueba la conexión a Internet.'),TextButton.icon(onPressed:()=>setState(()=>_future=_load(_gameSets[_selected])),icon:const Icon(Icons.refresh),label:const Text('Reintentar'))])));
        final all=s.data??const <_MachineRow>[];
        final rows=all.where((r)=> (_filter=='Todas'||r.kind==_filter) && ('${r.kind}${r.number}'.toLowerCase().contains(_query.toLowerCase())||r.move.toLowerCase().contains(_query.toLowerCase()))).toList();
        if(rows.isEmpty) return Center(child:Text(all.isEmpty?'No constan máquinas para este grupo en la fuente de datos.':'No hay resultados para la búsqueda.'));
        return ListView.builder(itemCount:rows.length,itemBuilder:(context,i){final r=rows[i];return ListTile(
          leading: CircleAvatar(child:Text('${r.kind}\n${r.number}',textAlign:TextAlign.center,style:const TextStyle(fontSize:10))),
          title: Text(widget.spanish ? (r.info?.name ?? _spanishMoveFallback(r.move)) : (r.info?.name ?? _pretty(r.move))), subtitle: Text('${r.kind}${r.number}  ·  ${_pretty(r.group)}'), trailing:const Icon(Icons.chevron_right),
          onTap:()=>showModalBottomSheet(isScrollControlled:true,context:context,builder:(_)=>_MachineDetail(row:r,spanish:widget.spanish,settings:widget.settings)),
        );});
      })),
      Padding(padding:const EdgeInsets.all(10),child:Text('Incluye las máquinas registradas para cada grupo. MT/MO/DT y su numeración pueden cambiar entre generaciones; las máquinas repetidas se muestran por separado cuando su número o movimiento difiere.',style:Theme.of(context).textTheme.bodySmall,textAlign:TextAlign.center)),
    ]),
  );
}

class _MachineDetail extends StatefulWidget { final _MachineRow row; final bool spanish; final AppSettings settings; const _MachineDetail({required this.row,required this.spanish,required this.settings}); @override State<_MachineDetail> createState()=>_MachineDetailState(); }
class _MachineDetailState extends State<_MachineDetail> {
  late Future<_MoveInfo> _future=widget.row.info != null ? Future.value(widget.row.info!) : _fetchMoveInfo(widget.row.moveUrl,widget.spanish);
  @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:EdgeInsets.fromLTRB(20,20,20,MediaQuery.of(context).viewInsets.bottom+20),child:FutureBuilder<_MoveInfo>(future:_future,builder:(context,s){if(s.connectionState!=ConnectionState.done)return const SizedBox(height:180,child:Center(child:CircularProgressIndicator()));if(s.hasError)return const Text('No se han podido cargar los detalles del movimiento.');final m=s.data!;return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text('${widget.row.kind}${widget.row.number}',style:Theme.of(context).textTheme.titleLarge),Text(m.name,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[Chip(label:Text('Tipo: ${m.type}')),Chip(label:Text('Categoría: ${m.category}')),Chip(label:Text('Potencia: ${m.power??'—'}')),Chip(label:Text('Precisión: ${m.accuracy==null?'—':'${m.accuracy}%'}')),Chip(label:Text('PP: ${m.pp??'—'}'))]),const SizedBox(height:14),Text('Efecto',style:Theme.of(context).textTheme.titleMedium),Text(editableText(widget.settings, 'machine:${widget.row.group}:${widget.row.item}:effect', m.effect)),Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>editTextValue(context,widget.settings,'machine:${widget.row.group}:${widget.row.item}:effect',editableText(widget.settings,'machine:${widget.row.group}:${widget.row.item}:effect',m.effect),'efecto de ${widget.row.kind}${widget.row.number}'),icon:const Icon(Icons.edit,size:16),label:const Text('Editar texto'))),const SizedBox(height:8),Text('Grupo: ${_pretty(widget.row.group)}'),Text('Objeto en la fuente: ${widget.row.item}') ]));}))); }

Future<List<_MachineRow>> _fetchMachines(List<String> groups) async {
  final c=HttpClient()..connectionTimeout=const Duration(seconds:20);
  Future<Map<String,dynamic>> get(String url) async {final req=await c.getUrl(Uri.parse(url));final res=await req.close();if(res.statusCode!=200)throw HttpException('HTTP ${res.statusCode}');return jsonDecode(await res.transform(utf8.decoder).join()) as Map<String,dynamic>;}
  try {
    final category=await get('https://pokeapi.co/api/v2/item-category/machines/');
    final items=(category['items'] as List? ?? const []).cast<Map<String,dynamic>>();
    final rows=<String,_MachineRow>{};
    // Limita concurrencia para no saturar el servicio.
    for(var start=0;start<items.length;start+=8){
      final batch=items.skip(start).take(8);
      await Future.wait(batch.map((item) async {
        try {final data=await get(item['url'] as String);final slug=data['name'] as String;final match=RegExp(r'^(tm|hm|tr)(\d+)$').firstMatch(slug);if(match==null)return;
          final kind=switch(match.group(1)){ 'tm'=>'MT','hm'=>'MO',_=>'DT'};final number=int.parse(match.group(2)!);
          for(final machine in (data['machines'] as List? ?? const [])) {final md=machine as Map<String,dynamic>;final vg=(md['version_group'] as Map<String,dynamic>)['name'] as String;if(!groups.contains(vg))continue;final move=md['move'] as Map<String,dynamic>;final row=_MachineRow(slug,move['name'] as String,move['url'] as String,number,kind,vg);rows['$vg:$slug:${row.move}']=row;}
        } catch (_) {}
      }));
    }
    final result=rows.values.toList()..sort((a,b){final g=groups.indexOf(a.group).compareTo(groups.indexOf(b.group));if(g!=0)return g;final k=['MT','MO','DT'].indexOf(a.kind).compareTo(['MT','MO','DT'].indexOf(b.kind));if(k!=0)return k;return a.number.compareTo(b.number);});
    return result;
  } finally {c.close(force:true);}
}

Future<_MoveInfo> _fetchMoveInfo(String url,bool spanish) async {
  final c=HttpClient()..connectionTimeout=const Duration(seconds:15);try{final req=await c.getUrl(Uri.parse(url));final res=await req.close();if(res.statusCode!=200)throw HttpException('HTTP ${res.statusCode}');final d=jsonDecode(await res.transform(utf8.decoder).join()) as Map<String,dynamic>;
    final names=(d['names'] as List? ?? const []).cast<Map<String,dynamic>>();final name=names.where((n)=>(n['language'] as Map)['name']==(spanish?'es':'en')).map((n)=>n['name'] as String).firstOrNull??_pretty(d['name'] as String);
    final types=(d['type']['names'] as List? ?? const []).cast<Map<String,dynamic>>();final type=types.where((n)=>(n['language'] as Map)['name']==(spanish?'es':'en')).map((n)=>n['name'] as String).firstOrNull??_pretty(d['type']['name'] as String);
    final classes=(d['damage_class']['names'] as List? ?? const []).cast<Map<String,dynamic>>();final category=classes.where((n)=>(n['language'] as Map)['name']==(spanish?'es':'en')).map((n)=>n['name'] as String).firstOrNull??_pretty(d['damage_class']['name'] as String);
    final effects=(d['effect_entries'] as List? ?? const []).cast<Map<String,dynamic>>();final effect=effects.where((e)=>(e['language'] as Map)['name']==(spanish?'es':'en')).map((e)=>e['short_effect'] as String).firstOrNull??(spanish?'No hay descripción disponible en español para este movimiento.':'No effect description available.');
    return _MoveInfo(name,type,category,effect,d['power'] as int?,d['accuracy'] as int?,d['pp'] as int?);
  }finally{c.close(force:true);}}

String _pretty(String s)=>s.split('-').map((x)=>x.isEmpty?x:'${x[0].toUpperCase()}${x.substring(1)}').join(' ');

String _spanishMoveFallback(String slug) => const {
  'thunderbolt': 'Rayo', 'thunder-wave': 'Onda Trueno', 'ice-beam': 'Rayo Hielo',
  'flamethrower': 'Lanzallamas', 'surf': 'Surf', 'strength': ' fuerza',
  'earthquake': 'Terremoto', 'psychic': 'Psíquico', 'shadow-ball': 'Bola Sombra',
  'protect': 'Protección', 'return': 'Retroceso', 'toxic': 'Tóxico',
  'rock-slide': 'Avalancha', 'iron-tail': ' cola férrea', 'waterfall': 'Cascada',
  'energy-ball': 'Energibola', 'dragon-claw': 'Garra Dragón', 'u-turn': 'Ida y Vuelta',
  'dark-pulse': 'Pulso Umbrío', 'will-o-wisp': 'Fuego Fatuo', 'roost': 'Respiro',
  'focus-blast': ' onda certera', 'flash-cannon': 'Foco Resplandor',
}[slug] ?? _pretty(slug);
