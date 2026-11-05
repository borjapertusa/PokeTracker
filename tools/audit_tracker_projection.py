#!/usr/bin/env python3
"""Auditoría estática de las formas que deben aparecer en el tracker actual.
No modifica los JSON ni los sprites originales.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
data = json.loads((ROOT / 'assets/data/pokedex.json').read_text(encoding='utf-8'))
species = {s['dex']: s for s in data['species']}

def visible(dex, entry):
    name, ident = species[dex]['name'], entry['id']
    if 'totem' in ident: return False
    if dex == 3 and ident == 'venusaur-mega-f': return False
    if dex == 25 and (any(x in ident for x in ('rock-star','belle','pop-star','phd','libre','cosplay')) or ident in ('pikachu-starter','pikachu-starter-f')): return False
    if dex == 133 and ident.startswith('eevee-starter'): return False
    if dex == 351 and ident != 'castform': return False
    if dex == 421 and ident == 'cherrim-sunshine': return False
    if dex in (483,484,487) and ident.endswith('-origin'): return False
    if dex == 493 and ident != 'arceus-normal': return False
    if dex == 555 and ident in ('darmanitan-zen','darmanitan-galar-zen'): return False
    if dex == 646 and ident in ('kyurem-black','kyurem-white'): return False
    if dex == 678 and ident in ('meowstic-female','meowstic-female-mega'): return False
    if dex == 716 and ident == 'xerneas-neutral': return False
    if dex == 718 and ident in ('zygarde-10-power-construct','zygarde-50-power-construct','zygarde-complete'): return False
    if dex == 773 and ident != 'silvally-normal': return False
    if dex == 774 and 'meteor' in ident: return False
    if dex == 778 and ident != 'mimikyu-disguised': return False
    if dex == 800 and ident != 'necrozma': return False
    if dex == 801 and ident == 'magearna-original-mega': return False
    if dex == 845 and ident != 'cramorant': return False
    if dex == 876 and ident == 'indeedee-female': return False
    if dex == 877 and ident == 'morpeko-hangry': return False
    if dex in (888,889) and ident.endswith('-crowned'): return False
    if dex == 890 and ident == 'eternatus-eternamax': return False
    if dex == 916 and ident == 'oinkologne-female': return False
    if dex == 978 and ident in ('tatsugiri-droopy-mega','tatsugiri-stretchy-mega'): return False
    if dex in (1007,1008) and ident != name: return False
    if dex in (1017,1024) and ident != name: return False
    return True

checks = {
  3: {'venusaur','venusaur-f','venusaur-mega','venusaur-gmax'},
  351: {'castform'}, 421: {'cherrim-overcast'},
  483: {'dialga'}, 484: {'palkia'}, 487: {'giratina-altered'},
  493: {'arceus-normal'}, 646: {'kyurem'}, 678: {'meowstic-male','meowstic-male-f','meowstic-male-mega'},
  716: {'xerneas-active'}, 718: {'zygarde-50','zygarde-10','zygarde-mega'},
  773: {'silvally-normal'}, 774: {'minior-red','minior-orange','minior-yellow','minior-green','minior-blue','minior-indigo','minior-violet'},
  778: {'mimikyu-disguised'}, 800: {'necrozma'}, 801: {'magearna','magearna-original','magearna-mega'},
  845: {'cramorant'}, 876: {'indeedee-male','indeedee-male-f'}, 877: {'morpeko-full-belly'},
  888: {'zacian'}, 889: {'zamazenta'}, 890: {'eternatus'}, 916: {'oinkologne-male','oinkologne-male-f'},
  978: {'tatsugiri-curly','tatsugiri-droopy','tatsugiri-stretchy','tatsugiri-curly-mega'},
  1007: {'koraidon'}, 1008: {'miraidon'}, 1017: {'ogerpon'}, 1024: {'terapagos'},
}
errors=[]
for dex, expected in checks.items():
    actual={e['id'] for e in species[dex]['entries'] if visible(dex,e)}
    if actual != expected:
        errors.append(f"{species[dex]['name']} ({dex}): esperadas {sorted(expected)}, obtenidas {sorted(actual)}")
# No se destruyen ni alteran las entradas originales; la proyección solo filtra en memoria.
print(f"Especies auditadas: {len(species)}")
print(f"Reglas con conjuntos de formas esperadas: {len(checks)}")
print(f"Entradas originales conservadas: {sum(len(s['entries']) for s in species.values())}")
if errors:
    print('FALLOS:')
    print('\n'.join(errors))
    raise SystemExit(1)
print('RESULTADO: OK — los conjuntos comprobados coinciden con las formas esperadas.')
