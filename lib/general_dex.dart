import 'package:flutter/material.dart';

import 'details.dart';
import 'info.dart';
import 'detail.dart';
import 'evolution_chart.dart';
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
  Species? _selected; // ficha mostrada en el panel lateral (pantallas anchas)

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Widget _detail(Species sp, {bool embedded = false}) => GeneralPokemonDetail(
      key: embedded ? ValueKey('panel-${sp.dex}') : null,
      species: sp, byDex: widget.byDex, details: widget.details,
      settings: widget.settings, embedded: embedded);

  /// Doble clic: ficha completa en una ventana nueva.
  void _openFull(Species sp) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => _detail(sp)));

  void _onTap(Species sp, bool wide) {
    if (wide) {
      setState(() => _selected = sp);
    } else {
      _openFull(sp);
    }
  }

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
      body: LayoutBuilder(builder: (context, box) {
        final wide = box.maxWidth >= 1000;
        final list = Column(children: [
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
              final sel = wide && identical(sp, _selected);
              return Card(clipBehavior:Clip.antiAlias,
                shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12),
                  side:BorderSide(color:sel?Theme.of(context).colorScheme.primary:Theme.of(context).colorScheme.outlineVariant,width:sel?2:1)),
                child:InkWell(
                onTap:()=>_onTap(sp, wide),
                onDoubleTap:()=>_openFull(sp),
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
      ]);
        if (!wide) return list;
        final theme = Theme.of(context);
        return Row(children: [
          Expanded(child: list),
          const VerticalDivider(width: 1),
          SizedBox(width: 460, child: _selected == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24),
                child: Text('Selecciona un Pokémon para ver su ficha.\nDoble clic para abrirla en una ventana.',
                  textAlign: TextAlign.center, style: theme.textTheme.bodyMedium)))
            : _detail(_selected!, embedded: true)),
        ]);
      }),
    );
  }
}

/// Ficha de un Pokémon en la Pokédex general. Usa EXACTAMENTE la misma vista
/// que la ventana de información del tracker (doble clic): en la ventana grande
/// el contenido va centrado y los sprites se pueden ampliar; en el panel lateral
/// (embedded) es la versión compacta.
class GeneralPokemonDetail extends StatelessWidget {
  final Species species;
  final Map<int, Species> byDex;
  final DexDetails? details;
  final AppSettings settings;
  final bool embedded; // true: sin Scaffold, para el panel lateral
  const GeneralPokemonDetail({super.key,required this.species,required this.byDex,
    required this.details,required this.settings,this.embedded=false});

  @override
  Widget build(BuildContext context) {
    final home = kHomeGame;
    final title = '#${species.dex.toString().padLeft(4,'0')}  ${species.displayName(settings.spanish)}';
    if (home == null) {
      return Scaffold(appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('Datos del juego no disponibles.')));
    }
    final gs = GameSpecies(species, species.dex, species.entries);
    final expanded = !embedded;
    final theme = Theme.of(context);
    final sz = settings.spriteSize.clamp(64.0, 128.0).toDouble() * (expanded ? 1.3 : 1.0);

