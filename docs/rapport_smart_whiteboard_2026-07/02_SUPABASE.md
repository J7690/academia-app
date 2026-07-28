# 02 — Supabase : la génération du storyboard v3

> Projet : `thevdfcwlcqzdoybfvgs`.
> Edge Function concernée : `whiteboard-generate-storyboard`.
> Déployée le 27/07/2026 depuis la racine `academia/` avec
> `supabase functions deploy whiteboard-generate-storyboard --use-api`.

---

## 1. Pourquoi intervenir sur la génération

L'utilisateur a été explicite : *« il faudrait intervenir depuis la génération des scènes, la
génération des narrations, la mise en scène »*.

Le raisonnement est juste : **aucune mise en scène ne peut sauver un storyboard plat.** Si le
storyboard ne dit pas *quels mots* sont importants, le moteur ne peut pas les faire ressortir.
S'il ne dit pas *quel rôle narratif* joue une scène, le moteur ne peut pas l'habiller
différemment. S'il n'y a qu'une narration par scène, la voix ne peut pas accompagner
précisément le bloc qui s'écrit.

D'où le **storyboard v3** : on enrichit le contrat de données pour donner au moteur de quoi
faire du montage.

---

## 2. Les trois nouveaux champs

### 2.1 `narration` **par bloc** — la contiguïté temporelle

**Avant (v2)** : une narration par scène. La voix récitait un paragraphe pendant que 3 blocs
s'écrivaient. L'étudiant entendait parler du bloc 3 alors que le bloc 1 s'affichait.

**Maintenant (v3)** : chaque bloc porte sa propre phrase de narration.

Extrait du prompt système :

> narration DE BLOC (TRES IMPORTANT, v3) : CHAQUE bloc DOIT avoir "narration" = 1 phrase
> (15 mots MAX) que le prof DIT pendant que ce bloc precis s'ecrit. C'est la **contiguite
> temporelle** : la voix accompagne exactement ce qui apparait. […] La narration de bloc
> REFORMULE (elle ne repete pas mot a mot le contenu ecrit).

Deux principes de psychologie cognitive sont ici encodés dans le prompt :
- **Contiguïté temporelle** (Mayer) : mot et image doivent être simultanés, sinon la mémoire
  de travail paie le coût de l'appariement.
- **Non-redondance** : la voix ne lit pas le texte écrit, elle le **reformule** — sinon les
  deux canaux se concurrencent au lieu de se compléter.

### 2.2 `beat` — le rôle narratif de la scène

Valeurs autorisées : `hook`, `concept`, `example`, `exercise`, `correction`, `recap`.

> beat : chaque scene DOIT avoir "beat" = role narratif : "hook" (accroche, scene 0
> UNIQUEMENT, avec une **question rhetorique**) | "concept" | "example" | "exercise" |
> "correction" | "recap" (**DERNIERE scene OBLIGATOIREMENT** : 3 a 5 points a retenir, blocs
> paragraph tres courts, un point par bloc).

C'est ce champ qui permet au moteur de **traiter différemment** une accroche, une correction
et un récapitulatif — exactement ce qu'un monteur ferait.

### 2.3 `key_words` — la matière de la typographie cinétique

> key_words : sur les blocs importants, ajoute "key_words" = tableau de 1 a 3 expressions
> COURTES (1 a 3 mots chacune) copiees **MOT POUR MOT** depuis le "content" du bloc. Ce sont
> les mots que la mise en scene fera RESSORTIR (typographie cinetique : plus gros, en
> couleur). **Choisis les mots qu'un prof ecrirait en rouge au tableau.**

La formulation « les mots qu'un prof écrirait en rouge » est délibérée : elle donne au modèle
un critère **intuitif et vérifiable**, bien plus efficace qu'une consigne abstraite du type
« choisis les termes saillants ».

---

## 3. Les contraintes de rythme ajoutées au prompt

> RYTHME : phrases de narration COURTES (15 mots max), ton direct et chaleureux, ~150 mots
> par minute. **Une respiration entre les idées vaut mieux qu'un flot continu.**

Ces contraintes agissent en amont de tout le reste : une phrase de 15 mots maximum garantit
mécaniquement qu'un bloc ne dure pas 20 secondes à l'écran, donc que la vidéo garde du rythme.

---

## 4. La philosophie de validation : **nettoyer, pas rejeter**

C'est la décision la plus importante de la vague E, et elle est **rétro-compatible par
construction**.

Un modèle de langage se trompe. S'il produit un `beat` inventé, un `key_words` qui ne figure
pas dans le contenu, ou une narration truffée de LaTeX, deux options existaient :

| Option | Conséquence |
|---|---|
| Rejeter la génération | L'étudiant perd ses crédits et n'a **aucune vidéo** pour une virgule mal placée |
| **Nettoyer le champ fautif** ✅ | L'étudiant a sa vidéo, simplement sans cet enrichissement |

Le code retenu, dans `validateStoryboard()` :

