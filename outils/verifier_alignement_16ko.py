#!/usr/bin/env python3
"""Vérifie que les bibliothèques natives d'un APK/AAB tiennent la page de 16 Ko.

    python outils/verifier_alignement_16ko.py academia_app/build/app/outputs/bundle/release/app-release.aab
    python outils/verifier_alignement_16ko.py academia_app/build/app/outputs/flutter-apk/app-release.apk

POURQUOI CE SCRIPT EXISTE. `ar_flutter_plugin` a dû être retiré de ce projet
parce que ses `.so` n'étaient pas alignés sur 16 Ko — exigence de Play depuis
Android 15. Le défaut ne se voit ni à la compilation ni à l'exécution sur un
appareil actuel : il se voit au dépôt, quand Play refuse le paquet. Un contrôle
absent ici coûte un aller-retour complet.

CE QU'ON MESURE, ET LA BÊTISE QUE J'AI FAILLI COMMETTRE. Ma première version
lisait la position de chaque `.so` DANS L'ARCHIVE et vérifiait qu'elle était un
multiple de 16 384. Sur le bundle du 09/09, elle a déclaré **les cinquante
bibliothèques non alignées** — alors que cette application est publiée. Deux
choses distinctes se confondaient :

  * l'alignement DANS L'ARCHIVE (zipalign) : il ne concerne que l'APK, et pour
    un bundle c'est Play qui le refait en produisant les APK d'installation.
    Le mesurer sur un `.aab` ne veut rien dire ;
  * l'alignement des SEGMENTS ELF (`p_align` des segments PT_LOAD) : c'est une
    propriété de la bibliothèque elle-même, décidée à sa compilation. C'est
    CELLE-LÀ qu'Android 15 exige à 16 Ko, et elle se lit aussi bien dans un APK
    que dans un AAB.

On lit donc les en-têtes de programme de chaque `.so`. Une bibliothèque dont un
segment chargeable a `p_align` inférieur à 16384 ne pourra pas être mappée sur
un appareil à pages de 16 Ko.

Sortie : 0 si tout tient, 1 sinon.
"""

from __future__ import annotations

import io
import struct
import sys
import zipfile
from pathlib import Path

PAGE = 16 * 1024
PT_LOAD = 1

# LA RÈGLE NE VAUT QUE POUR LE 64 BITS, ET C'EST LA DEUXIÈME FOIS QUE CE
# SCRIPT A FAILLI MENTIR. Sur le bundle du 09/09, la version qui ne triait pas
# par architecture annonçait **20 bibliothèques fautives**. Ventilées :
#
#     arm64-v8a     21 conformes,  0 sous 16 Ko
#     x86_64        21 conformes,  0 sous 16 Ko
#     armeabi-v7a    9 conformes, 20 sous 16 Ko
#
# Les vingt étaient TOUTES en `armeabi-v7a`. Les pages de 16 Ko sont une
# affaire d'appareils 64 bits ; le 32 bits n'est pas concerné, et ffmpeg,
# WebRTC et libc++ y resteront en 4 Ko sans que Play s'en émeuve.
ABI_64 = {"arm64-v8a", "x86_64"}


def alignements_pt_load(octets: bytes) -> list[int]:
    """Les `p_align` des segments chargeables d'un ELF, ou [] si illisible."""
    if len(octets) < 64 or octets[:4] != b"\x7fELF":
        return []
    classe = octets[4]          # 1 = 32 bits, 2 = 64 bits
    petit_boutien = octets[5] == 1
    e = "<" if petit_boutien else ">"

    if classe == 1:
        (phoff,) = struct.unpack_from(e + "I", octets, 0x1C)
        (phentsize,) = struct.unpack_from(e + "H", octets, 0x2A)
        (phnum,) = struct.unpack_from(e + "H", octets, 0x2C)
        decalage_align = 28
        format_align = e + "I"
    elif classe == 2:
        (phoff,) = struct.unpack_from(e + "Q", octets, 0x20)
        (phentsize,) = struct.unpack_from(e + "H", octets, 0x36)
        (phnum,) = struct.unpack_from(e + "H", octets, 0x38)
        decalage_align = 48
        format_align = e + "Q"
    else:
        return []

    aligns: list[int] = []
    for i in range(phnum):
        base = phoff + i * phentsize
        if base + phentsize > len(octets):
            break
        (p_type,) = struct.unpack_from(e + "I", octets, base)
        if p_type != PT_LOAD:
            continue
        (p_align,) = struct.unpack_from(format_align, octets, base + decalage_align)
        aligns.append(p_align)
    return aligns


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    chemin = Path(sys.argv[1])
    if not chemin.exists():
        print(f"Introuvable : {chemin}", file=sys.stderr)
        return 2

    fautes: list[str] = []
    illisibles: list[str] = []
    par_bibliotheque: dict[str, int] = {}

    with zipfile.ZipFile(chemin) as z:
        natifs = [i for i in z.infolist() if i.filename.endswith(".so")]
        if not natifs:
            print("Aucune bibliothèque native dans ce paquet.")
            return 0

        ignorees_32 = 0
        for info in sorted(natifs, key=lambda i: i.filename):
            parties = info.filename.split("/")
            abi = next((p for p in parties if p in ABI_64
                        or p in ("armeabi-v7a", "x86", "armeabi")), "?")
            if abi not in ABI_64:
                ignorees_32 += 1
                continue

            # L'en-tête ELF et la table des programmes tiennent dans les
            # premiers kilo-octets : inutile de décompresser 8 Mo pour lire 64
            # octets utiles.
            with z.open(info) as f:
                tete = f.read(256 * 1024)
            aligns = alignements_pt_load(tete)
            nom = f"{abi}/{Path(info.filename).name}"
            if not aligns:
                illisibles.append(info.filename)
                continue
            mini = min(aligns)
            par_bibliotheque[nom] = mini
            if mini < PAGE:
                fautes.append(f"{info.filename} : p_align {mini} "
                              f"({mini // 1024} Ko, 16 Ko exigés)")

    if fautes:
        largeur = max(len(n) for n in par_bibliotheque)
        for nom in sorted(par_bibliotheque):
            a = par_bibliotheque[nom]
            if a < PAGE:
                print(f"  {nom:<{largeur}}  p_align {a:>6} "
                      f"({a // 1024:>2} Ko)  TROP PETIT")

    print(f"{len(par_bibliotheque)} bibliothèque(s) 64 bits examinée(s) "
          f"({', '.join(sorted(ABI_64))}).")
    print(f"{ignorees_32} bibliothèque(s) 32 bits ignorée(s) : la page de "
          f"16 Ko ne les concerne pas.")
    if illisibles:
        print(f"{len(illisibles)} illisible(s) (en-tête ELF absent ou tronqué) :")
        for i in illisibles:
            print(f"  · {i}")

    if fautes:
        print(f"\n{len(fautes)} SEGMENT(S) SOUS 16 Ko — Play refusera ce paquet :")
        for f in fautes:
            print(f"  - {f}")
        return 1

    print("Toutes les bibliothèques natives tiennent la page de 16 Ko.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
