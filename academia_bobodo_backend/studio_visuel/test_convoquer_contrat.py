#!/usr/bin/env python3
"""Le contrat entre `composer_scene` et `convoquer`, verifiable SANS Blender.

POURQUOI CE FICHIER EXISTE (05/09/2026)
`_g_convoquer` passait `journal=j`, un objet `Journal`. `convoquer` appelle ce
parametre : `journal(f"...")`. `Journal` n'a que `fait()` et `degrade()` — donc
`TypeError: 'Journal' object is not callable`, A CHAQUE APPEL, reussi ou non.

Le geste passait donc systematiquement pour un echec. Mesure sur le travail
df934af7 (« le volcan ») : les cinq scenes employaient `convoquer`, les cinq
sont tombees sur le texte de secours — qui ne bouge pas — et la capsule a ete
refusee pour « image figee 27.31 s ». Le verbe etait juste, l'index etait
juste, le prompt etait juste. Une ligne separait les deux.

Ce defaut ne se voyait ni a la compilation, ni aux tests Deno, ni au banc de
l'index : il fallait un pod GPU, dix minutes et 0,15 $ pour l'apprendre — et
encore, sous la forme d'un message qui parlait d'autre chose.

Usage :  python test_convoquer_contrat.py
"""
import sys
from pathlib import Path

ICI = Path(__file__).parent
sys.path.insert(0, str(ICI))


def charger_journal():
    """Recupere la classe `Journal` sans importer Blender.

    `composer_scene` importe `academia3d`, qui importe `bpy` : indisponible
    hors de Blender. On execute donc la seule portion utile du fichier.
    """
    src = (ICI / "composer_scene.py").read_text(encoding="utf-8")
    debut = src.index("class Journal:")
    fin = src.index("# ── Les gestes executables")
    ns: dict = {}
    exec(src[debut:fin], ns)  # noqa: S102
    return ns["Journal"]


def essais() -> int:
    echecs = 0
    Journal = charger_journal()
    j = Journal()

    # 1. Ce que `composer_scene` passe doit etre APPELABLE.
    src = (ICI / "composer_scene.py").read_text(encoding="utf-8")
    if "journal=j)" in src:
        echecs += 1
        print("  ECHEC  _g_convoquer passe l'objet Journal — il sera appele\n"
              "         comme une fonction et levera TypeError")
    if "journal=j.fait" not in src:
        echecs += 1
        print("  ECHEC  _g_convoquer ne passe pas une methode appelable")

    # 2. La methode passee doit reellement accepter un message et le retenir.
    try:
        j.fait("convoquer: « volcan » -> a091df40 (by) — a volcano with fire")
    except Exception as e:  # noqa: BLE001
        echecs += 1
        print(f"  ECHEC  j.fait n'accepte pas un message : {e}")
    if len(j.faits) != 1:
        echecs += 1
        print(f"  ECHEC  le message n'a pas ete retenu ({len(j.faits)} faits)")

    # 3. `convoquer` doit rendre None — pas lever — sur un terme inconnu, et
    #    doit pouvoir journaliser au passage.
    import convoquer as c
    recu: list[str] = []
    resultat = c.convoquer("la sociologie", journal=recu.append)
    if resultat is not None:
        echecs += 1
        print("  ECHEC  un terme absent devrait rendre None")
    if not recu:
        echecs += 1
        print("  ECHEC  un terme absent devrait etre journalise")

    # 4. Un terme connu doit etre trouve dans l'index, avec son chemin.
    for terme in ("volcan", "cerveau", "coeur"):
        candidats = c.chercher(terme)
        if not candidats:
            echecs += 1
            print(f"  ECHEC  « {terme} » introuvable dans l'index")
        elif not candidats[0].get("chemin"):
            echecs += 1
            print(f"  ECHEC  « {terme} » sans chemin : 60 Mo par pod")

    # 5. Les faits doivent REMONTER, sinon le pod meurt avec sa preuve.
    gen = (ICI / "generateur_scenes.py").read_text(encoding="utf-8")
    exe = (ICI / "executer_capsule.py").read_text(encoding="utf-8")
    if 'print(f"FAIT ' not in gen:
        echecs += 1
        print("  ECHEC  generateur_scenes n'imprime pas les faits")
    if '"FAIT "' not in exe:
        echecs += 1
        print("  ECHEC  executer_capsule ne reprend pas les lignes FAIT")
    if "capsules/refuses/" not in exe:
        echecs += 1
        print("  ECHEC  le depot des refus n'est pas sous « capsules/ » —\n"
              "         la policy RLS du bucket le rejettera en silence")
    return echecs


if __name__ == "__main__":
    n = essais()
    print("TOUT PASSE" if n == 0 else f"{n} ECHEC(S)")
    sys.exit(1 if n else 0)
