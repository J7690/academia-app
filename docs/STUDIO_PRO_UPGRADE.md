# Smart Whiteboard — Passage au niveau PRO (retours vidéo)

Suite à ta première vidéo animée, voici la mise à niveau : combiner ce que font
**GoodNotes / CapCut / Canva** avec notre stack, et l'automatiser dès la génération —
sans que l'étudiant touche à quoi que ce soit.

## 1. Tes retours → ce qui a été corrigé (moteur)

| Retour | Correctif appliqué |
|---|---|
| Contenu collé en haut | Contenu **centré verticalement** qui remplit la feuille (`Scene.tsx`) |
| Polices trop petites | Titre 92px, texte 46px, formules/blocs 40-46px (`blocks.tsx`) |
| Lignes du cahier peu visibles | Lignes **bleu cahier 2px** bien marquées + **marge rouge** verticale (`theme.ts`, `Scene.tsx`) |
| Pas d'annotations (encercler une notion) | **Annotations manuscrites animées** : cercle / souligné / surlignage (`Annotation.tsx`) |
| Pas d'écriture manuscrite | Titres en police manuscrite **Caveat** avec tracé progressif |
| Voix robotique | Ralentissement diction + voir §4 (probable repli Piper) |

## 2. Comparaison GoodNotes / CapCut / Canva → notre implémentation

| Fonction (référence) | Chez eux | Chez nous (auto-hébergé, 0 crédit) |
|---|---|---|
| Écriture manuscrite | GoodNotes | Police Caveat + tracé progressif (option `@remotion/paths` pour lettrage SVG) |
| Entourer / souligner / surligner | GoodNotes, Canva | **RoughNotation-like** maison (`Annotation.tsx`) — cercle/souligné/surlignage animés |
| Typographie animée (kinetic) | CapCut | Blocs en fondu/scale/pop + révélation ligne par ligne |
| Transitions de scènes | CapCut | `@remotion/transitions` (slide / fondu / wipe) |
| Zooms cinématiques | CapCut | Ken Burns + `@remotion/motion-blur` |
| Effets lumineux | CapCut, Canva | GlowSweep + halo (`effects.tsx`), option `@remotion/skia` |
| Illustrations / photos | Canva | Pexels (libre) en Ken Burns |
| Maths animées | — | **Manim** (formules qui s'écrivent) |
| Voix off | CapCut (payant) | **Kokoro** (auto-hébergé, gratuit) + sous-titres |

Principe : les briques payantes de CapCut/Canva sont **remplacées par de l'open-source
qui tourne sur ton Kamatera** → même rendu, coût par vidéo ≈ 0.

## 3. Les INSTRUCTIONS injectées dans la génération (déployé, v34)

Le générateur IA produit maintenant automatiquement, à partir du sujet de l'étudiant :
- **Structure pro** : UNE idée maîtresse par scène, titre bref, textes **courts** (ils
  s'affichent en très grand). Fini les pavés collés en haut.
- **narration** par scène : 1-2 phrases de voix off naturelles (ton prof).
- **transition** par scène (objet `{kind}` — compatible app).
- **emphasis** : sur LE bloc clé de chaque scène, une annotation manuscrite
  (`circle` / `underline` / `highlight`) qui **met en valeur la notion**.

→ C'est ça, la symbiose : l'étudiant tape « économie », l'IA structure une leçon
« montable », et le moteur l'anime au niveau studio, sans intervention.

## 4. La voix « robotique » — diagnostic

Le plus probable : la voix off est tombée sur le **repli Piper** (Kokoro pas joignable
au moment du rendu). À vérifier via la balise :
```sql
select components->>'kokoro_reachable', components->>'tts_engine' from app.whiteboard_engine_health;
```
Pistes :
1. **Confirmer Kokoro actif** (conteneur `kokoro-fastapi` up, `KOKORO_URL` correct).
2. Choisir une **meilleure voix FR** de Kokoro (`KOKORO_VOICE`) — teste les voix `ff_*`.
3. `KOKORO_SPEED=0.95` (déjà par défaut) pour une diction plus posée.
4. Pour une voix **encore plus naturelle** en français : **StyleTTS 2** (licence MIT,
   commerciale OK) est l'upgrade recommandé si Kokoro ne suffit pas. (XTTS v2 = licence
   NON-commerciale → à éviter pour l'app.)

## 5. Pour VOIR ces améliorations (à exécuter sur le VPS)
Les fichiers du moteur ont changé. Sur le VPS :
```bash
rsync -a whiteboard_engine_remotion/ root@<VPS>:/opt/whiteboard-engine-remotion/
cd /opt/whiteboard-engine-remotion && npm ci      # (roughjs non requis : annotations maison)
node render.mjs --storyboard src/sample_storyboard.json --out /tmp/pro.mp4
```
Puis relancer un rendu `engine="remotion"` depuis l'app. (Rappel : Claude ne peut pas
exécuter ceci — pas d'accès VPS.)

## Sources
- [Kinetic typography 2026](https://www.ikagency.com/graphic-design-typography/kinetic-typography/) · [Explainer video techniques 2026](https://pexo.ai/blog/explainer-video-styles-3897)
- [RoughNotation (annotations manuscrites)](https://roughnotation.com/) · [rough.js](https://github.com/rough-stuff/rough)
- [Best self-hosted TTS FR 2026 (Kokoro/StyleTTS2)](https://localaimaster.com/blog/best-local-tts-models) · [Kokoro-82M](https://huggingface.co/hexgrad/Kokoro-82M)
