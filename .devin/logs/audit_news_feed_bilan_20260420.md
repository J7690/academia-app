# Audit Complet — Système d'Actualités Concours (prep-feed-actuality)
## Date: 20 Avril 2026

---

## 1. VERDICT GLOBAL

**Le dispositif EXISTE et est FONCTIONNEL.** Il tourne quotidiennement depuis le 6 avril 2026 et a accumulé **395 articles** injectés dans la base RAG du module Concours.

---

## 2. SOURCES RSS ACTIVES

| Source | Slug | URL RSS | Articles | Dernier fetch |
|--------|------|---------|----------|---------------|
| AIB (Agence d'Information du Burkina) | `aib` | https://www.aib.media/?feed=rss2 | **278** | 2026-04-20 05:00 UTC |
| Sidwaya | `sidwaya` | https://www.sidwaya.info/feed/ | **115** | 2026-04-20 05:00 UTC |
| RTB | `rtb` | https://www.rtb.bf/feed/ | **2** | 2026-04-20 05:00 UTC |

### Source supprimée
- **Lefaso.net** — supprimé via `deploy_remove_lefaso.py` (était un média privé, pas un média d'État)

### Observations
- **AIB** est la source la plus productive (278 articles, ~19/jour)
- **Sidwaya** fonctionne bien (115 articles, ~2/jour en moyenne après filtrage)
- **RTB** est quasi inopérante (2 articles seulement) — son flux RSS contient principalement du contenu vidéo (JT télévisé) avec très peu de texte exploitable

---

## 3. CRON JOB

| Job ID | Nom | Schedule | Actif |
|--------|-----|----------|-------|
| #6 | `prep-feed-actuality-daily` | `0 5 * * *` (05h00 UTC = 05h00 BF) | ✅ Oui |

### Historique d'exécution (7 derniers jours)
Toutes les exécutions du 14 au 20 avril 2026 : **status = succeeded** ✅

Le cron appelle l'Edge Function via `pg_net.http_post` → l'Edge Function scrape les 3 flux RSS → injecte les nouveaux articles.

---

## 4. EDGE FUNCTION `prep-feed-actuality`

### Statut : ✅ DÉPLOYÉE ET FONCTIONNELLE

**Test en direct (20 avril 2026 ~18h07 UTC) :**
```json
{
  "success": true,
  "total_fetched": 39,
  "total_injected": 21,
  "total_skipped": 18,
  "sources": [
    {"source": "aib", "fetched": 19, "injected": 19, "skipped": 0},
    {"source": "rtb", "fetched": 10, "injected": 0, "skipped": 10},
    {"source": "sidwaya", "fetched": 10, "injected": 2, "skipped": 8}
  ]
}
```

### Mécanisme de filtrage
1. **Filtrage par catégories** — 30+ catégories pertinentes (politique, économie, société, éducation, santé, droit, justice, sécurité, défense, agriculture, environnement, culture, sport, international...)
2. **Filtrage par longueur** — Articles < 50 caractères rejetés (élimine les articles vidéo RTB sans texte)
3. **Déduplication par URL** — Un article déjà injecté n'est pas réinjecté (table `prep_news_articles`, UNIQUE sur `article_url`)
4. **Nettoyage HTML** — Strip HTML, décode entités françaises (é, à, è, ê, â, ô, û, ï, ç)
5. **Troncature** — description 2000 chars, content 8000 chars, chunks 4000 chars

### Pipeline d'injection
```
RSS Feed → Parse XML (regex) → Filtre catégories → Filtre longueur → Dedup URL
→ INSERT prep_source_documents (doc_type='actualite', source_type='rss_feed')
→ INSERT prep_doc_chunks (chunk_type='actualite', subject_name='Actualités du Burkina Faso')
→ INSERT prep_news_articles (tracking/dedup)
```

---

## 5. DONNÉES ACCUMULÉES

| Table | Count |
|-------|-------|
| `prep_news_sources` | 3 |
| `prep_news_articles` | 395 |
| `prep_doc_chunks` (chunk_type='actualite') | 397 |
| `prep_source_documents` (doc_type='actualite') | 458 |
| Chunks RAG avec subject_name 'Actualités...' | 418 |

### Derniers articles injectés (20 avril 2026)
- "Conférences régionales du gouvernement : le premier ministre échange avec les forces vives du Yaadga" (5723 chars)
- "Créances dues à l'État : AJE somme les débiteurs de payer Plus de 107 milliards FCFA" (7266 chars)
- "Région de Yaadga: le chef du gouvernement galvanise les forces combattantes" (4000 chars)
- "SNC Bobo 2026: les préparatifs vont bon train dans le Bankui et dans le Sourou" (4578 chars)
- "Assemblée législative du Peuple: l'UNICEF salue les lois en faveur des enfants" (2315 chars)

---

## 6. CONSOMMATION PAR L'IA

### Comment les actualités alimentent le tuteur IA

**Chaîne complète :**
1. `prep-feed-actuality` injecte articles → `prep_doc_chunks` (chunk_type='actualite', subject_name='Actualités du Burkina Faso')
2. Quand l'étudiant pose une question au tuteur IA (`prep-tutor-chat`) :
   - D'abord : recherche sémantique via embeddings (si disponibles)
   - Si 0 résultat : **fallback RAG** via `app_prep_get_rag_chunks_by_name` → récupère les chunks par `subject_name` SANS embeddings
3. Le contexte RAG est injecté dans le prompt système : "CONNAISSANCES COMPLÉMENTAIRES — Utilise ces informations pour enrichir ta réponse de façon naturelle, sans citer de source."
4. Même mécanisme pour `prep-generate-questions` (génération de QCM)

### Limite actuelle
- Le sujet est transmis comme `'Général'` depuis Flutter (PrepAiTab) → l'Edge Function ne cible pas spécifiquement les actualités
- Les chunks actualité sont accessibles quand l'étudiant pose des questions sur l'actualité BF, mais pas automatiquement injectés dans toutes les conversations

---

## 7. ONGLETS MODULE CONCOURS (Flutter)

**8 onglets** : Accueil | Quiz | Exercices | Lives | IA Tutor | Sujets | Stats | Psychotech

- **IA Tutor** : Chat avec le tuteur IA qui utilise les chunks actualité via RAG fallback
- **Quiz** : Génération de questions qui peut puiser dans les chunks actualité
- Pas d'onglet dédié "Actualités" — les actualités sont consommées en arrière-plan par l'IA

---

## 8. POINTS FORTS ✅

1. **Automatique** — Le cron tourne chaque jour à 05h00 sans intervention humaine
2. **Fonctionnel** — 395 articles accumulés, 21 nouveaux injectés aujourd'hui
3. **Filtrage intelligent** — Catégories pertinentes, dédup, nettoyage HTML
4. **0 token consommé** — Pur fetch HTTP + SQL, pas d'appel IA
5. **Intégré au RAG** — Les chunks sont disponibles pour le tuteur IA et la génération de QCM
6. **Médias d'État couverts** — AIB (agence officielle), Sidwaya (quotidien national), RTB (télévision nationale)

## 9. POINTS FAIBLES / AMÉLIORATIONS POSSIBLES ⚠️

1. **RTB quasi inutile** — Seulement 2 articles en 2 semaines (contenu vidéo, pas de texte). Envisager de la désactiver ou de chercher une autre URL RSS.
2. **Pas d'embeddings** — Les chunks actualité n'ont PAS d'embeddings vectoriels, donc pas de recherche sémantique. Seul le fallback par nom fonctionne.
3. **Sujet "Général" côté Flutter** — Le PrepAiTab envoie `subject: 'Général'` → le RAG ne cible pas automatiquement les actualités. Un étudiant qui demande "Quelles sont les dernières nouvelles au BF?" obtiendrait le contexte, mais pas un étudiant qui demande une question de droit.
4. **Pas d'onglet Actualités** — Les actualités sont "invisibles" pour l'étudiant, il ne sait pas qu'elles alimentent l'IA.
5. **Lefaso.net supprimé** — C'était la source la plus riche (~50 articles/jour). Même si c'est un média privé, son contenu est très pertinent pour la préparation aux concours.
6. **Pas de monitoring** — Aucun dashboard admin pour voir les stats d'injection en temps réel.
