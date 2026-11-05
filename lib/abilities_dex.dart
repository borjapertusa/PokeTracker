import 'package:flutter/material.dart';
import 'details.dart';
import 'models.dart';
import 'settings.dart';

/// Efectos de habilidades fuera del combate. Se indican las generaciones en
/// las que están documentados; las habilidades no incluidas no tienen un
/// efecto de campo conocido en los juegos principales.
const Map<String, String> _fieldEffects = {
  'flame-body': 'Incubación: si el Pokémon está en el equipo, reduce a la mitad los pasos necesarios para eclosionar huevos (desde la Generación III).',
  'magma-armor': 'Incubación: si está en el equipo, reduce a la mitad los pasos necesarios para eclosionar huevos (desde la Generación III).',
  'honey-gather': 'Tras los combates, puede conseguir Miel sin necesidad de usar el movimiento Dulce Aroma. La probabilidad y los objetos dependen de la generación (introducida en la IV).',
  'pickup': 'Después de un combate puede recoger un objeto. Desde la Generación III puede recoger objetos usados por otros Pokémon; en generaciones posteriores también puede encontrar objetos al terminar el combate. La lista de objetos cambia según el juego y la generación.',
  'compound-eyes': 'Aumenta la probabilidad de que los Pokémon salvajes lleven objetos (desde la Generación III; la probabilidad exacta depende del juego).',
  'super-luck': 'Aumenta la probabilidad de encontrar Pokémon salvajes que lleven objetos (desde la Generación IV).',
  'synchronize': 'Desde la Generación IV, al liderar el equipo, tiene un 50 % de probabilidad de hacer que un Pokémon salvaje tenga la misma naturaleza. En generaciones posteriores puede haber excepciones según el encuentro.',
  'cute-charm': 'Al liderar el equipo, puede provocar encuentros con Pokémon salvajes del género opuesto con mayor frecuencia. El funcionamiento y la probabilidad varían según la generación (desde la Generación III).',
  'static': 'Desde la Generación III, al liderar el equipo aumenta la probabilidad de encontrar Pokémon salvajes de tipo Eléctrico (50 % en los juegos compatibles).',
  'magnet-pull': 'Desde la Generación IV, al liderar el equipo aumenta la probabilidad de encontrar Pokémon salvajes de tipo Acero (50 % en los juegos compatibles).',
  'illuminate': 'Modifica los encuentros salvajes: en generaciones antiguas aumentaba su frecuencia; desde la Generación IX aumenta la probabilidad de encontrar Pokémon salvajes (según el método y el juego).',
  'pressure': 'Desde la Generación IV, al liderar el equipo aumenta la probabilidad de encontrar Pokémon salvajes de nivel superior.',
  'hustle': 'Desde la Generación IV, al liderar el equipo aumenta la probabilidad de encontrar Pokémon salvajes de nivel superior.',
  'vital-spirit': 'Desde la Generación IV, al liderar el equipo aumenta la probabilidad de encontrar Pokémon salvajes de nivel superior.',
  'intimidate': 'Desde la Generación III, al liderar el equipo reduce la probabilidad de encontrar Pokémon salvajes de nivel inferior (en los juegos compatibles).',
  'stench': 'En algunas generaciones reduce la frecuencia de encuentros salvajes; el efecto ha cambiado entre juegos y no está presente en todos.',
  'white-smoke': 'Desde la Generación IV, reduce la frecuencia de encuentros salvajes (en los juegos compatibles).',
  'suction-cups': 'En algunas generaciones aumenta la probabilidad de que la pesca tenga éxito al liderar el equipo (desde la Generación III; el efecto varía según el juego).',
};

class AbilityDexScreen extends StatefulWidget {
  final List<Species> species;
  final DexDetails? details;
  final AppSettings settings;
  const AbilityDexScreen({super.key, required this.species, required this.details, required this.settings});
  @override
  State<AbilityDexScreen> createState() => _AbilityDexScreenState();
}

