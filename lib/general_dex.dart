import 'package:flutter/material.dart';

import 'details.dart';
import 'models.dart';
import 'move_dex.dart';
import 'settings.dart';
import 'widgets.dart';

/// Enciclopedia de consulta: no recibe ni modifica el progreso del tracker.
class GeneralDexScreen extends StatefulWidget {
  final List<Species> species;
  final Map<int, Species> byDex;
  final DexDetails? details;
  final AppSettings settings;
  const GeneralDexScreen({super.key, required this.species, required this.byDex,
    required this.details, required this.settings});

  @override
  State<GeneralDexScreen> createState() => _GeneralDexScreenState();
}

class _GeneralDexScreenState extends State<GeneralDexScreen> {
  final _search = TextEditingController();
  String _query = '';
  int? _generation;

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final spanish = widget.settings.spanish;
    final q = _query.trim().toLowerCase();
    final filtered = widget.species.where((s) {
      final name = s.displayName(spanish).toLowerCase();
      return (_generation == null || s.gen == _generation) &&
          (q.isEmpty || name.contains(q) || s.dex.toString() == q || '#${s.dex}'.contains(q));
    }).toList()..sort((a,b) => a.dex.compareTo(b.dex));
    return Scaffold(
      appBar: AppBar(title: const Text('Pokédex'), actions: [
        IconButton(tooltip: 'Comparar Pokémon', icon: const Icon(Icons.compare_arrows),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
            PokemonCompareScreen(species: widget.species, details: widget.details,
              settings: widget.settings)))),
        IconButton(tooltip: 'Limpiar búsqueda', onPressed: () {
          _search.clear(); setState(() => _query = '');
        }, icon: const Icon(Icons.clear)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8), child: Row(children: [
          Expanded(child: TextField(controller: _search, onChanged: (v)=>setState(()=>_query=v),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por nombre o número...', border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width:10),
          DropdownButton<int?>(value:_generation, hint:const Text('Generación'), items:[
            const DropdownMenuItem<int?>(value:null,child:Text('Todas')),
            for(var g=1;g<=9;g++) DropdownMenuItem<int?>(value:g,child:Text('Generación $g')),
          ], onChanged:(v)=>setState(()=>_generation=v)),
        ])),
        Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:4),
          child:Align(alignment:Alignment.centerLeft,child:Text('${filtered.length} Pokémon',
            style:Theme.of(context).textTheme.labelMedium))),
        Expanded(child: LayoutBuilder(builder:(context,c) {
          final columns=(c.maxWidth/150).floor().clamp(2,10).toInt();
          return GridView.builder(padding:const EdgeInsets.all(12),
            gridDelegate:SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:columns,
              crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:0.9),
            itemCount:filtered.length,itemBuilder:(context,i) {
              final sp=filtered[i];
              final entry=sp.entries.firstWhere((e)=>e.kind=='base'||e.id==sp.name,
                orElse:()=>sp.entries.first);
              return Card(clipBehavior:Clip.antiAlias, child:InkWell(
                onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GeneralPokemonDetail(
                  species:sp,byDex:widget.byDex,details:widget.details,settings:widget.settings))),
                child:Padding(padding:const EdgeInsets.all(8),child:Column(
                  mainAxisAlignment:MainAxisAlignment.center,children:[
                    Expanded(child:Sprite(entry.sprite,size:92,pixel:widget.settings.pixelSprites,
                      threeD:widget.settings.threeDSprites)),
                    Text('#${sp.dex.toString().padLeft(4,'0')}',style:Theme.of(context).textTheme.labelSmall),
                    Text(sp.displayName(spanish),maxLines:1,overflow:TextOverflow.ellipsis,
                      style:Theme.of(context).textTheme.titleSmall),
                  ]))));
            });
        })),
      ]),
    );
  }
}

class GeneralPokemonDetail extends StatefulWidget {
  final Species species;
  final Map<int, Species> byDex;
  final DexDetails? details;
  final AppSettings settings;
  const GeneralPokemonDetail({super.key,required this.species,required this.byDex,
    required this.details,required this.settings});
  @override
  State<GeneralPokemonDetail> createState()=>_GeneralPokemonDetailState();
}

