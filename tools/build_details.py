#!/usr/bin/env python3
"""Genera assets/data/details.json con la ficha de cada Pokémon:
estadísticas base, tipos, habilidades, línea evolutiva (con requisitos),
datos de cría/captura y ubicaciones por juego (PokéAPI).

Reutiliza la caché de build_dataset.py; solo descarga lo nuevo (cadenas evolutivas,
encuentros y habilidades), así que la primera vez tarda unos minutos.
Uso:  python tools/build_details.py   (después de build_dataset.py)

Ojo: PokéAPI solo tiene ubicaciones de los juegos más antiguos; para los recientes la app
muestra enlaces a PokémonDB y Serebii. Al terminar se imprime la cobertura por juego.
"""
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone

import build_dataset as bd

API = bd.API
CONF = bd.ROOT / "tools" / "games_config.json"
OUT = bd.ROOT / "assets" / "data" / "details.json"

EGG = {"monster": "Monstruo", "water1": "Agua 1", "bug": "Bicho", "flying": "Volador", "field": "Campo",
       "fairy": "Hada", "grass": "Planta", "human-like": "Humanoide", "water3": "Agua 3", "mineral": "Mineral",
       "amorphous": "Amorfo", "water2": "Agua 2", "ditto": "Ditto", "dragon": "Dragón", "no-eggs": "Sin huevos"}
GROWTH = {"slow": "Lenta", "medium": "Media rápida", "fast": "Rápida", "medium-slow": "Media lenta",
          "slow-then-very-fast": "Errática", "fast-then-very-slow": "Fluctuante"}
TYPES = {"normal": "Normal", "fire": "Fuego", "water": "Agua", "electric": "Eléctrico", "grass": "Planta",
         "ice": "Hielo", "fighting": "Lucha", "poison": "Veneno", "ground": "Tierra", "flying": "Volador",
         "psychic": "Psíquico", "bug": "Bicho", "rock": "Roca", "ghost": "Fantasma", "dragon": "Dragón",
         "dark": "Siniestro", "steel": "Acero", "fairy": "Hada"}
METHOD = {"walk": "Caminando", "surf": "Surf", "old-rod": "Caña vieja", "good-rod": "Caña buena",
          "super-rod": "Supercaña", "rock-smash": "Golpe roca", "headbutt": "Golpe cabeza", "gift": "Regalo",
          "gift-egg": "Huevo regalo", "only-one": "Único (estático)", "pokeflute": "Poké Flauta",
          "roaming-grass": "Errante (hierba)", "roaming-water": "Errante (agua)", "npc-trade": "Intercambio con NPC",
          "cave-spots": "Sombras en cuevas", "bridge-spots": "Sombras en puentes", "squirt-bottle": "Regadera",
          "wailmer-pail": "Cubo Wailmer", "seaweed": "Algas", "devon-scope": "Detector Devon",
          "headbutt-low": "Golpe cabeza (raro)", "headbutt-normal": "Golpe cabeza", "headbutt-high": "Golpe cabeza (frecuente)",
          "sos-encounter": "Llamada de ayuda", "rock-smash-low": "Golpe roca", "dark-grass": "Hierba oscura",
          "grass-spots": "Hierba agitada", "yellow-flowers": "Flores amarillas", "purple-flowers": "Flores moradas",
          "red-flowers": "Flores rojas", "rough-terrain": "Terreno irregular", "surf-spots": "Sombras en el agua",
          "super-rod-spots": "Sombras (Supercaña)", "land-spots": "Sombras en tierra", "overworld": "Mundo abierto",
          "gift-egg": "Huevo regalo", "bubbling-spots": "Burbujas", "feebas-tile-fishing": "Casillas de Feebas"}
COND = {"time-morning": "Mañana", "time-day": "Día", "time-night": "Noche", "swarm-yes": "Enjambre",
        "swarm-no": "Sin enjambre", "radar-on": "Poké Radar", "radar-off": "Sin radar",
        "season-spring": "Primavera", "season-summer": "Verano", "season-autumn": "Otoño", "season-winter": "Invierno",
        "story-progress-beat-green-oak": "Tras vencer al Prof. Oak", "radio-hoenn": "Radio Hoenn",
        "radio-sinnoh": "Radio Sinnoh", "radio-off": "Radio apagada"}
