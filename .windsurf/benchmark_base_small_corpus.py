#!/usr/bin/env python3
"""
Benchmark Base et Small sur corpus Academia (100 expressions).
Réutilise les fichiers audio déjà générés.
Aucun impact sur le service en cours.
"""

import os
import sys
import time
import json
import difflib
import glob

OUT_DIR = "/tmp/tiny_academia_benchmark"

# === CORPUS (même ordre que le benchmark Tiny) ===
CORPUS = [
    ("Bonjour Bobodo", "bobodo"), ("Je veux parler a Bobodo", "bobodo"),
    ("Bobodo explique moi cette lecon", "bobodo"), ("Academia est une super plateforme", "academia"),
    ("Comment fonctionne Academia", "academia"), ("Je suis sur Academia depuis deux mois", "academia"),
    ("Bobodo m aide a reviser", "bobodo"), ("Le tuteur intelligent s appelle Bobodo", "bobodo"),
    ("Academia propose des cours en ligne", "academia"), ("Je recommande Bobodo a mes amis", "bobodo"),
    ("Universite Joseph Ki-Zerbo", "universite"), ("Universite Nazi Boni", "universite"),
    ("Universite Ouaga I Joseph Ki-Zerbo", "universite"), ("Universite Norbert Zongo", "universite"),
    ("Universite Thomas Sankara", "universite"), ("Institut National des Sciences et Techniques", "ecole"),
    ("Ecole Nationale d Administration et de Magistrature", "ecole"),
    ("Institut Superieur des Sciences de la Sante", "ecole"),
    ("Centre Universitaire de Kaya", "ecole"), ("Ecole Normale Superieure de Koudougou", "ecole"),
    ("Universite de Dedougou", "universite"), ("Universite de Fada N Gourma", "universite"),
    ("Universite de Dori", "universite"), ("Universite de Bobo Dioulasso", "universite"),
    ("Institut Burkinabe des Arts et des Metiers", "ecole"),
    ("Medecine generale", "filiere"), ("Chirurgie dentaire", "filiere"),
    ("Sciences pharmaceutiques", "filiere"), ("Genie civil", "filiere"),
    ("Genie electrique", "filiere"), ("Genie informatique", "filiere"),
    ("Sciences economiques et gestion", "filiere"), ("Droit public", "filiere"),
    ("Droit prive", "filiere"), ("Sciences de l education", "filiere"),
    ("Biologie et physiologie", "filiere"), ("Chimie organique", "filiere"),
    ("Mathematiques fondamentales", "filiere"), ("Physique nucleaire", "filiere"),
    ("Statistiques appliquees", "filiere"),
    ("Burkina Faso", "pays"), ("Republique du Burkina Faso", "pays"),
    ("Cote d Ivoire", "pays"), ("Ghana", "pays"), ("Mali", "pays"),
    ("Senegal", "pays"), ("Togo", "pays"), ("Benin", "pays"),
    ("Niger", "pays"), ("Guinee Conakry", "pays"),
    ("Ouagadougou", "ville"), ("Bobo Dioulasso", "ville"),
    ("Koudougou", "ville"), ("Banfora", "ville"), ("Kaya", "ville"),
    ("Fada N Gourma", "ville"), ("Dori", "ville"), ("Gorom Gorom", "ville"),
    ("Gaoua", "ville"), ("Dedougou", "ville"),
    ("Concours d entree en medecine", "admin"), ("Concours direct", "admin"),
    ("Concours sur epreuves", "admin"), ("Concours sur titre", "admin"),
    ("Baccalaureat", "admin"), ("Diplome d etudes fondamentales", "admin"),
    ("Doctorat en medecine", "admin"), ("Master en sciences", "admin"),
    ("Inscription administrative", "admin"), ("Frais d inscription", "admin"),
    ("Bourse d etudes", "admin"), ("Attestation de reussite", "admin"),
    ("Releve de notes", "admin"), ("Carte d etudiant", "admin"),
    ("Paiement par orange money", "admin"),
    ("Cours magistral", "pedago"), ("Travaux diriges", "pedago"),
    ("Travaux pratiques", "pedago"), ("Examen blanc", "pedago"),
    ("Questionnaire a choix multiple", "pedago"), ("Sujet de dissertation", "pedago"),
    ("Correction automatique", "pedago"), ("Notes de cours", "pedago"),
    ("Resume de chapitre", "pedago"), ("Preparation aux concours", "pedago"),
    ("Comment m inscrire sur Academia", "question"), ("Ou trouver les cours de medecine", "question"),
    ("Quel est le prix de la formation", "question"), ("Comment payer avec LigdiCash", "question"),
    ("Puis-je avoir une bourse d etudes", "question"), ("Quelle universite accepte mon dossier", "question"),
    ("Comment preparer le concours de medecine", "question"), ("Ou sont les exercices corriges", "question"),
    ("Comment utiliser Bobodo en mode vocal", "question"), ("Quelle est la date limite d inscription", "question"),
    ("Comment recuperer mes credits", "question"), ("Puis-je changer de filiere", "question"),
    ("Ou se passe le concours", "question"), ("Comment contacter l administration", "question"),
    ("Merci Bobodo au revoir", "question"),
]