class _GeneralPokemonDetailState extends State<GeneralPokemonDetail> {
  bool _shiny=false;
  @override
  Widget build(BuildContext context) {
    final species=widget.species, settings=widget.settings;
    final info=widget.details?.species(species.dex);
    final theme=Theme.of(context);
    final varieties=info?.varieties ?? const <VarietyInfo>[];
    final chain=widget.details?.chain(info?.chain);
    final edges=chain==null?<(int,String,int)>[]:evoEdges(chain);
    final base=species.entries.firstWhere((e)=>e.kind=='base'||e.id==species.name,
      orElse:()=>species.entries.first);
    final image=_shiny && base.shiny!=null ? base.shiny : base.sprite;
    return Scaffold(appBar:AppBar(title:Text('${species.displayName(settings.spanish)} · #${species.dex.toString().padLeft(4,'0')}')),
      body:ListView(padding:const EdgeInsets.all(20),children:[
        Center(child:InkWell(
          borderRadius:BorderRadius.circular(16),
          onTap:()=>showDialog(context:context,builder:(ctx)=>Dialog(
            child:InteractiveViewer(minScale:0.5,maxScale:5,child:Padding(
              padding:const EdgeInsets.all(20),child:Sprite(image,size:320,pixel:settings.pixelSprites,threeD:settings.threeDSprites))))),
          child:Stack(alignment:Alignment.topRight,children:[
            Sprite(image,size:180,pixel:settings.pixelSprites,threeD:settings.threeDSprites),
            const Icon(Icons.zoom_in, size:22),
          ]))),
        Center(child:Text(species.displayName(settings.spanish),style:theme.textTheme.headlineMedium)),
        Center(child:Text('N.º ${species.dex.toString().padLeft(4,'0')} · Generación ${species.gen}',
          style:theme.textTheme.labelLarge)),
        Center(child:Padding(padding:const EdgeInsets.only(top:8),child:ToggleButtons(
          isSelected:[!_shiny,_shiny], onPressed:(i)=>setState(()=>_shiny=i==1),
          borderRadius:BorderRadius.circular(20),constraints:const BoxConstraints(minHeight:38,minWidth:112),
          children:const [Padding(padding:EdgeInsets.symmetric(horizontal:12),child:Text('Normal')),
            Padding(padding:EdgeInsets.symmetric(horizontal:12),child:Text('✨ Variocolor'))]))),
        if(info!=null)...[
          if(info.genus.isNotEmpty) Center(child:Text(info.genus,style:theme.textTheme.titleMedium)),
          if(info.text.isNotEmpty)...[const SizedBox(height:12),Text(info.text,style:theme.textTheme.bodyLarge)],
          _heading(context,'Datos de especie'),
          _facts(context,[
            if(info.catchRate!=null)('Ratio de captura','${info.catchRate}'),
            if(info.growth.isNotEmpty)('Ritmo de crecimiento',info.growth),
            if(info.happy!=null)('Amistad base','${info.happy}'),
            if(info.hatch!=null)('Ciclos de eclosión','${info.hatch}'),
            if(info.egg.isNotEmpty)('Grupos huevo',info.egg.join(', ')),
            ('Género',info.female<0?'Sin género':'♂ ${_percent(100-info.female*12.5)}% · ♀ ${_percent(info.female*12.5)}%'),
          ]),
          _heading(context,'Evoluciones'),
          if(edges.isEmpty) const Text('No evoluciona o no hay datos de evolución.')
          else for(final (from,requirement,to) in edges) Padding(padding:const EdgeInsets.symmetric(vertical:5),
            child:Row(children:[Expanded(child:Text(_name(from))),const Icon(Icons.arrow_forward,size:18),
              Expanded(child:Text('${_name(to)}\n$requirement',textAlign:TextAlign.end))])),
          _heading(context,'Formas y características'),
          for(final v in varieties) _varietyCard(context,v),
          PokemonMovesSection(pokemon: species.name, spanish: settings.spanish),
        ] else ...[const SizedBox(height:20),const Text('No hay ficha detallada disponible para este Pokémon.')],
        if(species.entries.length>1)...[
          _heading(context,'Sprites y variantes disponibles'),
          Wrap(spacing:12,runSpacing:12,children:[
            for(final e in species.entries) SizedBox(width:100,child:Column(children:[
              Sprite(_shiny && e.shiny!=null?e.shiny:e.sprite,size:72,
                pixel:settings.pixelSprites,threeD:settings.threeDSprites),
              Text(e.label,textAlign:TextAlign.center,style:theme.textTheme.labelSmall),
              if(e.kind.isNotEmpty)Text(e.kind,textAlign:TextAlign.center,style:theme.textTheme.labelSmall),
            ])),
          ]),
        ],
      ]));
  }