ITEM = {"fire-stone": "Piedra Fuego", "water-stone": "Piedra Agua", "thunder-stone": "Piedra Trueno",
        "leaf-stone": "Piedra Hoja", "moon-stone": "Piedra Lunar", "sun-stone": "Piedra Solar",
        "shiny-stone": "Piedra Día", "dusk-stone": "Piedra Noche", "dawn-stone": "Piedra Alba",
        "ice-stone": "Piedra Hielo", "oval-stone": "Piedra Oval", "linking-cord": "Cable Unión"}
TIME = {"day": "de día", "night": "de noche", "dusk": "al anochecer"}
VERSION = {"red": "Rojo", "blue": "Azul", "yellow": "Amarillo", "gold": "Oro", "silver": "Plata", "crystal": "Cristal",
           "ruby": "Rubí", "sapphire": "Zafiro", "emerald": "Esmeralda", "firered": "Rojo Fuego", "leafgreen": "Verde Hoja",
           "diamond": "Diamante", "pearl": "Perla", "platinum": "Platino", "heartgold": "HeartGold", "soulsilver": "SoulSilver",
           "black": "Negro", "white": "Blanco", "black-2": "Negro 2", "white-2": "Blanco 2", "x": "X", "y": "Y",
           "omega-ruby": "Rubí Omega", "alpha-sapphire": "Zafiro Alfa", "sun": "Sol", "moon": "Luna",
           "ultra-sun": "Ultrasol", "ultra-moon": "Ultraluna", "lets-go-pikachu": "Let's Go Pikachu",
           "lets-go-eevee": "Let's Go Eevee", "sword": "Espada", "shield": "Escudo",
           "brilliant-diamond": "Diamante Brillante", "shining-pearl": "Perla Reluciente",
           "legends-arceus": "Leyendas Arceus", "scarlet": "Escarlata", "violet": "Púrpura",
           "the-teal-mask": "Máscara Turquesa", "the-indigo-disk": "Disco Índigo"}


def pretty(s):
    return " ".join(w.capitalize() for w in str(s).split("-"))


def safe_get(url):
    try:
        return bd.get(url)
    except Exception:
        return None


# ---------- evolución ----------
def req_one(d):
    trig = (d.get("trigger") or {}).get("name", "")
    item = (d.get("item") or {}).get("name")
    if trig == "level-up":
        main = f"Nivel {d['min_level']}" if d.get("min_level") else "Subir de nivel"
    elif trig == "trade":
        main = "Intercambio"
    elif trig == "use-item":
        main = "Usar " + ITEM.get(item, pretty(item or "objeto"))
    elif trig == "shed":
        main = "Con hueco en el equipo y una Poké Ball"
    elif trig == "spin":
        main = "Girar con un dulce"
    elif trig == "three-critical-hits":
        main = "3 golpes críticos en un combate"
    elif trig == "take-damage":
        main = "Recibir daño"
    elif trig == "recoil-damage":
        main = "Sufrir daño por retroceso"
    elif trig == "tower-of-darkness":
        main = "Completar la Torre Oscura"
    elif trig == "tower-of-waters":
        main = "Completar la Torre Agua"
    else:
        main = pretty(trig) if trig else "Evoluciona"
    extra = []
    nm = lambda k: (d.get(k) or {}).get("name")
    if nm("held_item"): extra.append(f"con {ITEM.get(nm('held_item'), pretty(nm('held_item')))} equipado")
    if nm("known_move"): extra.append(f"conociendo {pretty(nm('known_move'))}")
    if nm("known_move_type"): extra.append(f"conociendo un movimiento de tipo {TYPES.get(nm('known_move_type'), nm('known_move_type'))}")
    if d.get("min_happiness"): extra.append(f"amistad ≥ {d['min_happiness']}")
    if d.get("min_affection"): extra.append(f"cariño ≥ {d['min_affection']}")
    if d.get("min_beauty"): extra.append(f"belleza ≥ {d['min_beauty']}")
    if d.get("time_of_day"): extra.append(TIME.get(d["time_of_day"], d["time_of_day"]))
    if nm("location"): extra.append(f"en {pretty(nm('location'))}")
    if d.get("gender"): extra.append({1: "solo hembra", 2: "solo macho"}.get(d["gender"], ""))
    if d.get("relative_physical_stats") is not None:
        extra.append({1: "Ataque > Defensa", -1: "Ataque < Defensa", 0: "Ataque = Defensa"}[d["relative_physical_stats"]])
    if nm("party_species"): extra.append(f"con {pretty(nm('party_species'))} en el equipo")
    if nm("party_type"): extra.append(f"con un Pokémon de tipo {TYPES.get(nm('party_type'), nm('party_type'))} en el equipo")
    if nm("trade_species"): extra.append(f"por {pretty(nm('trade_species'))}")
    if d.get("needs_overworld_rain"): extra.append("con lluvia")
    if d.get("turn_upside_down"): extra.append("con la consola boca abajo")
    if d.get("min_damage_taken"): extra.append(f"tras recibir {d['min_damage_taken']} de daño")
    if nm("used_move"): extra.append(f"usando {pretty(nm('used_move'))} {d.get('min_move_count') or ''} veces".replace("  ", " "))
    if d.get("min_steps"): extra.append(f"{d['min_steps']} pasos")
    extra = [x for x in extra if x]
    return main + (f" ({', '.join(extra)})" if extra else "")


