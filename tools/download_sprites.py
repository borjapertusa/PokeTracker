#!/usr/bin/env python3
"""Descarga los sprites de assets/data/pokedex.json a assets/sprites/ y
reescribe el JSON con rutas locales (assets/sprites/...).

- Es idempotente: salta lo ya descargado y las rutas que ya son locales.
- Si un sprite falla por red, conserva su URL (la app lo carga online) y se reintenta al repetir.
- Si el sprite no existe (404), se deja a null.
Uso:  python tools/download_sprites.py   (después de build_dataset.py)
"""
import json
import time
import urllib.error
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "assets" / "data" / "pokedex.json"
DEST = ROOT / "assets" / "sprites"
PREFIX = "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/"
KEYS = ("sprite", "shiny")


def local_name(url):
    rel = url[len(PREFIX):] if url.startswith(PREFIX) else url.split("://", 1)[1]
    return rel.replace("/", "_").replace("?", "_")


def download(url):
    """Devuelve 'ok', 'missing' (404) o 'error'."""
    dest = DEST / local_name(url)
    if dest.exists() and dest.stat().st_size > 0:
        return "ok"
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "pokedex-tracker"})
            with urllib.request.urlopen(req, timeout=30) as r:
                body = r.read()
            tmp = dest.with_suffix(dest.suffix + ".part")
            tmp.write_bytes(body)
            tmp.replace(dest)
            return "ok"
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return "missing"
            time.sleep(1.5 * (attempt + 1))
        except Exception:
            time.sleep(1.5 * (attempt + 1))
    return "error"


def main():
    data = json.loads(DATA.read_text("utf-8"))
    entries = [e for s in data["species"] for e in s["entries"]]
    urls = sorted({e[k] for e in entries for k in KEYS
                   if e.get(k) and e[k].startswith("http")})
    print(f"{len(urls)} sprites por descargar (los ya existentes se saltan)...")
    DEST.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(16) as ex:
        status = dict(zip(urls, ex.map(download, urls)))

    for e in entries:
        for k in KEYS:
            v = e.get(k)
            if v and v in status:
                if status[v] == "ok":
                    e[k] = f"assets/sprites/{local_name(v)}"
                elif status[v] == "missing":
                    e[k] = None
    DATA.write_text(json.dumps(data, ensure_ascii=False, separators=(",", ":")), "utf-8")

    n_ok = sum(v == "ok" for v in status.values())
    n_missing = sum(v == "missing" for v in status.values())
    n_err = sum(v == "error" for v in status.values())
    size = sum(f.stat().st_size for f in DEST.glob("*.png")) / 1e6
    print(f"Descargados/locales: {n_ok} | inexistentes: {n_missing} | con error: {n_err} | {size:.1f} MB")
    if n_err:
        print("Hubo errores de red: vuelve a ejecutar el script para reintentarlos.")


if __name__ == "__main__":
    main()