  String _name(int dex)=>widget.byDex[dex]?.displayName(widget.settings.spanish)??'#$dex';
  String _percent(double v)=>v==v.roundToDouble()?v.toInt().toString():v.toStringAsFixed(1);
  Widget _heading(BuildContext c,String title)=>Padding(padding:const EdgeInsets.only(top:22,bottom:10),
    child:Text(title,style:Theme.of(c).textTheme.titleLarge));
  Widget _facts(BuildContext c,List<(String,String)> facts)=>Wrap(spacing:18,runSpacing:12,
    children:[for(final (label,value) in facts)SizedBox(width:190,child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(label,style:Theme.of(c).textTheme.labelSmall),Text(value,style:Theme.of(c).textTheme.bodyMedium)]))]);
  Widget _varietyCard(BuildContext context,VarietyInfo v) {
    final theme=Theme.of(context); final total=v.stats.fold<int>(0,(a,b)=>a+b);
    return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(
      crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(v.name,style:theme.textTheme.titleMedium),
        if(v.types.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(vertical:6),
          child:Wrap(spacing:6,children:[for(final t in v.types)Chip(label:Text(_typeName(t)))])),
        Text('Altura: ${_measure(v.height/10)} m  ·  Peso: ${_measure(v.weight/10)} kg  ·  Exp. base: ${v.exp}'),
        const SizedBox(height:10),
        for(var i=0;i<v.stats.length&&i<6;i++)_StatRow(label:const ['PS','Ataque','Defensa','At. Esp.','Def. Esp.','Velocidad'][i],value:v.stats[i]),
        Padding(padding:const EdgeInsets.only(top:5),child:Text('Total: $total',style:theme.textTheme.labelLarge)),
        if(v.abilities.isNotEmpty)...[const SizedBox(height:10),Text('Habilidades',style:theme.textTheme.titleSmall),
          for(final (id,hidden) in v.abilities)Padding(padding:const EdgeInsets.symmetric(vertical:3),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text('${widget.details?.abilities[id]??id}${abilityRoleLabel(id, hidden) == 'Principal' ? '' : ' (${abilityRoleLabel(id, hidden)})'}',style:theme.textTheme.bodyMedium),
              if((widget.details?.abilityEffects[id]??'').isNotEmpty)Text(widget.details!.abilityEffects[id]!,style:theme.textTheme.bodySmall)]))],
        if(v.enc.isNotEmpty)...[const SizedBox(height:10),Text('Dónde encontrar esta forma',style:theme.textTheme.titleSmall),
          for(final game in v.enc.entries)for(final version in game.value.entries)Padding(
            padding:const EdgeInsets.only(top:5),child:Text('${game.key} · ${version.key}: ${version.value.map((e)=>e.area).toSet().join(', ')}',style:theme.textTheme.bodySmall))],
      ])));
  }
  String _measure(double v)=>v.toStringAsFixed(v==v.roundToDouble()?0:1);
  String _typeName(String t)=>const {'normal':'Normal','fire':'Fuego','water':'Agua','electric':'Eléctrico',
    'grass':'Planta','ice':'Hielo','fighting':'Lucha','poison':'Veneno','ground':'Tierra','flying':'Volador',
    'psychic':'Psíquico','bug':'Bicho','rock':'Roca','ghost':'Fantasma','dragon':'Dragón','dark':'Siniestro',
    'steel':'Acero','fairy':'Hada'}[t]??t;
}

class PokemonCompareScreen extends StatefulWidget {
  final List<Species> species;
  final DexDetails? details;
  final AppSettings settings;
  const PokemonCompareScreen({super.key,required this.species,required this.details,required this.settings});
  @override
  State<PokemonCompareScreen> createState()=>_PokemonCompareScreenState();
}

