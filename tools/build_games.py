#!/usr/bin/env python3
"""Genera assets/data/games.json: qué especies y formas cuentan en la Pokédex de cada juego.

Requiere haber ejecutado build_dataset.py (versión con datos de forma).
Fuente de las listas, por orden de prioridad:
  1) tools/dex_lists/<id>.txt   (lista manual, ver LEEME.txt)
  2) PokéAPI (pokédex regionales)
  3) Serebii (solo Leyendas Z-A y su DLC, si PokéAPI aún no los tiene)
Las formas se filtran según el juego (Mega, Gigamax, regionales, formas que aún no existían...).
Uso:  python tools/build_games.py
"""
import hashlib
import json
import re
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

import build_dataset as bd  # reutiliza la caché y el cliente de PokéAPI

ROOT = bd.ROOT
DATA = bd.OUT
OUT = ROOT / "assets" / "data" / "games.json"
TOOLS = ROOT / "tools"
CONF = TOOLS / "games_config.json"
MANUAL = TOOLS / "dex_lists"
OVERRIDES = TOOLS / "dex_overrides.json"
CACHE = bd.CACHE
API = bd.API
UA = "Mozilla/5.0 (compatible; pokedex-tracker)"
REGIONS = {"alola", "galar", "hisui", "paldea"}


def fetch_text(url):
    CACHE.mkdir(parents=True, exist_ok=True)
    f = CACHE / ("page_" + hashlib.md5(url.encode()).hexdigest() + ".html")
    if f.exists():
        return f.read_text("utf-8", errors="replace")
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                txt = r.read().decode("utf-8", errors="replace")
            f.write_text(txt, "utf-8")
            return txt
        except Exception:
            time.sleep(2 * (attempt + 1))
    return None


def parse_serebii(html):
    """Números nacionales, en orden, de las imágenes de la tabla de la Pokédex."""
    seen, out = set(), []
    for n in re.findall(r"legendsz-a/pokemon/small/(\d{1,4})", html):
        n = int(n)
        if n not in seen:
            seen.add(n)
            out.append(n)
    return out


def token_to_dex(tok, by_name, by_es):
    tok = tok.strip()
    if tok.isdigit():
        return int(tok)
    low = tok.lower()
    return by_name.get(low.replace(" ", "-")) or by_es.get(low)


def resolve_dex(game, ctx, available):
    """Devuelve (pares[(dex_nacional, nº_regional)], origen) o (None, motivo)."""
    by_name, by_es, all_dex = ctx
    manual = MANUAL / f"{game['id']}.txt"
    if manual.exists():
        toks = [ln.split(";")[0].strip() for ln in manual.read_text("utf-8").splitlines()]
        dexes, bad = [], []
        for t in filter(None, toks):
            d = token_to_dex(t, by_name, by_es)
            (dexes if d else bad).append(d or t)
        if bad:
            print(f"   aviso: {len(bad)} nombres no reconocidos en {manual.name}: {bad[:5]}")
        return [(d, i + 1) for i, d in enumerate(dexes)], "lista manual"

    src = game["dex"]
    if "national_max" in src:
        return [(d, d) for d in sorted(all_dex) if d <= src["national_max"]], "nacional"

    names = [n for n in src.get("pokeapi", []) if n in available]
    if names:
        found = []
        for n in names:
            dx = bd.get(f"{API}/pokedex/{n}")
            for pe in dx["pokemon_entries"]:
                d = by_name.get(pe["pokemon_species"]["name"])
                if d:
                    found.append((d, pe["entry_number"]))
        if len(names) == 1:
            return sorted(found, key=lambda x: x[1]), f"PokéAPI ({names[0]})"
        by_dex = {}
        for d, _ in found:
            by_dex.setdefault(d, d)
        return [(d, d) for d in sorted(by_dex)], f"PokéAPI ({'+'.join(names)})"

    if src.get("serebii"):
        html = fetch_text(src["serebii"])
        if html:
            nums = [n for n in parse_serebii(html) if n in all_dex]
            if nums:
                return [(d, i + 1) for i, d in enumerate(nums)], "Serebii"
        return None, "PokéAPI no la tiene y no se pudo leer Serebii"
    return None, "no hay pokédex con ese nombre en PokéAPI"


def allowed(e, g, order, vg):
    kind = e.get("kind", "base")
    if kind == "base":
        return True
    if vg.get(e.get("intro"), 100) > order:  # la forma aún no existía en ese juego
        return False
    if kind == "mega":
        return bool(g.get("mega"))
    if kind == "gmax":
        return bool(g.get("gmax"))
    if kind == "regional":
        return bool(REGIONS & set(e["id"].split("-")) & set(g.get("regional", [])))
    return not e.get("battleOnly")  # formas de combate no se registran en la Pokédex


def main():
    conf = json.loads(CONF.read_text("utf-8"))
    data = json.loads(DATA.read_text("utf-8"))
    if not any("intro" in e for s in data["species"] for e in s["entries"]):
        raise SystemExit("pokedex.json no tiene datos de forma. Ejecuta primero:\n"
                         "  python tools/build_dataset.py\n  python tools/download_sprites.py")
    vg = conf["vg_order"]
    by_dex = {s["dex"]: s for s in data["species"]}
    ctx = ({s["name"]: s["dex"] for s in data["species"]},
           {s["nameEs"].lower(): s["dex"] for s in data["species"]},
           set(by_dex))
    available = {d["name"] for d in bd.get(f"{API}/pokedex?limit=200")["results"]}
    overrides = json.loads(OVERRIDES.read_text("utf-8")) if OVERRIDES.exists() else {}

    games, missing = [], []
    print(f"{'juego':34} {'especies':>8} {'entradas':>8}  origen")
    for g in conf["games"]:
        pairs, how = resolve_dex(g, ctx, available)
        if pairs is None:
            print(f"{g['id']:34} {'-':>8} {'-':>8}  SIN DATOS: {how}")
            missing.append(g["id"])
            continue
        order = vg.get(g["vg"], 100)
        ov = overrides.get(g["id"], {})
        exclude, include = set(ov.get("exclude", [])), set(ov.get("include", []))
        species, seen, n_entries = [], set(), 0
        for dex, no in pairs:
            sp = by_dex.get(dex)
            if sp is None or dex in seen:
                continue
            seen.add(dex)
            ids = []
            for e in sp["entries"]:
                if e["id"] in exclude:
                    continue
                if e["id"] not in include and not allowed(e, g, order, vg):
                    continue
                if g["gen"] < 4 and e["gender"] == "female":  # sin diferencias de género visibles
                    continue
                ids.append(e["id"])
            if ids:
                species.append({"d": dex, "n": no, "e": ids})
                n_entries += len(ids)
        exp = g.get("expected")
        note = f"  (esperadas {exp}: revisa la lista)" if exp and len(species) != exp else ""
        print(f"{g['id']:34} {len(species):>8} {n_entries:>8}  {how}{note}")
        games.append({"id": g["id"], "name": g["name"], "gen": g["gen"],
                      "shiny": bool(g["shiny"]), "genders": g["gen"] >= 4,
                      "species": species})

    payload = {"generatedAt": datetime.now(timezone.utc).isoformat(), "games": games}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), "utf-8")
    print(f"\nListo: {len(games)} juegos -> {OUT}")
    if missing:
        print("Sin datos:", ", ".join(missing), "(mira tools/dex_lists/LEEME.txt)")


if __name__ == "__main__":
    main()
