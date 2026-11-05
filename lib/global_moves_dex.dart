import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'settings.dart';
import 'text_editor.dart';

/// Pokédex global de movimientos. Los datos detallados proceden de PokéAPI.
class MovesDexScreen extends StatefulWidget {
  final bool spanish;
  final AppSettings settings;
  const MovesDexScreen({super.key, required this.spanish, required this.settings});
  @override
  State<MovesDexScreen> createState() => _MovesDexScreenState();
}

class _MovesDexScreenState extends State<MovesDexScreen> {
  late Future<List<_MoveSummary>> _future = _load();
  String _query = '';
  String _type = 'Todos';
  Future<Map<String,dynamic>> _get(String url) async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 15);
    try { final r = await c.getUrl(Uri.parse(url)); final s = await r.close();
      if (s.statusCode != 200) throw HttpException('HTTP ${s.statusCode}');
      return jsonDecode(await s.transform(utf8.decoder).join()) as Map<String,dynamic>;
    } finally { c.close(force: true); }
  }
  Future<List<_MoveSummary>> _load() async {
    Map<String, dynamic> localized = {};
    if (widget.spanish) {
      try { localized = (jsonDecode(await rootBundle.loadString('assets/data/move_names_es.json')) as Map).cast<String, dynamic>(); } catch (_) {}
    }
    final raw = await _get('https://pokeapi.co/api/v2/move?limit=1000');
    return (raw['results'] as List).map((e) {
      final slug = e['name'] as String;
      return _MoveSummary((localized[slug] ?? _pretty(slug)).toString(), e['url'] as String);
    }).toList()..sort((a,b)=>a.name.compareTo(b.name));
  }
  String _pretty(String s) => s.split('-').map((x)=>x.isEmpty?x:'${x[0].toUpperCase()}${x.substring(1)}').join(' ');
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Movimientos')),
    body: FutureBuilder<List<_MoveSummary>>(future:_future,builder:(context,s){
      if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
      if(s.hasError) return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Text('No se pudieron cargar los movimientos.'),TextButton(onPressed:()=>setState(()=>_future=_load()),child:const Text('Reintentar'))]));
      final rows=s.data!; final filtered=rows.where((m)=>m.name.toLowerCase().contains(_query.toLowerCase())).toList();
      return Column(children:[Padding(padding:const EdgeInsets.all(12),child:TextField(decoration:const InputDecoration(prefixIcon:Icon(Icons.search),labelText:'Buscar movimiento',border:OutlineInputBorder()),onChanged:(v)=>setState(()=>_query=v))),
        Expanded(child:ListView.builder(itemCount:filtered.length,itemBuilder:(context,i)=>ListTile(title:Text(filtered[i].name),trailing:const Icon(Icons.chevron_right),onTap:()=>showModalBottomSheet(isScrollControlled:true,context:context,builder:(_)=>_MoveDetail(url:filtered[i].url,spanish:widget.spanish,settings:widget.settings))))),
      ]);
    }));
}
Future<Map<String, String>>? _pokemonNamesFuture;
Future<Map<String, String>> _loadPokemonNames() async {
  final raw = jsonDecode(await rootBundle.loadString('assets/data/pokedex.json')) as Map<String, dynamic>;
  final rows = (raw['species'] as List).cast<Map<String, dynamic>>();
  return {for (final row in rows) (row['name'] as String): (row['nameEs'] as String? ?? row['name'] as String)};
}

