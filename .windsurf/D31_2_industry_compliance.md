# D31_2_industry_compliance.md

**Date :** 2026-06-30  
**Sujet :** Comparaison du pipeline Smart Whiteboard avec les standards industriels après correction D31.2

---

## Résultat du test end-to-end

| Source | Durée pour "dérivés d'une fonction" | Statut |
|---|---|---|
| Storyboard (`duration_ms`) | 64 000 ms (8 scènes) | Référence |
| Worker reçu | 64 000 ms | ✅ |
| MP4 réel (ffprobe) | 64 000 ms | ✅ |
| Supabase (`whiteboard_renders.duration_ms`) | 64 000 ms | ✅ |

**Tolérance industrielle :** ±500 ms.  
**Résultat :** ✅ **0 ms d'écart** entre les 4 mesures.

---

## Comparaison avec les plateformes leaders

| Plateforme | Qui fixe la durée | Comment |
|---|---|---|
| **Canva Video** | Scène / timeline | L'utilisateur ajuste la durée de chaque scène ; l'audio/voiceover est aligné sur la timeline. |
| **CapCut** | Clip / TTS | Le TTS génère un clip audio de durée réelle ; la timeline visuelle est ajustée en conséquence. |
| **Explain Everything** | Slide + timeline | Chaque slide possède sa propre timeline définie par l'enregistrement et les interactions. |
| **Khan Academy** | Monteur humain | Les vidéos sont montées manuellement avec narration ; la durée dépend du script. |
| **GoodNotes** | N/A | Pas de génération vidéo automatique. |

---

## Standard industriel retenu

**Storyboard → Timeline → Renderer**

1. Le **storyboard** fournit la durée initiale de chaque scène (`duration_ms`).
2. La **timeline** (ou le worker) assemble les segments selon ces durées.
3. Le **renderer** (FFmpeg) exécute les durées sans les décider.
4. En présence de TTS/audio, la durée finale est recalculée à partir de la longueur audio réelle.

---

## Conformité de notre pipeline après D31.2

| Critère | Avant D31.2 | Après D31.2 | Standard |
|---|---|---|---|
| Durée définie par le storyboard | ❌ Ignorée | ✅ Utilisée | ✅ |
| Durée hardcodée par FFmpeg | ✅ 5s/scène | ❌ Supprimée | ✅ |
| Durée enregistrée correctement | ❌ `len(scenes)*5000` | ✅ `sum(duration_ms)` | ✅ |
| Dernière image dupliquée | ✅ Oui (durée +1 scène) | ❌ Non | ✅ |
| Durée MP4 = durée storyboard | ❌ Écart de 6–20s | ✅ Identique | ✅ |
| TTS ajuste la durée finale | ❌ TTS absent | N/A (prévu D31.5+) | ✅ (futur) |

---

## Verdict

**Le pipeline Smart Whiteboard est maintenant conforme au standard industriel de base :**

- La durée est définie par le storyboard.
- FFmpeg ne décide plus de la durée.
- Le MP4 reflète fidèlement le storyboard.

**La seule étape manquante pour être pleinement conforme à l'industrie TTS-driven** est l'ajustement automatique de la durée finale en fonction de la narration audio réelle (D31.5+).

---

## Sources

- Canva Help — *Trim videos and change scene duration* : https://www.canva.com/help/trim-videos/
- CapCut — *Text to Speech* : https://www.capcut.com/tools/text-to-speech
- Explain Everything Help — *Introduction to Recording* : https://help.explaineverything.com/hc/en-us/articles/360013332774
- Khan Academy Blog — *How Khan Academy Videos Are Made* : https://blog.khanacademy.org/how-khan-academy-videos-are-made-to-help-you-learn/
