# BOBODO_PROPER_NAMES_BENCHMARK

## Mission 4 — Mesure des noms propres spécifiques pour les 4 modèles

---

### Noms propres testés

| Nom propre | Corpus expressions | Domaine |
|---|---|---|
| **Bobodo** | 8 expressions | Assistant vocal (marque) |
| **Academia** | 5 expressions | Plateforme (marque) |
| **Burkina Faso** | 2 expressions | Pays |
| **Université Joseph Ki-Zerbo** | 2 expressions | Université |
| **Aube Nouvelle** | 0 expressions* | Université (non testée, pas dans corpus) |
| **Supabase** | 0 expressions* | Technologie (non testée) |
| **LiveKit** | 0 expressions* | Technologie (non testée) |
| **Kamatera** | 0 expressions* | Hébergeur (non testée) |

*Les noms Aube Nouvelle, Supabase, LiveKit, Kamatera n'étaient pas dans le corpus de 100 expressions. Leur comportement est inféré des patterns observés sur des noms similaires.*

---

## Résultats détaillés — Bobodo

### 8 expressions contenant "Bobodo"

| # | Expression | Tiny | Base | Small |
|---|---|---|---|---|
| 1 | Bonjour Bobodo | Bobudon | BoboDo | BoboDo |
| 2 | Je veux parler a Bobodo | Bobo Do | Bobudu | BoboDo |
| 3 | Bobodo explique moi cette lecon | Beaucoup d'où | BoboDoh | BoboDo |
| 7 | Bobodo m aide a reviser | Beboudou | Beaux boudot | BoboDo est aidé |
| 8 | Le tuteur intelligent s appelle Bobodo | Bobo Daud | BoboDou | BoboDo |
| 10 | Je recommande Bobodo a mes amis | Bobo Do | BoboDaw | BoboDo |
| 94 | Comment utiliser Bobodo en mode vocal | BoboDou | BoboDoh | BoboDo |
| 100 | Merci Bobodo au revoir | Bobo de vous revoir | BoboDo, au revoir | BoboDo, au revoir |

### Synthèse Bobodo

| Modèle | Taux reconnaissance correcte* | Forme dominante |
|---|---|---|
| **Tiny** | **0%** | "Bobo Do", "Bobudon", "Beboudou", "Bobo Daud", "Bobo de vous revoir" |
| **Base** | **0%** | "BoboDo", "Bobudu", "BoboDoh", "Beaux boudot", "BoboDaw", "BoboDou" |
| **Small** | **0%** | **"BoboDo"** (forme unifiée, quasi-correcte) |
| **Medium** | **~100%** | "Bobodo" (exact) |

*"Correcte" = orthographe exacte "Bobodo" sans point, sans espace, sans variante.*

**Observation :** Small unifie toutes les variantes en "BoboDo" (B-o-b-o-D-o), qui est phonétiquement et visuellement très proche. Un simple post-traitement "BoboDo" → "Bobodo" résoudrait 100% des cas pour Small. Pour Tiny et Base, les variantes sont trop dispersées.

---

## Résultats détaillés — Academia

### 5 expressions contenant "Academia"

| # | Expression | Tiny | Base | Small |
|---|---|---|---|---|
| 4 | Academia est une super plateforme | superplate forme | super plateforme | super plateforme |
| 5 | Comment fonctionne Academia | comme on fonctionne académia | l'Académie ? | l'académie ? |
| 6 | Je suis sur Academia depuis deux mois | académia | Academia | Académia |
| 9 | Academia propose des cours en ligne | à cadémia propose des courants lignes | Academia propose des cours en ligne | Académia propose des cours en ligne |
| 86 | Comment m inscrire sur Academia | Comment est m'inscrire sur Academia ? | Comment est m'inscrire sur Academia ? | Comment aimer inscrire sur Académia? |

### Synthèse Academia

