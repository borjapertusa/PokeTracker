#!/usr/bin/env python3
"""Descarga renderizados Pokémon HOME para los sprites numéricos del tracker.

Uso desde la raíz del proyecto:
    python tools/download_home_sprites.py

Las imágenes se guardan en assets/sprites3d/. Las formas cosméticas con sufijo
(ej. 1012-artisan.png) se omiten para no asignarles por error el modelo base.
"""
from __future__ import annotations

import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEX = ROOT / "assets" / "data" / "pokedex.json"
DEST = ROOT / "assets" / "sprites3d"
BASE = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/home"
PATTERN = re.compile(r"^(shiny_)?(female_)?(\d+)\.png$")


def candidates(filename: str):
    match = PATTERN.match(filename)
    if not match:
        return
    shiny, female, number = match.groups()
    variant = "shiny-female" if shiny and female else "shiny" if shiny else "female" if female else None
    if variant:
        # Algunos mirrors históricos organizan shiny-female como carpeta anidada.
        yield f"{BASE}/{variant}/{number}.png"
        if shiny and female:
            yield f"{BASE}/shiny/female/{number}.png"
    else:
        yield f"{BASE}/{number}.png"


def main():
    data = json.loads(DEX.read_text(encoding="utf-8"))
    filenames = set()
    skipped = 0
    for species in data["species"]:
        for entry in species["entries"]:
            for field in ("sprite", "shiny"):
                value = entry.get(field)
                if not value:
                    continue
                filename = Path(value).name
                if PATTERN.match(filename):
                    filenames.add(filename)
                else:
                    skipped += 1

    DEST.mkdir(parents=True, exist_ok=True)
    downloaded = 0
    missing = 0
    for index, filename in enumerate(sorted(filenames), 1):
        target = DEST / filename
        if target.exists() and target.stat().st_size > 0:
            continue
        found = False
        for url in candidates(filename) or []:
            request = urllib.request.Request(url, headers={"User-Agent": "PokeTracker/1.0"})
            try:
                with urllib.request.urlopen(request, timeout=20) as response:
                    payload = response.read()
                if payload.startswith(b"\x89PNG\r\n\x1a\n"):
                    target.write_bytes(payload)
                    downloaded += 1
                    found = True
                    break
            except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError):
                continue
        if not found:
            missing += 1
        if index % 50 == 0:
            print(f"{index}/{len(filenames)} procesados...")
        time.sleep(0.03)

    print(f"Listo: {downloaded} descargados, {missing} no disponibles, {skipped} variantes omitidas.")
    print(f"Carpeta: {DEST}")


if __name__ == "__main__":
    main()