# Noms propres spécifiques à tracker
PROPER_NAMES = {
    "Bobodo": ["Bonjour Bobodo", "Je veux parler a Bobodo", "Bobodo explique moi cette lecon",
               "Bobodo m aide a reviser", "Le tuteur intelligent s appelle Bobodo",
               "Je recommande Bobodo a mes amis", "Comment utiliser Bobodo en mode vocal", "Merci Bobodo au revoir"],
    "Academia": ["Academia est une super plateforme", "Comment fonctionne Academia",
                 "Je suis sur Academia depuis deux mois", "Academia propose des cours en ligne",
                 "Comment m inscrire sur Academia"],
    "Burkina Faso": ["Burkina Faso", "Republique du Burkina Faso"],
    "Joseph Ki-Zerbo": ["Universite Joseph Ki-Zerbo", "Universite Ouaga I Joseph Ki-Zerbo"],
    "Aube Nouvelle": [],  # Pas dans le corpus original, on le testera séparément si possible
    "Supabase": [],
    "LiveKit": [],
    "Kamatera": [],
}

CLK_TCK = os.sysconf(os.sysconf_names['SC_CLK_TCK'])

def get_pid_resources(pid):
    try:
        with open(f"/proc/{pid}/stat", "r") as f:
            parts = f.read().split()
            utime = int(parts[13])
            stime = int(parts[14])
        with open("/proc/uptime", "r") as f:
            uptime = float(f.read().split()[0])
        with open(f"/proc/{pid}/status", "r") as f:
            rss = None
            for line in f:
                if line.startswith("VmRSS:"):
                    rss = int(line.split()[1]) / 1024
                    break
        threads = len(os.listdir(f"/proc/{pid}/task"))
        return (utime, stime, uptime, rss, threads)
    except:
        return (None, None, None, None, None)

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

