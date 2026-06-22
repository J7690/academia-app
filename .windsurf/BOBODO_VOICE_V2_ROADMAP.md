# BOBODO VOICE V2 — ROADMAP

## Date : 14 Juin 2026

---

## Mission 1 — Plan latence 3–5s (sans GPU)

### Décomposition actuelle (mesurée)

| Étape | Durée actuelle | Incompressible ? |
|---|---|---|
| Silence detection | 0.8s | Réductible à 0.5s |
| **Whisper Small (STT)** | **3.0–3.5s** | **Incompressible** (CPU 4 cœurs, Small int8) |
| Edge Function (Bobodo IA) | 2.9s | Partiellement réductible |
| TTS (gTTS) | 1.0–2.5s | **Fortement réductible** |
| WebSocket send | <0.05s | Incompressible |
| **TOTAL** | **7.5–9.0s** | |

### Plan de réduction

| # | Action | Gain attendu | Nouveau total | Effort |
|---|---|---|---|---|
| 1 | **Remplacer gTTS par edge-tts** | -1.0 à -2.0s | ~6.5s | 1h |
| 2 | **Réduire silence_threshold 800→500ms** | -0.3s | ~6.2s | 1 min |
| 3 | **Streaming TTS** (envoyer audio par chunks) | -0.5s perçu | ~5.7s perçu | 3h |
| 4 | **Streaming LLM** (Edge Function stream → TTS en parallèle) | -1.5s | ~4.2s | 4h |
| 5 | **VAD côté client** (silence détecté côté Flutter, pas serveur) | -0.3s | ~3.9s | 2h |

### Projection réaliste

| Scénario | Latence | Actions requises |
|---|---|---|
| **V1 actuel** | 7.5–11s | — |
| **V2 simple** (actions 1+2) | **~6.0s** | 1h travail |
| **V2 intermédiaire** (1+2+3) | **~5.5s perçu** | 4h travail |
| **V2 complet** (1+2+3+4+5) | **~3.5–4.0s** | 10h travail |

### Ce qui est impossible sans GPU

| Optimisation | Pourquoi impossible |
|---|---|
| STT < 2.5s avec Small | CTranslate2 sur CPU = 3s minimum pour Small |
| STT < 1s | Nécessite GPU ou service cloud (Deepgram ~500ms) |
| Whisper Large | 20s+ sur CPU — totalement exclu |

**Verdict : 3.5–4s est atteignable sans GPU via streaming LLM→TTS + edge-tts + VAD client.**

---

## Mission 2 — Comparatif TTS

### gTTS (actuel)

| Métrique | Valeur |
|---|---|
| Latence mesurée | 0.6–2.5s (dépend longueur + réseau Google) |
| Qualité voix | Correcte, robotique |
| Dépendance | **Réseau** (appelle translate.google.com) |
| Offline | ❌ Non |
| Langues | Français ✅ |
| Coût | Gratuit |
| Risque | Google peut bloquer/rate-limit |

### Edge-TTS (Microsoft)

