#!/usr/bin/env python3
"""
Benchmark Tiny sur corpus Academia (100 expressions).
Aucun impact sur le service en cours.
"""

import os
import sys
import time
import json
import subprocess
import difflib
from pathlib import Path

OUT_DIR = "/tmp/tiny_academia_benchmark"
os.makedirs(OUT_DIR, exist_ok=True)

# === CORPUS 100 EXPRESSIONS ===
CORPUS = [
    # Catégorie A — Termes Bobodo & Academia (1-10)
    ("Bonjour Bobodo", "bobodo"),
    ("Je veux parler a Bobodo", "bobodo"),
    ("Bobodo explique moi cette lecon", "bobodo"),
    ("Academia est une super plateforme", "academia"),
    ("Comment fonctionne Academia", "academia"),
    ("Je suis sur Academia depuis deux mois", "academia"),
    ("Bobodo m aide a reviser", "bobodo"),
    ("Le tuteur intelligent s appelle Bobodo", "bobodo"),
    ("Academia propose des cours en ligne", "academia"),
    ("Je recommande Bobodo a mes amis", "bobodo"),
    # Catégorie B — Universités & Écoles (11-25)
    ("Universite Joseph Ki-Zerbo", "universite"),
    ("Universite Nazi Boni", "universite"),
    ("Universite Ouaga I Joseph Ki-Zerbo", "universite"),
    ("Universite Norbert Zongo", "universite"),
    ("Universite Thomas Sankara", "universite"),
    ("Institut National des Sciences et Techniques", "ecole"),
    ("Ecole Nationale d Administration et de Magistrature", "ecole"),
    ("Institut Superieur des Sciences de la Sante", "ecole"),
    ("Centre Universitaire de Kaya", "ecole"),
    ("Ecole Normale Superieure de Koudougou", "ecole"),
    ("Universite de Dedougou", "universite"),
    ("Universite de Fada N Gourma", "universite"),
    ("Universite de Dori", "universite"),
    ("Universite de Bobo Dioulasso", "universite"),
    ("Institut Burkinabe des Arts et des Metiers", "ecole"),
    # Catégorie C — Filières & Disciplines (26-40)
    ("Medecine generale", "filiere"),
    ("Chirurgie dentaire", "filiere"),
    ("Sciences pharmaceutiques", "filiere"),
    ("Genie civil", "filiere"),
    ("Genie electrique", "filiere"),
    ("Genie informatique", "filiere"),
    ("Sciences economiques et gestion", "filiere"),
    ("Droit public", "filiere"),
    ("Droit prive", "filiere"),
    ("Sciences de l education", "filiere"),
    ("Biologie et physiologie", "filiere"),
    ("Chimie organique", "filiere"),
    ("Mathematiques fondamentales", "filiere"),
    ("Physique nucleaire", "filiere"),
    ("Statistiques appliquees", "filiere"),
    # Catégorie D — Pays & Géographie (41-50)
    ("Burkina Faso", "pays"),
    ("Republique du Burkina Faso", "pays"),
    ("Cote d Ivoire", "pays"),
    ("Ghana", "pays"),
    ("Mali", "pays"),
    ("Senegal", "pays"),
    ("Togo", "pays"),
    ("Benin", "pays"),
    ("Niger", "pays"),
    ("Guinee Conakry", "pays"),
    # Catégorie E — Villes & Régions (51-60)
    ("Ouagadougou", "ville"),
    ("Bobo Dioulasso", "ville"),
    ("Koudougou", "ville"),
    ("Banfora", "ville"),
    ("Kaya", "ville"),
    ("Fada N Gourma", "ville"),
    ("Dori", "ville"),
    ("Gorom Gorom", "ville"),
    ("Gaoua", "ville"),
    ("Dedougou", "ville"),
    # Catégorie F — Termes Administratifs & Concours (61-75)
    ("Concours d entree en medecine", "admin"),
    ("Concours direct", "admin"),
    ("Concours sur epreuves", "admin"),
    ("Concours sur titre", "admin"),
    ("Baccalaureat", "admin"),
    ("Diplome d etudes fondamentales", "admin"),
    ("Doctorat en medecine", "admin"),
    ("Master en sciences", "admin"),
    ("Inscription administrative", "admin"),
    ("Frais d inscription", "admin"),
    ("Bourse d etudes", "admin"),
    ("Attestation de reussite", "admin"),
    ("Releve de notes", "admin"),
    ("Carte d etudiant", "admin"),
    ("Paiement par orange money", "admin"),
    # Catégorie G — Termes Pédagogiques (76-85)
    ("Cours magistral", "pedago"),
    ("Travaux diriges", "pedago"),
    ("Travaux pratiques", "pedago"),
    ("Examen blanc", "pedago"),
    ("Questionnaire a choix multiple", "pedago"),
    ("Sujet de dissertation", "pedago"),
    ("Correction automatique", "pedago"),
    ("Notes de cours", "pedago"),
    ("Resume de chapitre", "pedago"),
    ("Preparation aux concours", "pedago"),
    # Catégorie H — Questions Typiques (86-100)
    ("Comment m inscrire sur Academia", "question"),
    ("Ou trouver les cours de medecine", "question"),
    ("Quel est le prix de la formation", "question"),
    ("Comment payer avec LigdiCash", "question"),
    ("Puis-je avoir une bourse d etudes", "question"),
    ("Quelle universite accepte mon dossier", "question"),
    ("Comment preparer le concours de medecine", "question"),
    ("Ou sont les exercices corriges", "question"),
    ("Comment utiliser Bobodo en mode vocal", "question"),
    ("Quelle est la date limite d inscription", "question"),
    ("Comment recuperer mes credits", "question"),
    ("Puis-je changer de filiere", "question"),
    ("Ou se passe le concours", "question"),
    ("Comment contacter l administration", "question"),
    ("Merci Bobodo au revoir", "question"),
]