class _MoveSummary { final String name,url; _MoveSummary(this.name,this.url); }
class _MoveDetail extends StatefulWidget { final String url; final bool spanish; final AppSettings settings; const _MoveDetail({required this.url,required this.spanish,required this.settings}); @override State<_MoveDetail> createState()=>_MoveDetailState(); }
class _MoveDetailState extends State<_MoveDetail> {
 late Future<Map<String,dynamic>> future=_load();
 Future<Map<String,dynamic>> _load() async { final c=HttpClient()..connectionTimeout=const Duration(seconds:15); try {final r=await c.getUrl(Uri.parse(widget.url));final s=await r.close();if(s.statusCode!=200)throw Exception('HTTP ${s.statusCode}');final data=jsonDecode(await s.transform(utf8.decoder).join()) as Map<String,dynamic>;_pokemonNamesFuture ??= _loadPokemonNames();data['_localized_pokemon_names']=await _pokemonNamesFuture!;return data;}finally{c.close(force:true);} }
 String pretty(String s)=>s.split('-').map((x)=>x.isEmpty?x:'${x[0].toUpperCase()}${x.substring(1)}').join(' ');
 String localizedType(String s) => const {'normal':'Normal','fire':'Fuego','water':'Agua','electric':'Eléctrico','grass':'Planta','ice':'Hielo','fighting':'Lucha','poison':'Veneno','ground':'Tierra','flying':'Volador','psychic':'Psíquico','bug':'Bicho','rock':'Roca','ghost':'Fantasma','dragon':'Dragón','dark':'Siniestro','steel':'Acero','fairy':'Hada'}[s] ?? pretty(s);
 String localizedClass(String s) => const {'physical':'Físico','special':'Especial','status':'Estado'}[s] ?? pretty(s);
 String localizedGeneration(String s) { final m=RegExp(r'generation-([ivx]+)').firstMatch(s); return m==null?pretty(s):'Generación ${m.group(1)!.toUpperCase()}'; }
 @override Widget build(BuildContext context)=>SafeArea(child:Padding(padding:const EdgeInsets.all(18),child:FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,s){if(!s.hasData)return const Center(child:CircularProgressIndicator());final d=s.data!;final pp=d['pp'];final maxPp=pp==null?null:(pp as int)*8~/5;final learned=(d['learned_by_pokemon'] as List? ?? []);final past=d['past_values'] as List? ?? [];final names=(d['names'] as List? ?? []).cast<Map<String,dynamic>>();final lang=widget.spanish?'es':'en';final localized=names.where((n)=>(n['language'] as Map)['name']==lang).toList();final name=localized.isEmpty?pretty(d['name']):localized.first['name'];final typeNames=(d['type']['names'] as List? ?? []).cast<Map<String,dynamic>>();final typeEs=typeNames.where((n)=>(n['language'] as Map)['name']==lang).toList();final classNames=(d['damage_class']['names'] as List? ?? []).cast<Map<String,dynamic>>();final classEs=classNames.where((n)=>(n['language'] as Map)['name']==lang).toList();final typeName=typeEs.isNotEmpty?typeEs.first['name']:localizedType(d['type']['name']);final className=classEs.isNotEmpty?classEs.first['name']:localizedClass(d['damage_class']['name']);final flavor=(d['flavor_text_entries'] as List? ?? []).where((e)=>(e['language'] as Map?)?['name']==lang).toList();final effectEntries=(d['effect_entries'] as List? ?? []).where((e)=>(e['language'] as Map?)?['name']==lang).toList();final effect=widget.spanish?(flavor.isNotEmpty?flavor.last['flavor_text'].toString():'La fuente no ofrece una descripción en español para este movimiento.'):(effectEntries.isNotEmpty?effectEntries.first['effect'].toString():'No description available.');return SingleChildScrollView(child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[Text(name,style:Theme.of(context).textTheme.headlineSmall),const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[Chip(label:Text('Tipo: $typeName')),Chip(label:Text('Categoría: $className')),Chip(label:Text('Potencia: ${d['power']??'—'}')),Chip(label:Text('Precisión: ${d['accuracy']??'—'}')),Chip(label:Text('PP: ${pp??'—'} / ${maxPp??'—'} máx.')),Chip(label:Text('Prioridad: ${d['priority']}'))]),const SizedBox(height:12),Text('Efecto',style:Theme.of(context).textTheme.titleMedium),Text(editableText(widget.settings,'move:${d['name']}:effect',effect)),Align(alignment:Alignment.centerRight,child:TextButton.icon(onPressed:()=>editTextValue(context,widget.settings,'move:${d['name']}:effect',editableText(widget.settings,'move:${d['name']}:effect',effect),'efecto del movimiento'),icon:const Icon(Icons.edit,size:16),label:const Text('Editar texto'))),const SizedBox(height:12),Text('Cambios entre generaciones',style:Theme.of(context).textTheme.titleMedium),if(past.isEmpty)const Text('No constan cambios históricos en PokéAPI.') else ...past.map((p){final v=p as Map;final g=v['generation']?['name']??'Generación anterior';final ppast=v['power'];final ap=v['accuracy'];final ppp=v['pp'];return Text('${widget.spanish?localizedGeneration(g):pretty(g)}: potencia ${ppast??'—'}, precisión ${ap??'—'}, PP ${ppp??'—'}');}),const SizedBox(height:12),Text('Pokémon que lo aprenden (${learned.length})',style:Theme.of(context).textTheme.titleMedium),Text(learned.map((p)=>(d['_localized_pokemon_names'] as Map<String,String>)[p['name']] ?? pretty(p['name'])).join(', ')),const SizedBox(height:8),const Text('Nota: los PP máximos se calculan aplicando tres PP Máximos (×1,6). Los métodos y juegos concretos de aprendizaje se consultan en la ficha individual del Pokémon; la disponibilidad puede variar por versión.'),const SizedBox(height:12)]));}))); }