    Widget card(DexEntry e) {
      Widget sprite(String? path, bool shiny) => Stack(
        alignment: Alignment.topRight,
        children: [
          Sprite(path, size: sz, pixel: settings.pixelSprites, threeD: settings.threeDSprites),
          Tooltip(message: 'Ampliar', child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => showSpriteZoom(context, game: home, entry: e, settings: settings, shiny: shiny),
            child: const Padding(padding: EdgeInsets.all(3), child: Icon(Icons.zoom_in, size: 20)))),
        ],
      );
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Column(mainAxisSize: MainAxisSize.min, children: [
                sprite(e.sprite, false),
                Text('Normal', style: theme.textTheme.labelSmall),
              ]),
              if (e.shiny != null) ...[
                const SizedBox(width: 6),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  sprite(e.shiny, true),
                  Text('✨ Variocolor', style: theme.textTheme.labelSmall),
                ]),
              ],
            ]),
          ]),
        ),
      );
    }

    final content = ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title,
              textAlign: expanded ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.headlineSmall),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
          child: Wrap(
            alignment: expanded ? WrapAlignment.center : WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            children: [for (final e in species.entries) card(e)],
          ),
        ),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: expanded ? 1100 : double.infinity),
            child: PokemonInfo(
              game: home,
              games: kOfficialGames,
              gs: gs,
              details: details,
              byDex: byDex,
              settings: settings,
              showLocations: true,
              showMoves: true,
              expanded: expanded,
            ),
          ),
        ),
      ],
    );
    if (embedded) return Material(color: Colors.transparent, child: content);
    return Scaffold(appBar: AppBar(title: Text(title)), body: content);
  }
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
  int _a=1,_b=4;      // número de Pokédex de cada lado
  int _av=0,_bv=0;    // forma seleccionada de cada lado

  late final List<Species> _sorted=[...widget.species]..sort((a,b)=>a.dex.compareTo(b.dex));

  Species _species(int dex)=>_sorted.firstWhere((s)=>s.dex==dex,orElse:()=>_sorted.first);

  List<VarietyInfo> _varieties(Species s)=>widget.details?.species(s.dex)?.varieties ?? const <VarietyInfo>[];

  String _formLabel(Species sp,VarietyInfo v){
    if(v.name==sp.name) return 'Base';
    final suffix=v.name.startsWith('${sp.name}-')?v.name.substring(sp.name.length+1):v.name;
    return localizedFormName(suffix);
  }

  DexEntry _entryFor(Species s,VarietyInfo? v){
    if(v!=null){ for(final e in s.entries){ if(e.id==v.name) return e; } }
    return s.entries.first;
  }

  /// Buscador de Pokémon: filtra por nombre (español o inglés) o número.
  Future<int?> _pick(String title,int current)=>showDialog<int>(context:context,builder:(context){
    var q='';
    return StatefulBuilder(builder:(context,setLocal){
      final text=q.trim().toLowerCase();
      final list=text.isEmpty?_sorted:_sorted.where((s)=>
        s.displayName(widget.settings.spanish).toLowerCase().contains(text)||
        s.name.contains(text)||s.nameEs.toLowerCase().contains(text)||'${s.dex}'==text).toList();
      return Dialog(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:460,maxHeight:620),
        child:Column(children:[
          Padding(padding:const EdgeInsets.fromLTRB(16,16,16,8),child:Row(children:[
            Expanded(child:Text(title,style:Theme.of(context).textTheme.titleMedium)),
            IconButton(tooltip:'Cerrar',icon:const Icon(Icons.close),onPressed:()=>Navigator.pop(context)),
          ])),
          Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:TextField(
            autofocus:true,
            decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'Buscar por nombre o número',isDense:true,border:OutlineInputBorder()),
            onChanged:(v)=>setLocal(()=>q=v),
            onSubmitted:(_){ if(list.isNotEmpty) Navigator.pop(context,list.first.dex); },
          )),
          const SizedBox(height:6),
          Expanded(child:list.isEmpty
            ?const Center(child:Text('No hay Pokémon que coincidan.'))
            :ListView.builder(itemCount:list.length,itemBuilder:(context,i){
              final s=list[i];
              return ListTile(
                selected:s.dex==current,
                leading:CircleAvatar(radius:20,backgroundColor:Theme.of(context).colorScheme.surfaceContainerHighest,
                  child:ClipOval(child:Sprite(s.entries.first.sprite,size:36,pixel:widget.settings.pixelSprites,threeD:widget.settings.threeDSprites))),
                title:Text(s.displayName(widget.settings.spanish)),
                subtitle:Text('#${s.dex.toString().padLeft(4,'0')}'),
                onTap:()=>Navigator.pop(context,s.dex),
              );
            })),
        ])));
    });
  });

  @override
  Widget build(BuildContext context) {
    final theme=Theme.of(context);
    final a=_species(_a),b=_species(_b);
    final avs=_varieties(a),bvs=_varieties(b);
    final ai=avs.isEmpty?null:avs[_av.clamp(0,avs.length-1)];
    final bi=bvs.isEmpty?null:bvs[_bv.clamp(0,bvs.length-1)];
    final stats=['PS','Ataque','Defensa','Ataque especial','Defensa especial','Velocidad'];

    Widget panel(String label,Species s,List<VarietyInfo> vs,VarietyInfo? v,int sel,VoidCallback onPick,ValueChanged<int> onForm)=>Expanded(child:Column(children:[
      OutlinedButton(onPressed:onPick,child:Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(mainAxisSize:MainAxisSize.min,children:[
        const Icon(Icons.search,size:18),const SizedBox(width:6),
        Flexible(child:Text('$label: ${s.displayName(widget.settings.spanish)}',overflow:TextOverflow.ellipsis)),
      ]))),
      const SizedBox(height:8),
      Sprite(_entryFor(s,v).sprite,size:110,pixel:widget.settings.pixelSprites,threeD:widget.settings.threeDSprites),
      Text(s.displayName(widget.settings.spanish),style:theme.textTheme.titleMedium,textAlign:TextAlign.center),
      Text('#${s.dex}'),
      if(v!=null)Padding(padding:const EdgeInsets.only(top:6),child:Wrap(spacing:6,runSpacing:4,alignment:WrapAlignment.center,children:[for(final t in v.types)TypeChip(t)])),
      if(vs.length>1)Padding(padding:const EdgeInsets.only(top:8),child:Wrap(spacing:6,runSpacing:6,alignment:WrapAlignment.center,children:[
        for(var i=0;i<vs.length;i++)ChoiceChip(label:Text(_formLabel(s,vs[i])),selected:i==sel,onSelected:(_)=>onForm(i)),
      ])),
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
    String abilitiesOf(VarietyInfo? v)=>v?.abilities.map((e)=>'${widget.details?.abilities[e.$1]??e.$1}${abilityRoleLabel(e.$1,e.$2)=='Principal'?'':' (${abilityRoleLabel(e.$1,e.$2)})'}').join(', ')??'—';

    return Scaffold(appBar:AppBar(title:const Text('Comparar Pokémon')),body:ListView(padding:const EdgeInsets.all(16),children:[
      Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        panel('Pokémon 1',a,avs,ai,_av,() async{final d=await _pick('Elegir Pokémon 1',_a);if(d!=null)setState((){_a=d;_av=0;});},(i)=>setState(()=>_av=i)),
        const Padding(padding:EdgeInsets.all(8),child:Text('VS',style:TextStyle(fontWeight:FontWeight.bold))),
        panel('Pokémon 2',b,bvs,bi,_bv,() async{final d=await _pick('Elegir Pokémon 2',_b);if(d!=null)setState((){_b=d;_bv=0;});},(i)=>setState(()=>_bv=i)),
      ]),
      const Divider(height:28),
      Text('Estadísticas base',style:theme.textTheme.titleLarge),
      for(var i=0;i<6;i++)statRow(stats[i],ai!=null&&i<ai.stats.length?ai.stats[i]:null,bi!=null&&i<bi.stats.length?bi.stats[i]:null),
      const Divider(height:24),
      statRow('Total',ai?.stats.fold<int>(0,(x,y)=>x+y),bi?.stats.fold<int>(0,(x,y)=>x+y)),
      textRow('Altura',ai==null?'—':'${(ai.height/10).toStringAsFixed(1)} m',bi==null?'—':'${(bi.height/10).toStringAsFixed(1)} m'),
      textRow('Peso',ai==null?'—':'${(ai.weight/10).toStringAsFixed(1)} kg',bi==null?'—':'${(bi.weight/10).toStringAsFixed(1)} kg'),
      statRow('Experiencia base',ai?.exp,bi?.exp),
      textRow('Habilidades',abilitiesOf(ai),abilitiesOf(bi)),
      const SizedBox(height:12),
      Text('Las estadísticas resaltadas en negrita indican valores diferentes.',style:theme.textTheme.bodySmall),
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