# === DICTIONNAIRE DE CORRECTION ===
CORRECTIONS = {
    # Noms propres Academia
    "boudou": "Bobodo",
    "bouddou": "Bobodo",
    "boudo": "Bobodo",
    "boudou": "Bobodo",
    "bouddo": "Bobodo",
    "academia": "Academia",
    "akademia": "Academia",
    "académia": "Academia",
    # Burkina
    "burkina": "Burkina",
    "burquina": "Burkina",
    "bur quina": "Burkina",
    "bur qu'il n'a": "Burkina",
    "bur qu'il n'a face au": "Burkina Faso",
    "burquina faso": "Burkina Faso",
    # Universités
    "ki zerbo": "Ki-Zerbo",
    "kizerbo": "Ki-Zerbo",
    "nazi boni": "Nazi Boni",
    "norbert zongo": "Norbert Zongo",
    "thomas sankara": "Thomas Sankara",
    # Villes
    "ouagadougou": "Ouagadougou",
    "ouagadougou": "Ouagadougou",
    "bobo dioulasso": "Bobo Dioulasso",
    "koudougou": "Koudougou",
    "banfora": "Banfora",
    "kaya": "Kaya",
    "fada n gourma": "Fada N'Gourma",
    "fada n'gourma": "Fada N'Gourma",
    "dori": "Dori",
    "gorom gorom": "Gorom-Gorom",
    "gaoua": "Gaoua",
    "dedougou": "Dédougou",
    "dédougou": "Dédougou",
    # Pays
    "cote d'ivoire": "Côte d'Ivoire",
    "cote d ivoire": "Côte d'Ivoire",
    "senegal": "Sénégal",
    "togo": "Togo",
    "benin": "Bénin",
    "niger": "Niger",
    "guinee conakry": "Guinée Conakry",
    # Termes
    "medecine": "médecine",
    "genie": "génie",
    "mathematiques": "mathématiques",
    "baccalaureat": "baccalauréat",
    "bourse": "bourse",
    "releve": "relevé",
    "carte d etudiant": "carte d'étudiant",
    "travaux diriges": "travaux dirigés",
    "travaux pratiques": "travaux pratiques",
    "examen blanc": "examen blanc",
    "ligdicash": "LigdiCash",
    "ligdi cash": "LigdiCash",
    "questionnaire": "questionnaire",
    "dissertation": "dissertation",
    "preparation": "préparation",
    "chapitre": "chapitre",
    "resume": "résumé",
    "notes de cours": "notes de cours",
    "correction automatique": "correction automatique",
    "cours magistral": "cours magistral",
    # Génériques
    "universite": "université",
    "ecole": "école",
    "superieur": "supérieur",
    "nationale": "nationale",
    "superieure": "supérieure",
    "administration": "administration",
    "inscription": "inscription",
    "attestation": "attestation",
    "frais": "frais",
    "doctorat": "doctorat",
    "fondamentales": "fondamentales",
    "epreuves": "épreuves",
    "titre": "titre",
}

def normalize(s):
    """Normalise pour comparaison : minuscules, sans accents."""
    s = s.lower().strip()
    s = s.replace("é", "e").replace("è", "e").replace("ê", "e")
    s = s.replace("à", "a").replace("â", "a")
    s = s.replace("ô", "o").replace("ö", "o")
    s = s.replace("ï", "i").replace("î", "i")
    s = s.replace("ç", "c").replace("ù", "u").replace("û", "u")
    s = s.replace("'", " ").replace("-", " ")
    return s

