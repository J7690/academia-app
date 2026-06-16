# Audit Profond — Capacité d'Apprentissage IA du Module Concours
## Date: 20 Avril 2026

---

## VERDICT : L'IA N'APPREND PAS ENCORE RÉELLEMENT

Le dispositif technique EXISTE (tables, Edge Functions, RPCs), mais il est **inactif et vide**. La machine d'apprentissage est construite mais **jamais alimentée ni déclenchée**.

---

## A. ÉTAT DES TABLES D'APPRENTISSAGE

| Table | Rôle | Données |
|-------|------|---------|
| `prep_topics` | Thèmes identifiés par l'IA | **12 topics** (génériques, pas issus d'analyse) |
| `prep_topic_predictions` | Prédictions de probabilité par thème/concours | **0 prédictions** |
| `prep_question_topics` | Liaison questions ↔ topics | **0 liaisons** |
| `prep_student_weaknesses` | Faiblesses individuelles par matière | **0 enregistrements** |
| `prep_ai_corrections` | Corrections IA des réponses étudiants | **0 corrections** |
| `prep_quiz_attempts` | Tentatives de quiz (données d'usage) | **0 tentatives** |

### Diagnostic: Toutes les tables d'apprentissage sont VIDES.

---

## B. QUESTIONS PASSÉES (base de connaissances)

**Total : 147 questions** — C'est la seule "nourriture" du système.

### Par source d'origine :
- `ai_seed` : 96 questions (pré-générées, pas issues de vrais sujets)
- `external_source` : 36 questions (importées manuellement)
- `manual` : 15 questions (saisies à la main)

### Par matière :
| Matière | Questions | Chunks RAG |
|---------|-----------|------------|
| Culture Générale | 47 | 1128 (cross-join artifact) |
| Tests Psychotechniques | 26 | 0 |
| Droit Constitutionnel | 9 | 0 |
| Fiscalité | 8 | 0 |
| Actualités BF | 8 | 418 (actualités RSS) |
| Mathématiques | 8 | 0 |
| Économie Générale | 7 | 0 |
| Droit Administratif | 6 | 0 |
| Français | 5 | 0 |
| Finances Publiques | 5 | 0 |
| Droit du Travail | 3 | 0 |
| Droit Civil | 3 | 0 |
| GRH et Management | 3 | 0 |
| Comptabilité | 2 | 0 |
| Pédagogie | 2 | 0 |
| Droit Pénal | 2 | 0 |
| Informatique | 2 | 0 |
| Sciences Naturelles | 1 | 0 |
| Droit Fiscal | 0 | 0 |

### Problèmes critiques :
1. **96/147 questions sont des "ai_seed"** = pré-générées sans base de vrais sujets
2. **Seulement 36 questions "external_source"** = vrais sujets importés
3. **AUCUN chunk RAG par matière** sauf Actualités (via RSS) et Culture Gén
4. **AUCUN embedding** sur les 442 chunks existants (0/442)
5. **AUCUNE liaison question ↔ topic** (prep_question_topics vide)

---

## C. EDGE FUNCTIONS IA — État

| Edge Function | Déployée | Rôle | Utilisée ? |
|---------------|----------|------|------------|
| `prep-analyze-trends` | ✅ Oui | Analyse chunks + questions → détecte patterns → génère prédictions | **JAMAIS APPELÉE** (0 prédictions en DB) |
| `prep-generate-questions` | ✅ Oui | RAG + LLM → génère QCM | Oui (96 questions ai_seed) |
| `prep-tutor-chat` | ✅ Oui | Chat IA avec RAG contextuel | Oui |
| `prep-grade-assignment` | ✅ Oui | Correction IA des exercices | 0 corrections |
| `prep-ingest-document` | ✅ Oui | PDF/image → OCR → chunks → embeddings | Peu utilisée (24 chunks "content") |
| `prep-feed-actuality` | ✅ Oui | RSS → chunks actualité | ✅ Actif quotidien (418 chunks) |
| `prep-scan-subject` | ✅ Oui | Photo → OCR → correction IA | Inconnu |

---

## D. CHAÎNE D'APPRENTISSAGE — Analyse

### Ce qui DEVRAIT se passer (le design prévu) :

```
1. Admin importe des vrais sujets de concours (PDF, texte, JSON)
      ↓
2. prep-ingest-document → chunks + embeddings dans prep_doc_chunks
      ↓
3. prep-analyze-trends → analyse les patterns → remplit prep_topics + prep_topic_predictions
      ↓
4. prep-generate-questions utilise chunks (RAG) + prédictions pour générer des QCM ciblés
      ↓
5. Étudiants passent les quiz → prep_quiz_attempts
      ↓
6. Trigger trg_update_student_weaknesses → prep_student_weaknesses
      ↓
7. prep-generate-questions mode "adaptive" → questions ciblées sur les faiblesses
      ↓
8. Boucle de rétroaction : plus l'étudiant utilise, mieux l'IA cible
```

### Ce qui SE PASSE réellement :

```
1. Admin a importé 36 questions manuellement + 15 via JSON ← INSUFFISANT
2. prep-ingest-document a créé 24 chunks "content" ← TRÈS PEU
3. prep-analyze-trends n'a JAMAIS été appelée → 0 prédictions
4. prep-generate-questions génère des QCM SANS contexte RAG (0 embeddings)
5. 0 quiz attempts → le trigger ne se déclenche jamais
6. 0 faiblesses → le mode adaptatif ne peut pas fonctionner
7. La boucle est CASSÉE à l'étape 1 (pas assez de données)
```

---

## E. DIAGNOSTIC : POURQUOI L'IA N'APPREND PAS

### Cause racine #1 : PAS ASSEZ DE DONNÉES D'ENTRÉE
- **147 questions** dont 96 génériques → la base est trop petite pour identifier des patterns
- Il faudrait **500-1000+ questions** issues de VRAIS sujets de concours pour que l'analyse de tendances fonctionne
- Il faudrait des sujets tagués par **année**, **concours**, **matière**, **thème** pour détecter les cycles

### Cause racine #2 : prep-analyze-trends JAMAIS DÉCLENCHÉE
- L'Edge Function est déployée mais personne ne l'appelle
- Il n'y a pas de cron job pour la déclencher automatiquement
- Il n'y a pas de bouton admin pour la lancer
- Résultat : 0 prédictions, 0 patterns détectés

### Cause racine #3 : 0 EMBEDDINGS
- Les 442 chunks existants n'ont AUCUN embedding vectoriel
- La recherche sémantique (`app_prep_semantic_search`) ne retourne donc jamais rien
- Seul le fallback par nom (`app_prep_get_rag_chunks_by_name`) fonctionne

### Cause racine #4 : AUCUN USAGE ÉTUDIANT
- 0 quiz attempts = le système adaptatif ne peut pas apprendre
- 0 corrections IA = pas de feedback loop
- Le trigger `trg_update_student_weaknesses` existe (enabled=O) mais ne se déclenche jamais

### Cause racine #5 : prep-generate-questions NE CONSULTE PAS LES PRÉDICTIONS
- L'Edge Function ne lit PAS `prep_topic_predictions`
- Même si des prédictions existaient, elles ne seraient pas utilisées pour cibler la génération
- Le prompt ne mentionne pas les thèmes à forte probabilité

---

## F. RECOMMANDATIONS POUR ATTEINDRE L'OBJECTIF

### Phase A — Alimenter la machine (PRIORITÉ ABSOLUE)
1. **Importer massivement les vrais sujets** de concours : PDF scannés ou texte brut
   - Objectif minimum : 50 sujets complets (= ~500-1000 questions)
   - Via `app_admin_prep_import_questions_json` (0 token) ou `prep-ingest-document`
   - Tagger chaque question avec : année, concours_type, matière, thème
2. **Générer les embeddings** sur tous les chunks existants
   - Créer un cron ou script qui appelle OpenRouter embeddings en batch

### Phase B — Activer l'analyse de tendances
3. **Créer un cron job** ou bouton admin pour appeler `prep-analyze-trends` hebdomadairement
4. **Modifier prep-generate-questions** pour :
   - Lire `prep_topic_predictions` (thèmes à forte probabilité)
   - Injecter ces prédictions dans le prompt LLM
   - Générer des questions CIBLÉES sur les thèmes prédits

### Phase C — Boucle de rétroaction
5. **Taguer automatiquement les questions** aux topics (`prep_question_topics`)
6. **S'assurer que le trigger faiblesses fonctionne** quand les étudiants passent des quiz
7. **Connecter le scoring des actualités** aux prédictions de tendances

### Phase D — Dashboard apprentissage admin
8. **Créer un écran admin** montrant :
   - Les topics détectés avec leurs scores de probabilité
   - La couverture des matières (questions/chunks par matière)
   - Les gaps (matières sans contenu)
   - Un bouton "Analyser les tendances maintenant"

---

## G. RÉSUMÉ EN UNE PHRASE

**Le moteur d'apprentissage est construit (tables + Edge Functions + RPCs) mais il est à l'ARRÊT parce qu'il n'a pas été alimenté avec suffisamment de vrais sujets de concours, et l'analyse de tendances n'a jamais été déclenchée.**
