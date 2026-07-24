# Charte visuelle & organigramme des boutons — Feed Challenge (cible « habitudes TikTok »)

**Date :** 22 juillet 2026
**Objet :** réorganiser les boutons du feed Challenge pour épouser les réflexes TikTok/Facebook, **mettre le téléchargement en avant** (moteur de croissance : chaque vidéo téléchargée est filigranée Academia et partagée à l'extérieur), et intégrer proprement les modules à venir (Lives, Jeux, Duo, Compétitions, Challenges).
**Nature :** proposition (charte + organigramme + plan). Aucune modification de code appliquée.

---

## 1. Objectif

Que l'utilisateur qui a l'habitude de TikTok se sente **immédiatement chez lui** : mêmes emplacements, mêmes tailles, même logique de gestes. Et que le bouton **Télécharger/Enregistrer** soit visible et désirable, pour transformer chaque partage externe en publicité gratuite pour Academia.

---

## 2. Diagnostic de l'existant

**Barre d'actions (colonne droite), aujourd'hui — 5 actions :** ⋯ Menu · 💬 Commentaires · ❤️ Likes · 🏆 Rang · ↗️ Partage.
**Nav basse, aujourd'hui — 6 entrées :** Accueil · Challenges · ➕ (créer, central) · Jeux · Live · Profil.

Problèmes :

- **Le téléchargement est enterré** dans le menu « ⋯ » (`student_challenges_tab.dart`, ~l. 3310). Faible découvrabilité → peu de partages externes → on se prive du principal levier de notoriété.
- **Pas d'avatar auteur + bouton Suivre** dans la barre : c'est le point d'ancrage social n°1 de TikTok (identité créateur, abonnement). Son absence casse le réflexe.
- **Le « Rang 🏆 » occupe une place primaire** alors que c'est une info secondaire : il encombre la barre.
- **6 entrées en nav basse** (TikTok en a 5) et **Duo/Compétitions absents** de l'architecture. Le ➕ n'est pas au centre exact.
- Le **Favori (⭐ Save)** — présent chez TikTok et Facebook — est caché dans « ⋯ ».

---

## 3. Ce que font TikTok & Facebook (références actualisées)

- **Barre d'actions verticale à droite**, du haut vers le bas : **avatar auteur (+ suivre) → J'aime → Commenter → Enregistrer (favori) → Partager → disque audio rotatif**. Ce sont les actions primaires, placées là où le pouce les atteint le plus facilement.
- **Nav basse à 5 entrées** avec un **➕ créer central proéminent** (Accueil · Découvrir/Amis · ➕ · Boîte de réception · Profil).
- **Safe zones** : garder le contenu utile hors des **~120 px à droite** (barre d'actions) et **~300 px en bas** (légende + nav). Le filigrane/logo, lui, peut circuler puisqu'il est mobile.
- Sur TikTok, « Enregistrer la vidéo » vit dans le **panneau Partager** ; Academia peut légitimement s'en écarter et **exposer un bouton dédié**, car la diffusion externe de vidéos filigranées est un objectif produit assumé.

---

## 4. Principes directeurs

1. **Réflexes préservés** : même ordre, mêmes zones, mêmes tailles que TikTok. On ne réinvente pas, on adopte.
2. **Barre courte** : 5 actions d'engagement maximum + avatar + « ⋯ ». Tout le reste passe en secondaire.
3. **Téléchargement désirable** : bouton dédié, accent vert marque, libellé « Enregistrer ». C'est le seul élément où l'on se démarque volontairement de TikTok.
4. **Immersion** : vidéo plein écran, fonds transparents, dégradé bas léger pour la lisibilité (déjà réduit à 120 px).
5. **Cohérence de marque** : vert Academia (`#1EA75C` → `#A3D65C`) pour les accents et le ➕ ; blanc + ombre légère pour les icônes sur vidéo.

---

## 5. Organigramme des boutons (architecture cible)

```
FEED CHALLENGE (plein écran, immersif — écran d'accueil)
│
├─ HAUT : sélecteur de flux (comme « Abonnements | Pour toi » TikTok)
│    └─ Pour toi  ·  Challenges  ·  Live
│
├─ DROITE : barre d'actions (haut → bas)
│    ├─ 1. Avatar auteur  ⊕ Suivre        (social / abonnement)
│    ├─ 2. ❤️  J'aime            (+ compteur)
│    ├─ 3. 💬  Commenter          (+ compteur)
│    ├─ 4. ⭐  Enregistrer/Favori (+ compteur)   ← sortir du menu ⋯
│    ├─ 5. ⬇️  TÉLÉCHARGER  «Enregistrer»  ← MIS EN AVANT (accent vert)
│    ├─ 6. ↗️  Partager           (+ compteur)
│    └─ 7. ⋯  Plus  → Signaler · Rang détaillé · (Propriétaire : autoriser DL, corbeille, supprimer)
│
├─ BAS-GAUCHE : méta  → @auteur · titre (1 ligne) · signal 🎯/⚔️ · récompense · (rang, puce discrète)
│
└─ BAS : navigation principale (5 entrées, ➕ central)
     ├─ 🏠 Accueil        → le feed
     ├─ 🏆 Arène          → hub compétitif : Challenges · Duo · Compétitions/Tournois · Classements · Lives programmés
     ├─ ➕ Créer          → CENTRAL, proéminent → Vidéo · Duo · Live · (participer à un Challenge)
     ├─ 🎮 Jeux           → Economia (Market Master, Consumer Choice, Firm Tycoon, Market Structures)
     └─ 👤 Profil         → profil social (vidéos, abonnés, rangs, récompenses)
```

**Où vivent les 5 modules demandés :**

- **Challenges** : cœur du feed (segment « Challenges » en haut) + liste détaillée dans **Arène**.
- **Lives** : segment « Live » en haut du feed **et** section « Lives programmés » dans **Arène** ; création via ➕ → Live.
- **Jeux** : onglet dédié en nav basse (module Economia, identité noir/or).
- **Duo** : mode de **création** (➕ → Duo, façon « Duet » TikTok) + section dédiée dans **Arène**.
- **Compétitions** : sous **Arène** (tournois, brackets, saisons) ; un concours en cours peut apparaître dans le feed avec le signal ⚔️ Concours.

Ce regroupement fait passer la nav basse de **6 → 5** entrées (règle TikTok) sans rien perdre : les modes compétitifs sont réunis dans **Arène** au lieu d'être éparpillés.

---

## 6. Charte visuelle (tailles, emplacements, espacements, couleurs, états)

**Barre d'actions (droite)**

- Glyphe d'icône **30 px** (28–32) ; cible tactile **44–48 px**. Espacement vertical **15–18 px** entre items.
- Compteur sous chaque icône : **11–12 px**, blanc à 90 %.
- Marge droite **8–12 px** ; barre ancrée en bas, base ~**78 px** au-dessus du bord (au-dessus de la nav).
- Icônes **blanches** + ombre portée douce (lisibilité sur vidéo claire). Like actif = **rouge**.
- **Avatar** : cercle **44–48 px**, bordure blanche 2 px ; pastille ⊕ Suivre **18 px** vert `#1EA75C` en bas.
- **Bouton Télécharger (mis en avant)** : cercle plein **48 px** vert `#1EA75C`, glyphe ⬇️ blanc **26 px**, libellé « Enregistrer » **11 px** en `#A3D65C`. C'est le seul bouton « rempli » de la barre → l'œil y va.

**Navigation basse**

- Fond **noir**, icônes **24 px**, libellés **10 px**. Actif = **vert** `#1EA75C`, inactif = blanc 60 %.
- ➕ **central** : pavé **46 × 34 px**, radius 9, vert plein (ou dégradé marque existant), glyphe blanc 24 px.

**Zones & lisibilité**

- Respecter les **safe zones** : méta hors des **120 px** de droite ; contenu clé hors des **~200 px** du bas.
- Dégradé bas **~120 px** (déjà en place) pour détacher texte/icônes du fond.
- Titre sur **1 ligne** (déjà fait), @auteur **15 px** / 500, méta **12 px**.

**Règles de marque**

- Accent unique **vert Academia** (`#1EA75C` plein, `#A3D65C` clair). Éviter de multiplier les couleurs d'accent.
- Deux graisses seulement (regular / medium). Sentence case partout.

---

## 7. Mise en avant du téléchargement — 2 options

- **Option A (recommandée) — bouton dédié sur la barre.** ⬇️ « Enregistrer » en accent vert, entre Favori et Partager. Découvrabilité maximale → diffusion externe maximale. Léger écart volontaire vs TikTok, justifié par l'objectif de notoriété.
- **Option B — TikTok strict.** Pas de bouton dédié ; « Enregistrer la vidéo » devient **le 1er choix, mis en avant**, dans le panneau Partager. Barre 100 % pure TikTok, découvrabilité un cran en dessous.

Recommandation : **A**. On assume que le téléchargement filigrané est un canal d'acquisition.

---

## 8. Mapping d'implémentation (par phases)

Fichier principal : `academia_app/lib/features/student/tabs/student_challenges_tab.dart`.

**Phase 1 — Barre d'actions (impact max, risque faible)**
- Sortir **Télécharger** du menu ⋯ (l. ~3310) → bouton dédié accent vert dans la colonne (build ~l. 3245-3555).
- Sortir **Favori ⭐** du menu ⋯ → action visible.
- Ajouter **Avatar auteur + Suivre** en tête de barre (nécessite l'auteur dans le modèle vidéo + une RPC `follow` si absente — à auditer).
- Rétrograder **Rang 🏆** : puce discrète près de la méta (bas-gauche) au lieu de la barre.
- Ordre final barre : Avatar · ❤️ · 💬 · ⭐ · ⬇️ · ↗️ · ⋯.

**Phase 2 — Navigation basse (6 → 5)**
- Fusionner Challenges + Live (et futurs Duo/Compétitions) dans un hub **Arène** (`buildNavItem`, ~l. 1588-1710).
- Garder ➕ **central**. Onglets : Accueil · Arène · ➕ · Jeux · Profil.

**Phase 3 — Sélecteur de flux en haut**
- Ajouter « Pour toi · Challenges · Live » (segment style TikTok) en tête de feed.

**Phase 4 — Écran Arène (hub compétitif)**
- Regrouper Challenges en cours, Duo, Compétitions/tournois, classements, lives programmés.

Chaque phase est livrable indépendamment ; la Phase 1 apporte déjà l'essentiel (téléchargement en avant + réflexes TikTok).

---

## 9. Sources (conventions UI)

- [TikTok — signification des icônes latérales](https://www.tiktok.com/discover/what-is-all-the-icons-on-the-right-side-of-the-tiktok-screen-mean?lang=en)
- [Why TikTok's UI is amazing — analyse UX/UI](https://www.linkedin.com/pulse/why-tiktoks-ui-amazing-uxui-analysis-series-part-1-mesai-memoria)
- [Facebook — partage de Reels plus simple (oct. 2025)](https://about.fb.com/news/2025/10/finding-sharing-reels-facebook-just-got-easier-more-fun/)
- [Meta — safe zones Reels/Stories (2026)](https://blog.adnabu.com/meta-ads/meta-safe-zones/)

## Documents internes lus

- `docs/kellenge_implementation_guide.cmd` (modules Jeux / Economia), `docs/STUDIO_P1_TIKTOK_BENCHMARK.md`, `.windsurf/PHASE1_CHALLENGE_UI_REPORT.md`, code `student_challenges_tab.dart` (barre d'actions + nav basse).