| Métrique | Valeur attendue |
|---|---|
| Latence attendue | **0.2–0.8s** (streaming, serveur Microsoft edge) |
| Qualité voix | **Excellente** (voix neuronales Azure) |
| Dépendance | Réseau (mais API officielle, pas de scraping) |
| Offline | ❌ Non |
| Langues | Français ✅ (plusieurs voix : Denise, Henri, Sylvie) |
| Coût | **Gratuit** (utilise le même moteur qu'Edge browser) |
| Streaming | ✅ OUI (chunks audio en temps réel) |
| Risque | Très faible (API Microsoft stable) |
| Installation | `pip install edge-tts` |

### Piper (local)

| Métrique | Valeur attendue |
|---|---|
| Latence attendue | **0.1–0.4s** (local, pas de réseau) |
| Qualité voix | Moyenne (voix VITS, moins naturelle) |
| Dépendance | **Aucune** (100% local) |
| Offline | ✅ OUI |
| Langues | Français ✅ (voix fr_FR-medium) |
| Coût | Gratuit |
| Streaming | ❌ Non (génère le fichier entier) |
| RAM supplémentaire | ~100–200 MB |
| Risque | Qualité vocale inférieure |
| Installation | Binaire + modèle voix |

### Recommandation

| Critère | gTTS | Edge-TTS | Piper |
|---|---|---|---|
| Latence | ⚠️ 0.6–2.5s | ✅ 0.2–0.8s | ✅ 0.1–0.4s |
| Qualité | ⚠️ Robotique | ✅ Naturelle | ⚠️ Moyenne |
| Fiabilité | ⚠️ Scraping | ✅ API officielle | ✅ Local |
| Streaming | ❌ | ✅ | ❌ |
| Offline | ❌ | ❌ | ✅ |

**Cible V2 : Edge-TTS**

- Gain latence : -1.0 à -2.0s (vs gTTS)
- Qualité voix : nettement supérieure (voix neuronale Microsoft)
- Streaming : permet l'envoi progressif → latence perçue réduite
- Coût : gratuit
- Risque : très faible

**Fallback : Piper** — si besoin d'une solution 100% offline ou si Edge-TTS est indisponible.

---

## Mission 3 — Écarts UX vs ChatGPT Voice

### Matrice de comparaison

| Fonctionnalité | ChatGPT Voice | Bobodo V1 | Écart | Impact UX |
|---|---|---|---|---|
| **Barge-in** (interrompre la réponse) | ✅ Immédiat | ❌ Impossible | **Critique** | L'user doit attendre la fin |
| **Interruption TTS** | ✅ Coupe immédiatement | ❌ Audio envoyé en bloc | **Élevé** | Réponses longues = frustration |
| **Écoute continue** | ✅ Toujours actif | ❌ 1 envoi = 1 attente | **Élevé** | Pas de dialogue naturel |
| **Latence perception** | ~1–2s | 7.5–11s | **Élevé** | Attente perceptible |
| **Reprise automatique** | ✅ | ❌ (client doit relancer) | **Modéré** | Coupure réseau = relance manuelle |
| **Détection fin de phrase** | ✅ Instantanée (VAD local) | ⚠️ Timeout 800ms serveur | **Modéré** | Pause forcée |
| **Multi-tour fluide** | ✅ Continu | ✅ Fonctionne (8s entre tours) | Faible | OK pour assistant éducatif |
| **Qualité voix** | ✅ Naturelle | ⚠️ gTTS robotique | **Modéré** | Perception qualité |
| **Mémoire conversation** | ✅ | ✅ (via Edge Function) | Aucun | Équivalent |

### Classement par impact

| # | Écart | Impact | Corrigeable V2 ? |
|---|---|---|---|
| 1 | **Latence** (7.5s vs 1.5s) | ★★★★★ | Partiellement (→ 3.5–4s) |
| 2 | **Barge-in** | ★★★★☆ | Oui (streaming TTS + flag interruption) |
| 3 | **Qualité voix** | ★★★☆☆ | Oui (edge-tts) |
| 4 | **Écoute continue** | ★★★☆☆ | Complexe (VAD client + pipeline continu) |
| 5 | **Interruption TTS** | ★★★☆☆ | Oui (streaming audio + cancel) |
| 6 | **Auto-reconnexion** | ★★☆☆☆ | Oui (Flutter WebSocket reconnect) |
| 7 | **VAD local** | ★★☆☆☆ | Oui (flutter_sound + silence detect) |

---

## Mission 4 — Observabilité production

### Métriques pilote

| Métrique | Source | Seuil normal | Seuil alerte |
|---|---|---|---|
| Service actif | `systemctl is-active` | `active` | `inactive` → restart |
| RAM | `systemctl status` | < 1 GB | > 1.5 GB |
| Sessions actives | Log `Active: N` | 0–5 | > 10 |
| Latence STT | Log `STT_LATENCY` | < 5 000 ms | > 8 000 ms |
| Erreurs WS | Log `error` count | 0 | > 5/heure |
| Transcriptions/heure | Log `Transcription:` count | Variable | < 1 (service mort) |
| Uptime | `systemctl show -p ActiveEnterTimestamp` | Continu | Restart inattendu |

### Dashboard minimal (cron + fichier log)

```bash
# /opt/bobodo-vocal/monitor.sh (toutes les 5 min via cron)
#!/bin/bash
STATUS=$(systemctl is-active bobodo-vocal)
MEM=$(systemctl show bobodo-vocal -p MemoryCurrent | cut -d= -f2)
SESSIONS=$(journalctl -u bobodo-vocal --since='5 min ago' | grep -c 'Registered session')
ERRORS=$(journalctl -u bobodo-vocal --since='5 min ago' | grep -ci 'error')
echo "$(date) | status=$STATUS | mem=$MEM | sessions=$SESSIONS | errors=$ERRORS" >> /var/log/bobodo-monitor.log

if [ "$STATUS" != "active" ]; then
    systemctl restart bobodo-vocal
    echo "$(date) | AUTO-RESTART" >> /var/log/bobodo-monitor.log
fi
```

### Alertes recommandées

| Condition | Action | Implémentation |
|---|---|---|
| Service down | Restart auto | `Restart=always` dans systemd |
| RAM > 1.5 GB | Log + alerte | Script cron |
| 0 transcriptions en 30 min (si users actifs) | Investigation | Script cron |

---

## Mission 5 — Roadmap V2

### P0 — Indispensables (avant 1000 users)

| # | Action | Effort | Risque | Gain UX |
|---|---|---|---|---|
| 1 | Remplacer gTTS par edge-tts | 1h | Très faible | Latence -1.5s + voix naturelle |
| 2 | Ajouter `Restart=always` systemd | 5 min | Nul | Disponibilité auto |
| 3 | Script monitoring cron | 30 min | Nul | Détection pannes |
| 4 | Auto-reconnexion WS côté Flutter | 2h | Faible | Résilience réseau mobile |

### P1 — Importantes (V2 core)

| # | Action | Effort | Risque | Gain UX |
|---|---|---|---|---|
| 5 | Streaming LLM → TTS (pipeline parallèle) | 4h | Moyen | Latence perçue -1.5s |
| 6 | Barge-in (interruption réponse) | 3h | Moyen | UX conversationnelle naturelle |
| 7 | VAD côté client (Flutter silence detection) | 2h | Faible | Réactivité +0.3s |
| 8 | Silence threshold dynamique | 1h | Faible | Adaptabilité |

### P2 — Confort (post-1000 users)

| # | Action | Effort | Risque | Gain UX |
|---|---|---|---|---|
| 9 | Écoute continue (multi-phrase sans relance) | 6h | Élevé | Mode conversation naturel |
| 10 | Indicateurs visuels avancés (waveform, état) | 3h | Nul | Polish UX |
| 11 | Fallback STT cloud (Deepgram) si latence > seuil | 4h | Moyen | Latence <2s (payant) |
| 12 | Dashboard web monitoring temps réel | 6h | Nul | Ops |
| 13 | Fine-tuning Whisper Small (corpus Academia) | 20h+ | Élevé | WER -30% |

---

## Livrable final

### 1. Ce qui doit être fait avant 1000 utilisateurs

| # | Action | Effort total |
|---|---|---|
| 1 | Edge-TTS (remplacer gTTS) | 1h |
| 2 | Restart=always systemd | 5 min |
| 3 | Monitoring cron | 30 min |
| 4 | Auto-reconnexion Flutter | 2h |
| **Total** | | **~3.5h** |

### 2. Ce qui peut attendre après 1000 utilisateurs

- Streaming LLM→TTS
- Barge-in
- VAD client
- Écoute continue
- Dashboard monitoring
- Fallback cloud STT
- Fine-tuning Whisper

### 3. Temps estimé pour V2

| Version | Contenu | Effort |
|---|---|---|
| **V2 simple** (P0) | Edge-TTS + monitoring + reconnexion | **~3.5h** |
| **V2 intermédiaire** (P0 + P1 partiel) | + streaming + barge-in | **~10h** |
| **V2 complet** (P0 + P1 + P2 partiel) | + écoute continue + VAD | **~25h** |

### 4. Gain utilisateur attendu

| Version | Latence | Qualité voix | UX |
|---|---|---|---|
| **V1 actuel** | 7.5–11s | Robotique (gTTS) | Fonctionnel |
| **V2 simple** | **~6.0s** | **Naturelle** (edge-tts) | Amélioré |
| **V2 intermédiaire** | **~4.0s perçu** | Naturelle + streaming | **Fluide** |
| **V2 complet** | **~3.5s** + barge-in | Naturelle + interruptible | **Proche ChatGPT** |

### 5. Décision

## **MAINTIEN V1 PENDANT LE PILOTE**

**Justification :**
- V1 est validé, stable, et suffisant pour 500 étudiants
- Les P0 (edge-tts, monitoring, reconnexion) peuvent être implémentés **en parallèle** du pilote sans interruption de service
- Aucun correctif bloquant n'est nécessaire avant le lancement
- Le pilote produira des données réelles (usage, feedback) qui guideront les priorités V2

**Plan :**
1. **Semaine 1** : Lancer pilote avec V1
2. **Semaine 1–2** : Implémenter P0 en parallèle (edge-tts, monitoring)
3. **Semaine 3–4** : Déployer V2 simple (upgrade transparent)
4. **Mois 2** : Évaluer feedback → décider P1