class _PokemonCompareScreenState extends State<PokemonCompareScreen> {
  int _a=1,_b=4;
  @override
  Widget build(BuildContext context) {
    final sorted=[...widget.species]..sort((a,b)=>a.dex.compareTo(b.dex));
    final a=sorted.firstWhere((s)=>s.dex==_a,orElse:()=>sorted.first);
    final b=sorted.firstWhere((s)=>s.dex==_b,orElse:()=>sorted.length>1?sorted[1]:sorted.first);
    final av=widget.details?.species(a.dex)?.varieties ?? const <VarietyInfo>[];
    final bv=widget.details?.species(b.dex)?.varieties ?? const <VarietyInfo>[];
    final ai=av.isEmpty?null:av.first;
    final bi=bv.isEmpty?null:bv.first;
    final stats=['PS','Ataque','Defensa','Ataque especial','Defensa especial','Velocidad'];
    Widget picker(String label,int value,ValueChanged<int> change)=>DropdownButtonFormField<int>(
      value:value,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),
      isExpanded:true,items:[for(final s in sorted)DropdownMenuItem(value:s.dex,
        child:Text('#${s.dex} ${s.displayName(widget.settings.spanish)}',overflow:TextOverflow.ellipsis))],
      onChanged:(v){if(v!=null)change(v);});
    Widget panel(Species s,VarietyInfo? v)=>Expanded(child:Column(children:[
      Sprite(s.entries.first.sprite,size:110,pixel:widget.settings.pixelSprites,threeD:widget.settings.threeDSprites),
      Text(s.displayName(widget.settings.spanish),style:Theme.of(context).textTheme.titleMedium),
      Text('#${s.dex}'),
      if(v!=null)Wrap(spacing:4,children:[for(final t in v.types)Chip(label:Text(t))]),
    ]));
    Widget statRow(String label,int? x,int? y) {
      final same=x==y;
      return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
        Expanded(child:Text(x==null?'—':'$x',textAlign:TextAlign.center,
          style:TextStyle(fontWeight:same?FontWeight.normal:FontWeight.bold))),
        Expanded(flex:2,child:Text(label,textAlign:TextAlign.center)),
        Expanded(child:Text(y==null?'—':'$y',textAlign:TextAlign.center,
          style:TextStyle(fontWeight:same?FontWeight.normal:FontWeight.bold))),
      ]));
    }
    Widget textRow(String label,String x,String y)=>Padding(
      padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[
        Expanded(child:Text(x,textAlign:TextAlign.center)),
        Expanded(flex:2,child:Text(label,textAlign:TextAlign.center)),
        Expanded(child:Text(y,textAlign:TextAlign.center)),
      ]));
    return Scaffold(appBar:AppBar(title:const Text('Comparar Pokémon')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Row(children:[Expanded(child:picker('Pokémon 1',_a,(v)=>setState(()=>_a=v))),
        const SizedBox(width:10),Expanded(child:picker('Pokémon 2',_b,(v)=>setState(()=>_b=v)))]),
      const SizedBox(height:18),Row(children:[panel(a,ai),const Padding(padding:EdgeInsets.all(8),child:Text('VS',style:TextStyle(fontWeight:FontWeight.bold))),panel(b,bi)]),
      const Divider(height:28),
      Text('Estadísticas base',style:Theme.of(context).textTheme.titleLarge),
      for(var i=0;i<6;i++)statRow(stats[i],ai!=null&&i<ai.stats.length?ai.stats[i]:null,bi!=null&&i<bi.stats.length?bi.stats[i]:null),
      const Divider(height:24),
      statRow('Total',ai?.stats.fold<int>(0,(x,y)=>x+y),bi?.stats.fold<int>(0,(x,y)=>x+y)),
      textRow('Altura',ai==null?'—':'${(ai.height/10).toStringAsFixed(1)} m',bi==null?'—':'${(bi.height/10).toStringAsFixed(1)} m'),
      textRow('Peso',ai==null?'—':'${(ai.weight/10).toStringAsFixed(1)} kg',bi==null?'—':'${(bi.weight/10).toStringAsFixed(1)} kg'),
      statRow('Experiencia base',ai?.exp,bi?.exp),
      textRow('Habilidades',ai?.abilities.map((e)=>'${widget.details?.abilities[e.$1]??e.$1}${abilityRoleLabel(e.$1, e.$2) == 'Principal' ? '' : ' (${abilityRoleLabel(e.$1, e.$2)})'}').join(', ')??'—',
        bi?.abilities.map((e)=>'${widget.details?.abilities[e.$1]??e.$1}${abilityRoleLabel(e.$1, e.$2) == 'Principal' ? '' : ' (${abilityRoleLabel(e.$1, e.$2)})'}').join(', ')??'—'),
      const SizedBox(height:12),
      Text('Las estadísticas resaltadas en negrita indican valores diferentes.',style:Theme.of(context).textTheme.bodySmall),
    ]));
  }
}

class _StatRow extends StatelessWidget {
  final String label; final int value;
  const _StatRow({required this.label,required this.value});
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(children:[
    SizedBox(width:90,child:Text(label)),Expanded(child:LinearProgressIndicator(value:(value/255).clamp(0,1).toDouble())),
    const SizedBox(width:10),SizedBox(width:32,child:Text('$value',textAlign:TextAlign.end))]));
}
