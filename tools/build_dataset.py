#!/usr/bin/env python3
"""Genera assets/data/pokedex.json desde PokéAPI.

Cada "entrada" es la unidad que se marca en la app: especie + forma + género.
Las respuestas de la API se guardan en tools/.cache, así que repetir el script es rápido.
Uso:  python tools/build_dataset.py
"""
import hashlib
import json
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

API = "https://pokeapi.co/api/v2"
ROOT = Path(__file__).resolve().parent.parent
CACHE = ROOT / "tools" / ".cache"
OUT = ROOT / "assets" / "data" / "pokedex.json"
ROMAN = {"i": 1, "ii": 2, "iii": 3, "iv": 4, "v": 5, "vi": 6, "vii": 7, "viii": 8, "ix": 9}
REGIONAL = {"alola", "galar", "hisui", "paldea"}


def get(url):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / (hashlib.md5(url.encode()).hexdigest() + ".json")
    if f.exists():
        return json.loads(f.read_text("utf-8"))
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "pokedex-tracker"})
            with urllib.request.urlopen(req, timeout=30) as r:
                data = json.load(r)
            f.write_text(json.dumps(data), "utf-8")
            return data
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    raise RuntimeError(f"No se pudo descargar {url}")


def pretty(s):
    return s.replace("-", " ").title()


def kind_of(pk_name, sp_name, is_default):
    if is_default:
        return "base"
    parts = pk_name[len(sp_name) + 1:].split("-")
    if "mega" in parts:
        return "mega"
    if "gmax" in parts:
        return "gmax"
    if parts[0] in REGIONAL:
        return "regional"
    return "other"


def vg_of(form):
    """Grupo de versiones en el que se introdujo la forma (p. ej. 'x-y')."""
    return (form.get("version_group") or {}).get("name")


def entry(id_, label, kind, gender, normal, shiny, battle_only, intro=None):
    return {"id": id_, "label": label, "kind": kind, "gender": gender,
            "sprite": normal, "shiny": shiny, "battleOnly": bool(battle_only),
            "intro": intro}


def name_es(sp):
    for n in sp["names"]:
        if n["language"]["name"] == "es":
            return n["name"]
    return pretty(sp["name"])


def process_species(ref):
    sp = get(ref["url"])
    entries = []
    for v in sp["varieties"]:
        pk = get(v["pokemon"]["url"])
        spr = pk["sprites"]
        kind = kind_of(pk["name"], sp["name"], v["is_default"])
        forms = [get(f["url"]) for f in pk["forms"]]

        if len(forms) > 1:  # formas cosméticas: Unown, Vivillon, Alcremie, Flabébé...
            for fm in forms:
                fs = fm["sprites"]
                label = pretty(fm["form_name"]) if fm.get("form_name") else "Base"
                entries.append(entry(
                    fm["name"], label, "cosmetic", "none",
                    fs.get("front_default") or spr.get("front_default"),
                    fs.get("front_shiny") or spr.get("front_shiny"),
                    fm.get("is_battle_only"), vg_of(fm)))
            continue

        label = "Base" if v["is_default"] else pretty(pk["name"][len(sp["name"]) + 1:])
        battle_only = forms[0].get("is_battle_only") if forms else False
        intro = vg_of(forms[0]) if forms else None
        female = spr.get("front_female")
        if sp.get("has_gender_differences") and female:  # diferencia visual de género
            entries.append(entry(pk["name"], label, kind, "male",
                                 spr.get("front_default"), spr.get("front_shiny"), battle_only, intro))
            entries.append(entry(pk["name"] + "-f", label, kind, "female",
                                 female, spr.get("front_shiny_female"), battle_only, intro))
        else:
            entries.append(entry(pk["name"], label, kind, "none",
                                 spr.get("front_default"), spr.get("front_shiny"), battle_only, intro))

    gen = ROMAN[sp["generation"]["name"].split("-")[1]]
    return {"dex": sp["id"], "name": sp["name"], "nameEs": name_es(sp),
            "gen": gen, "entries": entries}


def main():
    refs = get(f"{API}/pokemon-species?limit=3000")["results"]
    print(f"{len(refs)} especies, descargando (puede tardar unos minutos)...")
    with ThreadPoolExecutor(16) as ex:
        species = list(ex.map(process_species, refs))
    species.sort(key=lambda s: s["dex"])
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = {"generatedAt": datetime.now(timezone.utc).isoformat(), "species": species}
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), "utf-8")
    total = sum(len(s["entries"]) for s in species)
    print(f"Listo: {len(species)} especies, {total} entradas -> {OUT}")


if __name__ == "__main__":
    main()
