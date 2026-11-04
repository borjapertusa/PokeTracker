/// Datos de ficha (assets/data/details.json, generado por tools/build_details.py).

class Encounter {
  final String area;
  final List<String> methods;
  final int lo, hi, chance;
  final List<String> conds;

  Encounter.fromJson(List j)
      : area = j[0] as String,
        methods = (j[1] as List).cast<String>(),
        lo = j[2] as int,
        hi = j[3] as int,
        chance = j[4] as int,
        conds = (j[5] as List).cast<String>();
}

class VarietyInfo {
  final String name;
  final bool isDefault;
  final List<String> types;
  final List<int> stats; // PS, Ataque, Defensa, At. Esp., Def. Esp., Velocidad
  final List<(String, bool)> abilities; // (id, oculta)
  final int height, weight, exp; // decímetros, hectogramos
  final Map<String, Map<String, List<Encounter>>> enc; // juego -> versión -> zonas

  VarietyInfo.fromJson(Map<String, dynamic> j)
      : name = j['n'] as String,
        isDefault = j['d'] as bool,
        types = (j['types'] as List).cast<String>(),
        stats = (j['stats'] as List).cast<int>(),
        abilities = [
          for (final a in j['ab'] as List) ((a as List)[0] as String, a[1] == 1),
        ],
        height = j['h'] as int,
        weight = j['w'] as int,
        exp = j['exp'] as int,
        enc = _parseEnc(j['enc']);

  static Map<String, Map<String, List<Encounter>>> _parseEnc(dynamic raw) {
    final out = <String, Map<String, List<Encounter>>>{};
    if (raw is Map<String, dynamic>) {
      raw.forEach((game, versions) {
        out[game] = {
          for (final v in (versions as Map<String, dynamic>).entries)
            v.key: [
              for (final r in v.value as List) Encounter.fromJson(r as List),
            ],
        };
      });
    }
    return out;
  }
}

class SpeciesInfo {
  final String genus, text, growth;
  final List<String> egg;
  final int? catchRate, hatch, happy, chain;
  final int female; // octavos de hembra; -1 = sin género
  final List<VarietyInfo> varieties; // la primera es la forma por defecto

  SpeciesInfo.fromJson(Map<String, dynamic> j)
      : genus = j['genus'] as String? ?? '',
        text = j['text'] as String? ?? '',
        growth = j['growth'] as String? ?? '',
        egg = (j['egg'] as List).cast<String>(),
        catchRate = j['catch'] as int?,
        hatch = j['hatch'] as int?,
        happy = j['happy'] as int?,
        chain = j['chain'] as int?,
        female = (j['female'] as int?) ?? -1,
        varieties = (j['varieties'] as List)
            .map((v) => VarietyInfo.fromJson(v as Map<String, dynamic>))
            .toList();
}

class EvoNode {
  final int dex;
  final List<(String, EvoNode)> to; // (requisito, evolución)

  EvoNode.fromJson(Map<String, dynamic> j)
      : dex = (j['d'] as int?) ?? 0,
        to = [
          for (final k in j['to'] as List)
            (
              (k as Map<String, dynamic>)['r'] as String,
              EvoNode.fromJson(k['n'] as Map<String, dynamic>),
            ),
        ];
}

/// Pasos de la línea evolutiva: (desde, requisito, hasta).
List<(int, String, int)> evoEdges(EvoNode n) => [
      for (final (req, child) in n.to) ...[
        (n.dex, req, child.dex),
        ...evoEdges(child),
      ],
    ];

class DexDetails {
  final Map<String, dynamic> _species;
  final Map<String, dynamic> _chains;
  final Map<String, String> abilities;

  DexDetails._(this._species, this._chains, this.abilities);

  factory DexDetails.fromJson(Map<String, dynamic> j) => DexDetails._(
        j['species'] as Map<String, dynamic>,
        j['chains'] as Map<String, dynamic>,
        (j['abilities'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as String)),
      );

  SpeciesInfo? species(int dex) {
    final m = _species['$dex'];
    return m == null ? null : SpeciesInfo.fromJson(m as Map<String, dynamic>);
  }

  EvoNode? chain(int? id) {
    if (id == null) return null;
    final m = _chains['$id'];
    return m == null ? null : EvoNode.fromJson(m as Map<String, dynamic>);
  }
}