```typescript
// beat v3 : role narratif de la scene. Valeur inconnue -> on retire, le moteur
// rend la scene normalement (retro-compatible).
if ('beat' in s && !['hook','concept','example','exercise','correction','recap']
    .includes(s.beat as string)) delete s.beat;
```

```typescript
// key_words v3 : mots-cles de typographie cinetique. Chacun doit etre un
// EXTRAIT REEL du contenu (comme emphasis_target), 1 a 3 mots-cles max.
if ('key_words' in b) {
  const contentNorm = normalizeForMatch((b.content as string) ?? '');
  const kws = Array.isArray(b.key_words)
    ? (b.key_words as unknown[])
        .filter((k): k is string => typeof k === 'string')
        .map(k => k.trim())
        .filter(k => k.length >= 2 && k.length <= 40 && contentNorm.includes(normalizeForMatch(k)))
        .slice(0, 3)
    : [];
  if (kws.length > 0) b.key_words = kws; else delete b.key_words;
}
```

**Le filtre `contentNorm.includes(...)` est essentiel** : un `key_word` qui n'existe pas dans
le texte écrit ne pourrait pas être mis en couleur — le moteur ne saurait pas quel mot
colorer. On le retire donc silencieusement.

### Nettoyage anti-LaTeX de la narration
La voix off ne doit jamais lire de LaTeX. Les deux narrations (scène et bloc) subissent le
même nettoyage :

```typescript
b.narration = (b.narration as string)
  .replace(/\$+/g, ' ')
  .replace(/\\[a-zA-Z]+/g, ' ')
  .replace(/[{}^_]/g, ' ')
  .replace(/\s{2,}/g, ' ')
  .trim();
```

Le prompt exige par ailleurs les maths **en toutes lettres** dans la narration :
> « la limite de f de x quand x tend vers a », « l'intégrale de a à b de f de x d x »

---

## 5. Rétro-compatibilité — vérifiée

Tous les champs v3 (`beat`, `narration` de bloc, `key_words`) sont **optionnels** côté moteur.

| Cas | Comportement |
|---|---|
| Storyboard v2 existant (sans champs v3) | Rendu normal, sans typographie cinétique ni cartes récap |
| `beat` invalide | Champ supprimé, scène rendue normalement |
| `key_words` hors contenu | Champ supprimé, mots écrits en noir |
| Pas de `narration` de bloc | Repli sur la narration de scène (déjà présent dans `whiteboard_narration.py`) |

Aucun storyboard déjà en base ne casse. **Aucune migration nécessaire.**

---

## 6. Champs conservés des versions antérieures

| Champ | Portée | Rôle |
|---|---|---|
| `emphasis` + `emphasis_target` | bloc | Cercle / souligné / surlignage sur **2 à 8 mots exacts** — « un professeur entoure UN MOT CLÉ, pas un paragraphe ». `highlight` reste en place, `circle` et `underline` s'effacent |
| `write_speed` | bloc | `slow` pour une définition (le prof articule), `fast` pour une liaison |
| `recall` | scène | `{ target: <order>, kind: 'circle' }` — la caméra **remonte** vers une notion antérieure, la ré-encercle, puis redescend. À utiliser 0 à 2 fois par vidéo |
| `transition` | scène | Objet `{ kind: 'fade' \| 'slide' \| 'wipe' }` |

---

## 7. Garde-fous structurels (inchangés)

| Règle | Valeur |
|---|---|
| Nombre de scènes | 5 à 10 |
| Blocs par scène | 2 à 4 recommandés, **10 maximum** (rejet au-delà) |
| Taille du storyboard | **100 Ko maximum** |
| Types de blocs valides | `title`, `paragraph`, `formula`, `definition`, `exercise`, `correction`, `diagram`, `graph` |
| Bloc vide | Rejeté |
| `style` manquant | Rempli par défaut (`fontSize: 16, fontWeight: normal, color: #000000`) |

Les blocs `formula` doivent être du **LaTeX KaTeX pur** ; les blocs `diagram` du **Mermaid
valide**.

---

## 8. Crédits

La logique de **réservation puis remboursement** des crédits est inchangée : les crédits sont
réservés avant l'appel au modèle et remboursés si la génération échoue. La philosophie
« nettoyer plutôt que rejeter » réduit mécaniquement le nombre de remboursements — et surtout
le nombre de déceptions.

---

## 9. Storage

Deux objets par job de rendu dans le bucket vidéo :

| Objet | Quand | Rôle |
|---|---|---|
| Aperçu (`_preview`) | ~15 s après le début du rendu | Lu immédiatement par l'app |
| MP4 complet | à la fin du rendu | Remplace l'aperçu dans le lecteur |

⚠️ **Point de vigilance rencontré** : l'application ne pouvait pas *lister* le bucket pour
détecter l'aperçu (les policies RLS ne l'autorisent pas). La solution retenue est une **sonde
HEAD sur l'URL publique** — voir `03_FLUTTER.md` §3.