def benchmark_model(model_name, corpus, out_dir):
    """Benchmark un modèle sur le corpus."""
    print(f"\n{'='*60}")
    print(f"BENCHMARKING: {model_name.upper()}")
    print(f"{'='*60}")

    from faster_whisper import WhisperModel
    t_load_start = time.time()
    model = WhisperModel(model_name, device="cpu", compute_type="int8")
    t_load_end = time.time()
    load_ms = (t_load_end - t_load_start) * 1000

    pid = os.getpid()
    r_load = get_pid_resources(pid)
    ram_load = r_load[3] if r_load[3] else 0

    print(f"  Loaded in {load_ms:.0f}ms | RAM={ram_load:.0f}MB")

    results = []
    times = []
    rams = []
    cpus = []

    # Warm-up
    wav0 = os.path.join(out_dir, "expr_000.wav")
    if os.path.exists(wav0):
        segments, _ = model.transcribe(wav0, language="fr", beam_size=5)
        _ = " ".join([s.text for s in segments])

    for i, (expected, cat) in enumerate(corpus):
        wav = os.path.join(out_dir, f"expr_{i:03d}.wav")
        if not os.path.exists(wav):
            print(f"  MISSING: {wav}")
            continue

        r1 = get_pid_resources(pid)
        t1 = time.time()
        segments, info = model.transcribe(wav, language="fr", beam_size=5)
        text = " ".join([s.text for s in segments]).strip()
        t2 = time.time()
        r2 = get_pid_resources(pid)

        elapsed = (t2 - t1) * 1000
        times.append(elapsed)
        rams.append(r2[3] if r2[3] else 0)

        # CPU approx
        if r1[0] is not None and r2[0] is not None:
            cpu = ((r2[0] + r2[1]) - (r1[0] + r1[1])) / CLK_TCK / (r2[2] - r1[2]) * 100
            cpus.append(cpu)
        else:
            cpus.append(0)

        wer = word_error_rate(expected, text)
        exact = normalize(expected) == normalize(text)

        results.append({
            "id": i + 1,
            "expected": expected,
            "category": cat,
            "actual": text,
            "exact": exact,
            "wer": round(wer, 1),
            "time_ms": round(elapsed, 1),
            "cpu_percent": round(cpus[-1], 1),
            "ram_mb": round(rams[-1], 1)
        })

        status = "OK" if exact else "ERR"
        print(f"  {i+1:03d}/{len(corpus)} [{status}] {elapsed:.0f}ms | WER={wer:.0f}% | '{text[:50]}'")

    # Stats
    avg_time = sum(times) / len(times) if times else 0
    min_time = min(times) if times else 0
    max_time = max(times) if times else 0
    avg_ram = sum(rams) / len(rams) if rams else 0
    max_ram = max(rams) if rams else 0
    avg_cpu = sum(cpus) / len(cpus) if cpus else 0
    exact_count = sum(1 for r in results if r["exact"])
    avg_wer = sum(r["wer"] for r in results) / len(results) if results else 0

    critical = [r for r in results if r["wer"] >= 30]
    major = [r for r in results if 10 <= r["wer"] < 30]
    minor = [r for r in results if 0 < r["wer"] < 10]

    print(f"\n  --- {model_name.upper()} SUMMARY ---")
    print(f"  Load time: {load_ms:.0f}ms")
    print(f"  RAM at load: {ram_load:.0f}MB")
    print(f"  Avg time: {avg_time:.0f}ms")
    print(f"  Min time: {min_time:.0f}ms")
    print(f"  Max time: {max_time:.0f}ms")
    print(f"  Avg RAM: {avg_ram:.0f}MB")
    print(f"  Max RAM: {max_ram:.0f}MB")
    print(f"  Avg CPU: {avg_cpu:.0f}%")
    print(f"  Exact: {exact_count}/{len(results)} = {exact_count/len(results)*100:.1f}%")
    print(f"  WER avg: {avg_wer:.1f}%")
    print(f"  Critical: {len(critical)} ({len(critical)/len(results)*100:.1f}%)")

    return {
        "model": model_name,
        "load_ms": round(load_ms, 1),
        "ram_load_mb": round(ram_load, 1),
        "avg_time_ms": round(avg_time, 1),
        "min_time_ms": round(min_time, 1),
        "max_time_ms": round(max_time, 1),
        "avg_ram_mb": round(avg_ram, 1),
        "max_ram_mb": round(max_ram, 1),
        "avg_cpu_percent": round(avg_cpu, 1),
        "exact_count": exact_count,
        "exact_percent": round(exact_count/len(results)*100, 1),
        "wer_avg": round(avg_wer, 1),
        "critical_count": len(critical),
        "critical_percent": round(len(critical)/len(results)*100, 1),
        "major_count": len(major),
        "major_percent": round(len(major)/len(results)*100, 1),
        "minor_count": len(minor),
        "minor_percent": round(len(minor)/len(results)*100, 1),
        "results": results
    }

def main():
    print("="*60)
    print("BOBODO BASE + SMALL REAL BENCHMARK — Kamatera")
    print("="*60)
    print(f"Corpus: {len(CORPUS)} expressions")
    print(f"Audio dir: {OUT_DIR}")

    # Vérifier que les fichiers existent
    wav_files = sorted(glob.glob(os.path.join(OUT_DIR, "expr_*.wav")))
    print(f"WAV files found: {len(wav_files)}")
    if len(wav_files) < len(CORPUS):
        print("ERROR: Not enough audio files. Run the Tiny corpus benchmark first.")
        sys.exit(1)

    # Benchmark Base
    base_report = benchmark_model("base", CORPUS, OUT_DIR)

    # Benchmark Small
    small_report = benchmark_model("small", CORPUS, OUT_DIR)

    # Final report
    report = {
        "timestamp": time.strftime("%Y-%m-%d %H:%M:%S"),
        "server": "Kamatera 185.167.97.144",
        "corpus_size": len(CORPUS),
        "base": base_report,
        "small": small_report
    }

    report_path = os.path.join(OUT_DIR, "base_small_corpus_report.json")
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"\n{'='*60}")
    print(f"REPORT SAVED: {report_path}")
    print(f"{'='*60}")

if __name__ == "__main__":
    main()