def word_error_rate(expected, actual):
    """Calcule le WER (mots incorrects / mots totaux)."""
    e_words = normalize(expected).split()
    a_words = normalize(actual).split()
    # Séquence alignment simple
    matcher = difflib.SequenceMatcher(None, e_words, a_words)
    errors = 0
    for tag, i1, i2, j1, j2 in matcher.get_opcodes():
        if tag != 'equal':
            errors += max(i2 - i1, j2 - j1)
    total = len(e_words)
    return (errors / total * 100) if total > 0 else 0

def apply_dict(text):
    """Applique le dictionnaire de correction."""
    result = text
    # Appliquer les corrections longues d'abord
    keys_by_len = sorted(CORRECTIONS.keys(), key=len, reverse=True)
    for wrong in keys_by_len:
        right = CORRECTIONS[wrong]
        result = result.replace(wrong, right)
        # Aussi en minuscule
        result = result.replace(wrong.lower(), right)
    return result

def generate_audio(text, idx):
    """Génère un WAV 16kHz mono à partir du texte."""
    mp3 = os.path.join(OUT_DIR, f"expr_{idx:03d}.mp3")
    wav = os.path.join(OUT_DIR, f"expr_{idx:03d}.wav")
    subprocess.run(["gtts-cli", text, "--lang", "fr", "--output", mp3], capture_output=True)
    subprocess.run(["ffmpeg", "-y", "-i", mp3, "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wav], capture_output=True)
    return wav

def main():
    print("="*60)
    print("BOBODO TINY — ACADEMIA CORPUS BENCHMARK")
    print("="*60)

    print(f"\nCorpus: {len(CORPUS)} expressions")

    # Vérifier déps
    print("\n[1/5] Checking dependencies...")
    try:
        subprocess.run(["gtts-cli", "--help"], check=True, capture_output=True)
        print("  gtts-cli: OK")
    except:
        print("  gtts-cli: NOT FOUND")
        sys.exit(1)
    try:
        subprocess.run(["ffmpeg", "-version"], check=True, capture_output=True)
        print("  ffmpeg: OK")
    except:
        print("  ffmpeg: NOT FOUND")
        sys.exit(1)

    # Charger Tiny
    print("\n[2/5] Loading Tiny model...")
    from faster_whisper import WhisperModel
    model = WhisperModel("tiny", device="cpu", compute_type="int8")

    # Générer tous les audios
    print("\n[3/5] Generating 100 audio files...")
    audio_files = []
    for i, (text, cat) in enumerate(CORPUS):
        wav = generate_audio(text, i)
        audio_files.append(wav)
        if (i + 1) % 20 == 0:
            print(f"  {i+1}/{len(CORPUS)} done")

    # Transcrire
    print("\n[4/5] Transcribing with Tiny...")
    results = []
    total_time = 0
    for i, (expected, cat) in enumerate(CORPUS):
        t1 = time.time()
        segments, info = model.transcribe(audio_files[i], language="fr", beam_size=5)
        raw_text = " ".join([s.text for s in segments]).strip()
        t2 = time.time()
        elapsed = (t2 - t1) * 1000
        total_time += elapsed

        corrected_text = apply_dict(raw_text)
        wer_raw = word_error_rate(expected, raw_text)
        wer_corrected = word_error_rate(expected, corrected_text)

        # Déterminer si exact
        exact_raw = normalize(expected) == normalize(raw_text)
        exact_corrected = normalize(expected) == normalize(corrected_text)

        results.append({
            "id": i + 1,
            "expected": expected,
            "category": cat,
            "raw": raw_text,
            "corrected": corrected_text,
            "exact_raw": exact_raw,
            "exact_corrected": exact_corrected,
            "wer_raw": round(wer_raw, 1),
            "wer_corrected": round(wer_corrected, 1),
            "time_ms": round(elapsed, 1)
        })

        if not exact_raw:
            status = "ERR"
        else:
            status = "OK"
        print(f"  {i+1:03d}/{len(CORPUS)} [{status}] {elapsed:.0f}ms | E:'{expected[:40]}' | A:'{raw_text[:40]}'")

    # Stats globales
    avg_time = total_time / len(CORPUS)
    exact_raw_count = sum(1 for r in results if r["exact_raw"])
    exact_corr_count = sum(1 for r in results if r["exact_corrected"])
    avg_wer_raw = sum(r["wer_raw"] for r in results) / len(CORPUS)
    avg_wer_corr = sum(r["wer_corrected"] for r in results) / len(CORPUS)

    # Classification erreurs
    critical_raw = [r for r in results if r["wer_raw"] >= 30]
    major_raw = [r for r in results if 10 <= r["wer_raw"] < 30]
    minor_raw = [r for r in results if 0 < r["wer_raw"] < 10]

    critical_corr = [r for r in results if r["wer_corrected"] >= 30]
    major_corr = [r for r in results if 10 <= r["wer_corrected"] < 30]
    minor_corr = [r for r in results if 0 < r["wer_corrected"] < 10]

    print("\n" + "="*60)
    print("RESULTS")
    print("="*60)
    print(f"\nExact match (raw)     : {exact_raw_count}/{len(CORPUS)} = {exact_raw_count/len(CORPUS)*100:.1f}%")
    print(f"Exact match (corrected): {exact_corr_count}/{len(CORPUS)} = {exact_corr_count/len(CORPUS)*100:.1f}%")
    print(f"WER moyen (raw)       : {avg_wer_raw:.1f}%")
    print(f"WER moyen (corrected)  : {avg_wer_corr:.1f}%")
    print(f"Temps moyen/phrase    : {avg_time:.0f}ms")
    print(f"Temps total           : {total_time/1000:.0f}s")

    print(f"\n--- Classification erreurs RAW ---")
    print(f"  CRITIQUE (WER>=30%) : {len(critical_raw)} = {len(critical_raw)/len(CORPUS)*100:.1f}%")
    print(f"  MAJEURE (10-30%)    : {len(major_raw)} = {len(major_raw)/len(CORPUS)*100:.1f}%")
    print(f"  MINEURE (0-10%)     : {len(minor_raw)} = {len(minor_raw)/len(CORPUS)*100:.1f}%")

    print(f"\n--- Classification erreurs CORRECTED ---")
    print(f"  CRITIQUE (WER>=30%) : {len(critical_corr)} = {len(critical_corr)/len(CORPUS)*100:.1f}%")
    print(f"  MAJEURE (10-30%)    : {len(major_corr)} = {len(major_corr)/len(CORPUS)*100:.1f}%")
    print(f"  MINEURE (0-10%)     : {len(minor_corr)} = {len(minor_corr)/len(CORPUS)*100:.1f}%")

    # Catégories
    print("\n--- Par catégorie (WER moyen, RAW) ---")
    cats = {}
    for r in results:
        c = r["category"]
        if c not in cats:
            cats[c] = []
        cats[c].append(r["wer_raw"])
    for cat in sorted(cats.keys()):
        avg = sum(cats[cat]) / len(cats[cat])
        print(f"  {cat:<15} : {avg:.1f}% WER (n={len(cats[cat])})")

    # Sauvegarder rapport
    report = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "server": "Kamatera 185.167.97.144",
        "model": "tiny",
        "beam_size": 5,
        "total_expressions": len(CORPUS),
        "exact_raw_percent": round(exact_raw_count/len(CORPUS)*100, 1),
        "exact_corrected_percent": round(exact_corr_count/len(CORPUS)*100, 1),
        "wer_raw_avg": round(avg_wer_raw, 1),
        "wer_corrected_avg": round(avg_wer_corr, 1),
        "avg_time_ms": round(avg_time, 1),
        "total_time_s": round(total_time/1000, 1),
        "classification_raw": {
            "critical_count": len(critical_raw),
            "critical_percent": round(len(critical_raw)/len(CORPUS)*100, 1),
            "major_count": len(major_raw),
            "major_percent": round(len(major_raw)/len(CORPUS)*100, 1),
            "minor_count": len(minor_raw),
            "minor_percent": round(len(minor_raw)/len(CORPUS)*100, 1),
        },
        "classification_corrected": {
            "critical_count": len(critical_corr),
            "critical_percent": round(len(critical_corr)/len(CORPUS)*100, 1),
            "major_count": len(major_corr),
            "major_percent": round(len(major_corr)/len(CORPUS)*100, 1),
            "minor_count": len(minor_corr),
            "minor_percent": round(len(minor_corr)/len(CORPUS)*100, 1),
        },
        "category_wer": {cat: round(sum(v)/len(v), 1) for cat, v in cats.items()},
        "critical_errors_raw": [{"id": r["id"], "expected": r["expected"], "actual": r["raw"], "wer": r["wer_raw"]} for r in critical_raw],
        "critical_errors_corrected": [{"id": r["id"], "expected": r["expected"], "actual": r["corrected"], "wer": r["wer_corrected"]} for r in critical_corr],
        "all_results": results
    }

    report_path = os.path.join(OUT_DIR, "academia_corpus_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\n\nREPORT SAVED: {report_path}")
    print("="*60)

if __name__ == "__main__":
    main()