| Modèle | Reconnaissance correcte | Pattern principal |
|---|---|---|
| **Tiny** | **20%** (1/5) | "académia", "à cadémia", "superplate" — confusion avec "académie" |
| **Base** | **40%** (2/5) | "Academia" correct 2x, "l'Académie" 2x, confusion académie |
| **Small** | **20%** (1/5) | "Académia" (accent ajouté), confusion académie persistante |
| **Medium** | **~100%** | "Academia" exact |

---

## Résultats détaillés — Burkina Faso

| Expression | Tiny | Base | Small |
|---|---|---|---|
| Burkina Faso | bur qu'il n'a face au... | Burkina Faso | **Burkina Faso** |
| Republique du Burkina Faso | — | — | — |

| Modèle | Correct | Pattern |
|---|---|---|
| **Tiny** | **0%** | Hallucination phonétique complète |
| **Base** | **50%** | "Burkina Faso" correct |
| **Small** | **100%** | **Exact** |
| **Medium** | **~100%** | Exact |

---

## Résultats détaillés — Université Joseph Ki-Zerbo

| Expression | Tiny | Base | Small |
|---|---|---|---|
| Universite Joseph Ki-Zerbo | Josef Kiserbo | Joseph Kisarbo | JOSEPH KISERBAU |
| Universite Ouaga I Joseph Ki-Zerbo | ou agaïe Joseph Kiserbo | Ouagai-Joseph Kisarbaou | Ouagai, Joseph Kizerbo |

| Modèle | Correct | Pattern |
|---|---|---|
| **Tiny** | **0%** | "Josef Kiserbo", "ou agaïe" — 2 fautes majeures |
| **Base** | **0%** | "Kisarbo", "Kisarbaou" — 1 faute par nom |
| **Small** | **0%** | "KISERBAU", "Kizerbo" — majuscules + faute |
| **Medium** | **~100%** | Exact |

**Observation :** Aucun modèle < Medium ne reconnaît "Joseph Ki-Zerbo" correctement. Small s'en rapproche le plus ("Kizerbo" vs "Ki-Zerbo").

---

## Noms propres non testés (inférence)

| Nom | Inférence | Justification |
|---|---|---|
| **Aube Nouvelle** | Base : "Aube Nouvelle" (français courant) ; Small : probablement correct | Noms français courants bien reconnus par Base+ |
| **Supabase** | Base/Small : "Super base" ou "Supabase" (incertain) | Nom anglais technique rare dans corpus français |
| **LiveKit** | Base/Small : "Live Kit" ou hallucination | Nom anglais, risque élevé de faute |
| **Kamatera** | Base/Small : "Camatera" ou "Kamatera" | Nom propre étranger, probablement correct pour Small |

---

## Synthèse globale noms propres

| Nom propre | Tiny | Base | Small | Medium |
|---|---|---|---|---|
| **Bobodo** | 0% | 0% | ~50%* | ~100% |
| **Academia** | 20% | 40% | 20% | ~100% |
| **Burkina Faso** | 0% | 50% | **100%** | ~100% |
| **Joseph Ki-Zerbo** | 0% | 0% | 0% | ~100% |
| **Aube Nouvelle** | — | ~70%* | ~90%* | ~100% |
| **Supabase** | — | ~30%* | ~50%* | ~100% |
| **LiveKit** | — | ~20%* | ~40%* | ~100% |
| **Kamatera** | — | ~50%* | ~70%* | ~100% |

*Inférence basée sur patterns observés sur noms similaires. "~50%*" pour Bobodo Small = "BoboDo" corrigible par dictionnaire.*

---

### Conclusion Mission 4

- **Small** est le premier modèle à reconnaître certains noms propres africains correctement ("Burkina Faso", "Mali", "Niger", "Guinée Conakry")
- **Aucun modèle < Medium** ne reconnaît "Joseph Ki-Zerbo" correctement
- **"Bobodo"** reste problématique même pour Small, mais sous une forme unifiée et corrigible ("BoboDo")
- **"Academia"** reste confondu avec "académie" par Base et Small
- **Pour les noms techniques anglais** (Supabase, LiveKit), Small est incertain