def req_text(details):
    out = []
    for d in details:
        t = req_one(d)
        if t not in out:
            out.append(t)
    return " / ".join(out) or "—"


def tree(node, dex_by_name):
    return {"d": dex_by_name.get(node["species"]["name"]),
            "to": [{"r": req_text(ev.get("evolution_details", [])), "n": tree(ev, dex_by_name)}
                   for ev in node.get("evolves_to", [])]}


# ---------- ubicaciones ----------
def compact_enc(data, ver2game):
    raw = {}
    for loc in data or []:
        area = loc["location_area"]["name"]
        for vd in loc["version_details"]:
            a = raw.setdefault(vd["version"]["name"], {}).setdefault(
                area, {"m": set(), "lo": 999, "hi": 0, "ch": 0, "c": set()})
            a["ch"] = max(a["ch"], vd.get("max_chance") or 0)
            for ed in vd["encounter_details"]:
                a["m"].add(ed["method"]["name"])
                a["lo"] = min(a["lo"], ed["min_level"])
                a["hi"] = max(a["hi"], ed["max_level"])
                for cv in ed.get("condition_values", []):
                    a["c"].add(cv["name"])
    out = {}
    for ver, areas in raw.items():
        game = ver2game.get(ver)
        if not game:
            continue
        rows = []
        for area, a in sorted(areas.items()):
            name = pretty(area[:-5] if area.endswith("-area") else area)
            rows.append([name, sorted(METHOD.get(m, pretty(m)) for m in a["m"]),
                         a["lo"] if a["lo"] != 999 else 0, a["hi"], a["ch"],
                         sorted(COND.get(c, pretty(c)) for c in a["c"])])
        out.setdefault(game, {})[VERSION.get(ver, pretty(ver))] = rows
    return out


def es_text(entries, key):
    es = [e for e in entries if e["language"]["name"] == "es"]
    pool = es or [e for e in entries if e["language"]["name"] == "en"]
    return pool[-1][key].replace("\n", " ").replace("\f", " ") if pool else ""