class _AbilityDexScreenState extends State<AbilityDexScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _filter = 'Todas';
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final details = widget.details;
    final abilities = details?.abilities.entries.toList() ?? [];
    abilities.sort((a,b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    final q = _query.trim().toLowerCase();
    final filtered = abilities.where((a) {
      final matches = q.isEmpty || a.value.toLowerCase().contains(q) || a.key.contains(q) ||
          ((widget.settings.spanish ? details?.abilityEffectsEs[a.key] : details?.abilityEffects[a.key]) ?? '').toLowerCase().contains(q) ||
          (_fieldEffects[a.key] ?? '').toLowerCase().contains(q) ||
          widget.species.any((sp) => sp.displayName(widget.settings.spanish).toLowerCase().contains(q) &&
            (details?.species(sp.dex)?.varieties.any((v) => v.abilities.any((entry) => entry.$1 == a.key)) ?? false));
      final hasField = _fieldEffects.containsKey(a.key);
      return matches && (_filter != 'Con efecto fuera de combate' || hasField) &&
          (_filter != 'Sin efecto fuera de combate' || !hasField);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Habilidades')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16,12,16,8), child: TextField(
          controller: _search, onChanged: (v)=>setState(()=>_query=v),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Buscar habilidad, efecto o Pokémon...', border: OutlineInputBorder(), isDense: true),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal:16), child: Row(children:[
          Expanded(child: DropdownButton<String>(isExpanded:true, value:_filter, items: const [
            DropdownMenuItem(value:'Todas',child:Text('Todas las habilidades')),
            DropdownMenuItem(value:'Con efecto fuera de combate',child:Text('Con efecto fuera de combate')),
            DropdownMenuItem(value:'Sin efecto fuera de combate',child:Text('Sin efecto fuera de combate')),
          ], onChanged:(v)=>setState(()=>_filter=v??'Todas'))),
          const SizedBox(width:12), Text('${filtered.length} / ${abilities.length}', style:Theme.of(context).textTheme.labelMedium),
        ])),
        Expanded(child: ListView.builder(padding:const EdgeInsets.all(12), itemCount:filtered.length, itemBuilder:(context,i) {
          final a=filtered[i];
          final holders=_holders(a.key);
          return Card(child: ListTile(
            leading: CircleAvatar(child: const Icon(Icons.auto_awesome)),
            title: Text(a.value),
            subtitle: Text('${holders.length} Pokémon · ${_fieldEffects.containsKey(a.key)?'Efecto fuera de combate':'Sin efecto de campo conocido'}'),
            trailing: const Icon(Icons.chevron_right),
            onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>AbilityDetailScreen(
              id:a.key,name:a.value,details:details,species:widget.species,settings:widget.settings))),
          ));
        })),
      ]),
    );
  }

  List<_AbilityHolder> _holders(String id) {
    final out=<_AbilityHolder>[];
    for(final s in widget.species) {
      final info=widget.details?.species(s.dex);
      if(info==null) continue;
      final found=<String>{};
      final roles=<String>{};
      for(final v in info.varieties) {
        for(final (ability,hidden) in v.abilities) {
          if(ability==id) { found.add(localizedFormName(v.name)); roles.add(abilityRoleLabel(ability, hidden)); }
        }
      }
      if(found.isNotEmpty) out.add(_AbilityHolder(s,found.toList()..sort(),roles.toList()));
    }
    return out;
  }
}

class _AbilityHolder {
  final Species species; final List<String> forms; final List<String> roles;
  _AbilityHolder(this.species,this.forms,this.roles);
}

class AbilityDetailScreen extends StatelessWidget {
  final String id,name; final DexDetails? details; final List<Species> species; final AppSettings settings;
  const AbilityDetailScreen({super.key,required this.id,required this.name,required this.details,required this.species,required this.settings});
  @override
  Widget build(BuildContext context) {
    final holders=<_AbilityHolder>[];
    for(final s in species) {
      final info=details?.species(s.dex); if(info==null) continue;
      final forms=<String>{}; final roles=<String>{};
      for(final v in info.varieties) for(final (a,hidden) in v.abilities) {
        if(a==id) { forms.add(localizedFormName(v.name)); roles.add(abilityRoleLabel(a, hidden)); }
      }
      if(forms.isNotEmpty) holders.add(_AbilityHolder(s,forms.toList()..sort(),roles.toList()));
    }
    holders.sort((a,b)=>a.species.dex.compareTo(b.species.dex));
    final battle = settings.spanish
        ? (details?.abilityEffectsEs[id] ?? 'La fuente no ofrece una descripción de esta habilidad en español.')
        : (details?.abilityEffects[id] ?? 'No hay descripción disponible.');
    final field=id == 'embody-aspect' ? 'No tiene efecto fuera de combate.' : _fieldEffects[id];
    final theme=Theme.of(context);
    return Scaffold(appBar:AppBar(title:Text(name)),body:ListView(padding:const EdgeInsets.all(18),children:[
      Center(child:Icon(Icons.auto_awesome,size:54,color:theme.colorScheme.primary)),
      Center(child:Text(name,style:theme.textTheme.headlineMedium,textAlign:TextAlign.center)),
      Center(child:Text(id,style:theme.textTheme.labelMedium)),
      _section(context,'Efecto en combate',battle),
      _section(context,'Efecto fuera de combate',field ?? 'No se conoce un efecto fuera de combate en los juegos principales.'),
      if(field!=null && id != 'embody-aspect') Padding(padding:const EdgeInsets.only(top:4),child:Text('Nota: algunos efectos dependen del juego, del método de encuentro y de la generación; se indican las generaciones conocidas en la descripción.',style:theme.textTheme.bodySmall)),
      Padding(padding:const EdgeInsets.only(top:24,bottom:8),child:Text('Pokémon que pueden tenerla (${holders.length})',style:theme.textTheme.titleLarge)),
      for(final h in holders) Card(child:ListTile(
        leading:CircleAvatar(child:Text('#${h.species.dex}')),
        title:Text(h.species.displayName(settings.spanish)),
        subtitle:Text('${h.roles.join(' / ')}\nFormas: ${h.forms.join(', ')}'),
        isThreeLine:true,
      )),
    ]));
  }
  Widget _section(BuildContext c,String title,String body)=>Padding(padding:const EdgeInsets.only(top:20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(title,style:Theme.of(c).textTheme.titleLarge),const SizedBox(height:7),
    Card(child:Padding(padding:const EdgeInsets.all(14),child:Text(body))),
  ]));
}
