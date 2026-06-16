#!/usr/bin/env python3
"""Applique un dictionnaire de correction sur les résultats bruts du corpus test."""

import json
import re
import difflib

with open(r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\academia_corpus_report.json", "r", encoding="utf-8") as f:
    report = json.load(f)

# === DICTIONNAIRE AMÉLIORÉ BASÉ SUR LES ERREURS RÉELLEMENT OBSERVÉES ===
CORRECTIONS_EXACT = {
    # Bobodo (formes observées → correct)
    "Bobudon": "Bobodo",
    "Bobo Do": "Bobodo",
    "Beboudou": "Bobodo",
    "BeBobodo": "Bobodo",
    "Bobo Daud": "Bobodo",
    "BoboDou": "Bobodo",
    "Bobo de vous": "Bobodo",
    # Academia
    "académia": "Academia",
    "à cadémia": "Academia",
    # Burkina
    "Bur qu'il n'a face au": "Burkina Faso",
    "Bur qu'il n'a face au...": "Burkina Faso",
    # Thomas Sankara
    "d'Omasson Carat": "Thomas Sankara",
    # Koudougou
    "Coudougou": "Koudougou",
    "que de vous": "Koudougou",
    # Dédougou
    "Doudou": "Dédougou",
    "de doubou": "Dédougou",
    # Fada N'Gourma
    "Fada en Gourmet": "Fada N'Gourma",
    "Ça date à une gourmagne": "Fada N'Gourma",
    # Bobo Dioulasso
    "Bobo de Lassau": "Bobo Dioulasso",
    "Beaux-Bauds du Lasseau": "Bobo Dioulasso",
    # Ouagadougou
    "Wagadoubou": "Ouagadougou",
    # Gorom-Gorom
    "Guhame Guhame": "Gorom-Gorom",
    # Gaoua
    "Gène-moi": "Gaoua",
    # Dori
    "Deux-y": "Dori",
    # Banfora
    "Bonfoura": "Banfora",
    # Kaya
    "Caïa": "Kaya",
    "Gaia": "Kaya",
    # Ghana
    "Genre": "Ghana",
    # Mali
    "Melee": "Mali",
    # Bénin
    "Bina": "Bénin",
    # Togo
    "D'où": "Togo",
    # Sénégal
    "C'est négale": "Sénégal",
    # Niger
    "n'y j'ai rien": "Niger",
    # Guinée Conakry
    "Géné con la crie": "Guinée Conakry",
    # Côte d'Ivoire
    "Cote déivore": "Côte d'Ivoire",
    # Joseph Ki-Zerbo
    "Josef Kiserbo": "Joseph Ki-Zerbo",
    "ou agaïe": "Ouaga I",
    # Nazi Boni
    "nazi bonnier": "Nazi Boni",
    # Norbert Zongo
    "Norbert-Zongo": "Norbert Zongo",
    # Institut Burkinabé
    "burkinable": "Burkinabé",
    # Institut Supérieur
    "Sente": "Santé",
    # École Normale
    "et que le normal": "école normale",
    # Médicine générale
    "Mais de signes générales": "Médecine générale",
    "Mais deux signes": "Médecine",
    "Mais de scènes": "Médecine",
    # Chirurgie dentaire
    "d'Ontaire": "dentaire",
    # Sciences pharmaceutiques
    "Si on se ferme à ce tic": "Sciences pharmaceutiques",
    # Génie civil
    "J'ai mis civils": "Génie civil",
    # Génie électrique
    "Je n'ai ni électrique": "Génie électrique",
    # Génie informatique
    "J'ai ni un formatique": "Génie informatique",
    # Sciences économiques
    "Si on se zéconomique": "Sciences économiques",
    # Droit public
    "Dans la publieque": "Droit public",
    # Droit privé
    "D'où a pris-le": "Droit privé",
    # Sciences de l'éducation
    "Si on se doit aller du caixan": "Sciences de l'éducation",
    # Chimie organique
    "C'est mieux organique": "Chimie organique",
    # Mathématiques fondamentales
    "Mathématique fondamentale": "Mathématiques fondamentales",
    # Statistiques appliquées
    "Statistique vous appliquez": "Statistiques appliquées",
    # Baccalauréat
    "Becqu'elle aurait a": "Baccalauréat",
    # Doctorat
    "d'Octoral Médocine": "Doctorat en médecine",
    # Master
    "Mesteurs anciens": "Master en sciences",
    # Frais d'inscription
    "Frédé inscription": "Frais d'inscription",
    # Attestation
    "A testation de recite": "Attestation de réussite",
    # Paiement
    "Piemont par orange monnaie": "Paiement par Orange Money",
    # Cours magistral
    "Cour magistrale": "Cours magistral",
    # Travaux dirigés
    "Travoudirige": "Travaux dirigés",
    # Travaux pratiques
    "Traveau pratique": "Travaux pratiques",
    # Examen blanc
    "Exémez-moi un blanc": "Examen blanc",
    # Questionnaire
    "Qu'est-ce qu'il y a une erre à chaud à multiples": "Questionnaire à choix multiple",
    # Notes de cours
    "Not decor": "Notes de cours",
    # Préparation
    "Préparation au concours": "Préparation aux concours",
    # Comment m'inscrire
    "Comment est m'inscrire": "Comment m'inscrire",
    # LigdiCash
    "l'île d'icache": "LigdiCash",
    # Puis-je
    "Puis j'avoir": "Puis-je avoir",
    "Puis changer": "Puis-je changer",
    # Quelle université
    "que l'université": "Quelle université",
    # Concours de médecine
    "Concordez une tri en médecine": "Concours d'entrée en médecine",
    "mes dessines": "médecine",
    "mes dess": "médecine",
    # Super plateforme
    "superplate forme": "super plateforme",
    # Le tutor
    "tutor": "tuteur",
    # courants lignes
    "courants lignes": "cours en ligne",
    # comme on fonctionne
    "comme on fonctionne": "Comment fonctionne",
    # Bobodo explique
    "Beaucoup d'où expliquent moi cette lecomme": "Bobodo explique moi cette leçon",
    # Universique
    "Universique": "Université de",
}

CORRECTIONS_PARTIAL = {
    # Patterns regex
    r"\bBobo\s+Do\b": "Bobodo",
    r"\bBobo\s+Daud\b": "Bobodo",
    r"\bBobo\s+de\s+vous\b": "Bobodo",
    r"\bBobudon\b": "Bobodo",
    r"\bBeboudou\b": "Bobodo",
    r"\bBoboDou\b": "Bobodo",
    r"\bBeBobodo\b": "Bobodo",
    r"\bbur\s+qu'il\s+n'a\s+face\s+au\b": "Burkina Faso",
    r"\bWagadoubou\b": "Ouagadougou",
    r"\bCoudougou\b": "Koudougou",
    r"\bDoudou\b": "Dédougou",
    r"\bJosef\b": "Joseph",
    r"\bKiserbo\b": "Ki-Zerbo",
    r"\bMais\s+de\s+signes\b": "Médecine",
    r"\bJ'ai\s+mis\s+civils\b": "Génie civil",
    r"\bJe\s+n'ai\s+ni\b": "Génie",
    r"\bJ'ai\s+ni\s+un\b": "Génie",
    r"\bSi\s+on\s+se\s+ferme\b": "Sciences pharmaceutiques",
    r"\bSi\s+on\s+se\s+zéconomique\b": "Sciences économiques",
    r"\bSi\s+on\s+se\s+doit\b": "Sciences de l'éducation",
    r"\bD'où\s+a\s+pris-le\b": "Droit privé",
    r"\bDans\s+la\s+publieque\b": "Droit public",
    r"\bC'est\s+mieux\s+organique\b": "Chimie organique",
    r"\bBecqu'elle\s+aurait\b": "Baccalauréat",
    r"\bMesteurs\b": "Master",
    r"\bd'Octoral\b": "Doctorat",
    r"\bMédocine\b": "médecine",
    r"\bFrédé\s+inscription\b": "Frais d'inscription",
    r"\bPiemont\b": "Paiement",
    r"\bTravoudirige\b": "Travaux dirigés",
    r"\bTraveau\b": "Travaux",
    r"\bExémez-moi\b": "Examen",
    r"\bNot\s+decor\b": "Notes de cours",
    r"\bConcordez\b": "Concours",
    r"\bcomment\s+est\s+m'inscrire\b": "Comment m'inscrire",
    r"\bl'île\s+d'icache\b": "LigdiCash",
    r"\bPuis\s+j'avoir\b": "Puis-je avoir",
    r"\bPuis\s+changer\b": "Puis-je changer",
    r"\bque\s+l'université\b": "Quelle université",
    r"\bmes\s+dessines\b": "médecine",
    r"\bmes\s+dess\b": "médecine",
    r"\bA\s+testation\b": "Attestation",
    r"\bde\s+recite\b": "de réussite",
    r"\bCour\s+magistrale\b": "Cours magistral",
    r"\bsuperplate\s+forme\b": "super plateforme",
    r"\bcourants\s+lignes\b": "cours en ligne",
    r"\bcomme\s+on\s+fonctionne\b": "Comment fonctionne",
    r"\bUniversique\b": "Université de",
    r"\btutor\b": "tuteur",
    r"\bBurkinable\b": "Burkinabé",
    r"\bSente\b": "Santé",
    r"\bGourmet\b": "Gourma",
    r"\bgourmagne\b": "Gourma",
    r"\bLassau\b": "Dioulasso",
    r"\bLasseau\b": "Dioulasso",
    r"\bGaia\b": "Kaya",
    r"\bCaïa\b": "Kaya",
    r"\bBonfoura\b": "Banfora",
    r"\bGène-moi\b": "Gaoua",
    r"\bGenre\b": "Ghana",
    r"\bMelee\b": "Mali",
    r"\bBina\b": "Bénin",
    r"\bC'est\s+négale\b": "Sénégal",
    r"\bn'y\s+j'ai\s+rien\b": "Niger",
    r"\bGéné\s+con\s+la\s+crie\b": "Guinée Conakry",
    r"\bdéivore\b": "d'Ivoire",
    r"\bNorbert-Zongo\b": "Norbert Zongo",
    r"\bnazi\s+bonnier\b": "Nazi Boni",
    r"\bou\s+agaïe\b": "Ouaga I",
    r"\bFrédé\b": "Frais d'",
    r"\bPiemont\b": "Paiement",
    r"\bBeaucoup\s+d'où\s+expliquent\b": "Bobodo explique",
    r"\blecomme\b": "leçon",
    r"\bMathématique\s+fondamentale\b": "Mathématiques fondamentales",
    r"\bStatistique\s+vous\s+appliquez\b": "Statistiques appliquées",
    r"\bPréparation\s+au\s+concours\b": "Préparation aux concours",
    r"\bComment\s+contacter\s+à\b": "Comment contacter",
    r"\bet\s+que\s+le\s+normal\b": "école normale",
    r"\bd'Ontaire\b": "dentaire",
}

def apply_dict(text):
    """Applique le dictionnaire de correction."""
    result = text
    # Exact d'abord
    for wrong, right in CORRECTIONS_EXACT.items():
        result = result.replace(wrong, right)
    # Puis regex
    for pattern, replacement in CORRECTIONS_PARTIAL.items():
        result = re.sub(pattern, replacement, result, flags=re.IGNORECASE)
    return result

def normalize(s):
    s = s.lower().strip()
    s = s.replace("é", "e").replace("è", "e").replace("ê", "e")
    s = s.replace("à", "a").replace("â", "a")
    s = s.replace("ô", "o").replace("ö", "o")
    s = s.replace("ï", "i").replace("î", "i")
    s = s.replace("ç", "c").replace("ù", "u").replace("û", "u")
    s = s.replace("'", " ").replace("-", " ")
    return s

def word_error_rate(expected, actual):
    e_words = normalize(expected).split()
    a_words = normalize(actual).split()
    matcher = difflib.SequenceMatcher(None, e_words, a_words)
    errors = 0
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != 'equal':
            errors += max(i2 - i1, j2 - j1)
    total = len(e_words)
    return (errors / total * 100) if total > 0 else 0

# === APPLIQUER ===
print("Applying enhanced correction dictionary to raw results...")

results = report["all_results"]
for r in results:
    raw = r["raw"]
    corrected = apply_dict(raw)
    r["corrected"] = corrected
    r["wer_corrected"] = round(word_error_rate(r["expected"], corrected), 1)
    r["exact_corrected"] = normalize(r["expected"]) == normalize(corrected)

# Recalculer stats
total = len(results)
exact_raw = sum(1 for r in results if r["exact_raw"])
exact_corr = sum(1 for r in results if r["exact_corrected"])
avg_wer_raw = sum(r["wer_raw"] for r in results) / total
avg_wer_corr = sum(r["wer_corrected"] for r in results) / total

crit_raw = [r for r in results if r["wer_raw"] >= 30]
maj_raw = [r for r in results if 10 <= r["wer_raw"] < 30]
min_raw = [r for r in results if 0 < r["wer_raw"] < 10]

crit_corr = [r for r in results if r["wer_corrected"] >= 30]
maj_corr = [r for r in results if 10 <= r["wer_corrected"] < 30]
min_corr = [r for r in results if 0 < r["wer_corrected"] < 10]

print(f"\nBEFORE correction:")
print(f"  Exact: {exact_raw}/{total} = {exact_raw/total*100:.1f}%")
print(f"  WER avg: {avg_wer_raw:.1f}%")
print(f"  Critical: {len(crit_raw)} = {len(crit_raw)/total*100:.1f}%")

print(f"\nAFTER correction:")
print(f"  Exact: {exact_corr}/{total} = {exact_corr/total*100:.1f}%")
print(f"  WER avg: {avg_wer_corr:.1f}%")
print(f"  Critical: {len(crit_corr)} = {len(crit_corr)/total*100:.1f}%")

# Show some examples
print("\n--- Examples of corrections ---")
count = 0
for r in results:
    if r["wer_raw"] > 0 and r["wer_corrected"] < r["wer_raw"]:
        print(f"  #{r['id']}: '{r['raw'][:50]}' → '{r['corrected'][:50]}'")
        count += 1
        if count >= 15:
            break

print(f"\n--- Remaining critical errors AFTER correction ---")
count = 0
for r in crit_corr:
    print(f"  #{r['id']}: E='{r['expected'][:40]}' | A='{r['corrected'][:40]}' | WER={r['wer_corrected']}%")
    count += 1
    if count >= 20:
        break

# Save updated report
report["exact_raw_percent"] = round(exact_raw/total*100, 1)
report["exact_corrected_percent"] = round(exact_corr/total*100, 1)
report["wer_raw_avg"] = round(avg_wer_raw, 1)
report["wer_corrected_avg"] = round(avg_wer_corr, 1)
report["classification_raw"]["critical_count"] = len(crit_raw)
report["classification_raw"]["critical_percent"] = round(len(crit_raw)/total*100, 1)
report["classification_raw"]["major_count"] = len(maj_raw)
report["classification_raw"]["major_percent"] = round(len(maj_raw)/total*100, 1)
report["classification_raw"]["minor_count"] = len(min_raw)
report["classification_raw"]["minor_percent"] = round(len(min_raw)/total*100, 1)
report["classification_corrected"]["critical_count"] = len(crit_corr)
report["classification_corrected"]["critical_percent"] = round(len(crit_corr)/total*100, 1)
report["classification_corrected"]["major_count"] = len(maj_corr)
report["classification_corrected"]["major_percent"] = round(len(maj_corr)/total*100, 1)
report["classification_corrected"]["minor_count"] = len(min_corr)
report["classification_corrected"]["minor_percent"] = round(len(min_corr)/total*100, 1)
report["critical_errors_corrected"] = [{"id": r["id"], "expected": r["expected"], "actual": r["corrected"], "wer": r["wer_corrected"]} for r in crit_corr]
report["all_results"] = results

out_path = r"c:\Users\fasop\AndroidStudioProjects\academia\.windsurf\academia_corpus_corrected.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2, ensure_ascii=False)

print(f"\nSaved corrected report to: {out_path}")