def make_processor(ver2game):
    def process(ref):
        sp = bd.get(ref["url"])
        varieties = []
        for v in sorted(sp["varieties"], key=lambda v: not v["is_default"]):
            pk = bd.get(v["pokemon"]["url"])
            st = {s["stat"]["name"]: s["base_stat"] for s in pk["stats"]}
            item = {"n": pk["name"], "d": bool(v["is_default"]),
                    "types": [t["type"]["name"] for t in sorted(pk["types"], key=lambda t: t["slot"])],
                    "stats": [st.get(k, 0) for k in ("hp", "attack", "defense", "special-attack", "special-defense", "speed")],
                    "ab": [[a["ability"]["name"], 1 if a["is_hidden"] else 0, a["ability"]["url"]]
                           for a in sorted(pk["abilities"], key=lambda a: a["slot"])],
                    "h": pk["height"], "w": pk["weight"], "exp": pk.get("base_experience") or 0}
            enc = compact_enc(safe_get(pk["location_area_encounters"]), ver2game)
            if enc:
                item["enc"] = enc
            varieties.append(item)
        info = {"genus": es_text(sp.get("genera", []), "genus"),
                "text": es_text(sp.get("flavor_text_entries", []), "flavor_text"),
                "egg": [EGG.get(g["name"], pretty(g["name"])) for g in sp.get("egg_groups", [])],
                "catch": sp.get("capture_rate"), "growth": GROWTH.get((sp.get("growth_rate") or {}).get("name"), ""),
                "female": sp.get("gender_rate", -1), "hatch": sp.get("hatch_counter"),
                "happy": sp.get("base_happiness"), "varieties": varieties}
        chain_url = (sp.get("evolution_chain") or {}).get("url")
        return sp["id"], info, chain_url
    return process


def main():
    conf = json.loads(CONF.read_text("utf-8"))
    ver2game = {v: g["id"] for g in conf["games"] for v in g.get("versions", [])}
    data = json.loads(bd.OUT.read_text("utf-8"))
    dex_by_name = {s["name"]: s["dex"] for s in data["species"]}
    refs = bd.get(f"{API}/pokemon-species?limit=3000")["results"]
    print(f"{len(refs)} especies: descargando fichas (la primera vez tarda unos minutos)...")
    with ThreadPoolExecutor(16) as ex:
        results = list(ex.map(make_processor(ver2game), refs))

    chain_urls = sorted({c for _, _, c in results if c})
    with ThreadPoolExecutor(16) as ex:
        chain_data = list(ex.map(safe_get, chain_urls))
    chains = {}
    for url, cd in zip(chain_urls, chain_data):
        if cd:
            chains[url.rstrip("/").rsplit("/", 1)[1]] = tree(cd["chain"], dex_by_name)

    ab_urls = sorted({a[2] for _, i, _ in results for v in i["varieties"] for a in v["ab"]})
    with ThreadPoolExecutor(16) as ex:
        ab_data = list(ex.map(safe_get, ab_urls))
    names = {}
    ability_effects = {}
    for url, ad in zip(ab_urls, ab_data):
        if ad:
            es = [n["name"] for n in ad["names"] if n["language"]["name"] == "es"]
            en = [n["name"] for n in ad["names"] if n["language"]["name"] == "en"]
            names[ad["name"]] = (es or en or [pretty(ad["name"])])[0]
            entries = ad.get("effect_entries", [])
            localized = [e for e in entries if e.get("language", {}).get("name") == "es"]
            fallback = [e for e in entries if e.get("language", {}).get("name") == "en"]
            selected = localized or fallback
            if selected:
                effect = selected[0].get("short_effect") or selected[0].get("effect") or ""
                ability_effects[ad["name"]] = effect.replace("\n", " ").replace("\f", " ").strip()

    species = {}
    cover = {}
    for dex, info, curl in results:
        info["chain"] = int(curl.rstrip("/").rsplit("/", 1)[1]) if curl else None
        for v in info["varieties"]:
            v["ab"] = [[a[0], a[1]] for a in v["ab"]]
            for g in v.get("enc", {}):
                cover[g] = cover.get(g, 0) + 1
        species[str(dex)] = info

    payload = {"generatedAt": datetime.now(timezone.utc).isoformat(), "abilities": names,
               "abilityEffects": ability_effects, "chains": chains, "species": species}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), "utf-8")
    print(f"\nListo: {len(species)} fichas, {len(chains)} líneas evolutivas -> {OUT} "
          f"({OUT.stat().st_size / 1e6:.1f} MB)")
    print("Cobertura de ubicaciones (formas con datos por juego):")
    for g in conf["games"]:
        n = cover.get(g["id"], 0)
        print(f"  {g['id']:28} {n if n else 'sin datos en PokéAPI'}")


if __name__ == "__main__":
    main()
