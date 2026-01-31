# Cahier des charges – Animations & Mascotte BOBODO
# Plateforme ACADEMIA (Nexiom Group)

---

## 0. Contexte & objectifs stratégiques

### 0.1 Contexte

La plateforme ACADEMIA (Nexiom Group) est une solution de **courtage académique** destinée aux étudiants et à leurs parents, avec un back-office d’administration puissant.

L’introduction d’une mascotte officielle (BOBODO) et d’un système d’animations a pour objectif de :

- **Rassurer** parents et étudiants.
- **Guider** : orientation, complétion de dossier, paiements.
- **Engager** sans infantiliser.
- **Professionnaliser** l’image du courtage académique.

Les animations ne sont **pas décoratives** : elles doivent **expliquer, confirmer, sécuriser**.

### 0.2 Périmètre

Ce cahier des charges couvre :

- La **mascotte BOBODO** (identité, style, variantes, états d’animation).
- Les **animations produit** sur les principaux parcours :
  - Étudiant.
  - Parent.
  - Admin.
- Les **micro-interactions** globales (boutons, formulaires, toasts, loaders, etc.).
- Les **implémentations techniques** :
  - App mobile Flutter (plateforme principale).
  - Site vitrine web (Next.js / HTML).
- Les **règles d’accessibilité** (reduce motion, WCAG).
- Le lien avec la **gamification** et le **parrainage** (récompenses, triggers, anti-fraude).

---

## 1. Mascotte officielle : BOBODO

### 1.1 Identité & rôle

- **Nom** : BOBODO.
- **Rôle** : guide intelligent, conseiller académique, assistant de confiance.
- BOBODO n’est **pas un gadget** et ne doit pas commenter en continu.

**Principes d’intervention** :

- Il intervient seulement quand c’est **utile** :
  - Onboarding.
  - Orientation.
  - Blocage / incompréhension.
  - Succès importants (dossier soumis, admission, profil complété...).
- Il **ne parle pas tout le temps** : interventions courtes, ciblées, toujours actionnables.

### 1.2 Direction artistique (style visuel)

- **Style** : semi-flat moderne, crédible, éducatif.
- **Genre** : neutre.
- **Expression dominante** : calme, bienveillante, rassurante.
- **Accessoire identitaire** : chapeau de graduation stylisé (pompon discret).
- **Palette** : dérivée des couleurs Academia (verts / bleus académiques + neutres).

**Interdits** :

- Caricature enfantine.
- Animation trop rapide ou agitée.
- Humour excessif, blagues permanentes.

### 1.3 Variantes de BOBODO (formats visuels)

- **Avatar rond (tête + épaules)**
  - Usage : chat, petits espaces, header.
  - Lisible en 40×40.

- **Demi-corps**
  - Usage : formulaires, blocs d’aide, écrans orientation / candidature.

- **Full body**
  - Usage : onboarding, grandes illustrations (landing, écrans de succès majeurs).

Toutes les variantes doivent partager :

- Le même style semi-flat.
- Le même design de chapeau de graduation.
- Les mêmes proportions générales.

### 1.4 États d’animation obligatoires (MVP BOBODO)

Liste d’états à livrer (prioritairement en **Rive**, fallback **Lottie**, secours **PNG**) :

1. **Idle**  
   - Attente, présence discrète, micro-mouvements lents (respiration).
2. **Blink**  
   - Clignements intégrés à l’Idle pour donner de la vie.
3. **Thinking**  
   - Orientation, réflexion, calcul (regard légèrement levé, posture de réflexion).
4. **Pointing**  
   - Geste pour montrer une action, un bouton, une section.
5. **Typing**  
   - Animation de frappe (chat, réponses en cours).
6. **Success**  
   - Validation douce (sourire modéré, geste discret positif).
7. **Warning**  
   - Attention douce, mise en garde sans dramatiser.
8. **Celebration (≤ 1s)**  
   - Célébration très légère, courte, jamais en boucle.

### 1.5 Formats & pipelines d’assets

**Priorités de format** :

1. **Rive (.riv)** – format principal pour l’app Flutter.
2. **Lottie (.json)** – fallback, surtout pour le web.
3. **PNG statiques** – fallback et mode "Reduce Motion".

**Organisation des assets (recommandée)** :

- Flutter :
  - `assets/bobodo/rive/bobodo.riv`
  - `assets/bobodo/lottie/*.json`
  - `assets/bobodo/images/*.png`

- Web (Next.js) :
  - `/public/bobodo/lottie/*.json`
  - `/public/bobodo/images/*.png`

### 1.6 Exigences techniques pour le designer (Rive-ready)

- Calques séparés, non fusionnés, notamment :
  - `Head`, `Face_Base`, `Eyes_L`, `Eyes_R`, `Lids`, `Brows`, `Mouth`.
  - `Torso`, `Arm_L`, `Arm_R`, `Hand_L`, `Hand_R`, `Hips`.
  - `Hat`, `Tassel` (pompon).
- Pas de dégradés complexes.
- Pas d’ombres floues (compatibilité temps réel).
- Points d’ancrage logiques : cou, épaules, coudes, poignets, base du chapeau.
- Lisible à 40×40 et 128×128.


---

## 2. Parcours & règles d’animation – Étudiants & Parents

### 2.1 Parcours étudiant – Timeline officielle

Étapes clés du parcours étudiant (timeline animée) :

1. Création compte.
2. Profil étudiant.
3. Orientation.
4. Choix programme.
5. Candidature (brouillon).
6. Documents.
7. Soumission.
8. Paiement / échéancier.
9. Analyse admin.
10. Admission / refus.

#### Règles d’animation de la timeline

- La **timeline est toujours visible** sur les écrans de candidature.
- États par étape :
  - ⏳ **À faire**.
  - 🔄 **En cours** (animation de "pulse" lente).
  - ✅ **Validé** (check animé discret).
  - ⚠️ **Bloqué** (icône info + intervention ciblée de BOBODO).

#### Interventions de BOBODO (étudiant)

BOBODO intervient uniquement si :

- Une étape bloque (erreur, timeout, refus incompris, champ manquant critique).
- Un champ critique est manquant pour pouvoir avancer.
- Un succès important est atteint (dossier soumis, admission, profil complet…).

Les messages doivent être **courts, rassurants, orientés action**.

### 2.2 Parcours parent – Confiance & visibilité

Étapes simplifiées pour le parent :

1. Choix université.
2. Budget & échéancier.
3. Paiement sécurisé.
4. Statut dossier.
5. Admission / confirmation de rentrée.

**Animations clés côté parent** :

- Barres de progression claires.
- Icônes de sécurité (paiement sécurisé, chiffrement, etc.).
- Statuts lisibles et explicites.
- **Aucune animation ludique** (pas de confetti, pas de gamification visible).

BOBODO intervient très peu, avec un ton strictement professionnel.


---

## 3. Catalogue global d’animations UI

### 3.1 Micro-interactions (obligatoires)

À implémenter sur Flutter et, quand pertinent, sur le site web :

- **Boutons** :
  - État hover (web), press (mobile), loading (spinner intégré ou barre de progression fine).
- **Champs de formulaire** :
  - Focus (bord/lueur discrète).
  - Erreur (shake léger + message clair + icône).
  - Succès (check discret, changement de couleur sobre).
- **Toasts** :
  - Slide-in (depuis le haut/bas), durée limitée, pas d’animation agressive.
- **Skeleton loaders** :
  - Prefetch liste, formulaires longs, tables admin.
- **Progress bars** :
  - Doivent refléter un **pourcentage réel** (pas de faux indicateurs).

### 3.2 Animations de confiance

**Paiement** :

- Icône shield animée (sécurité).
- État "traitement" (loading clair, pas bloquant visuellement mais explicite).
- Confirmation claire en cas de succès.

**Upload documents** :

- Affichage du pourcentage réel.
- Confirmation visuelle immédiate à la fin.
- Gestion propre des erreurs (fichier trop lourd, format non accepté, etc.).

### 3.3 Gamification (contrôlée)

- Badges discrets (profil complet, dossier soumis, etc.).
- Confetti **ultra léger** (≤ 1s) uniquement sur des étapes non sensibles :
  - ex : profil complété, dossier complet, admission.
- Jamais de gamification sur :
  - Paiement.
  - Vue admin.
  - Écrans d’erreur.


---

## 4. Animations par écran (Flutter + Web)

### 4.1 Accueil – Site vitrine (Next.js / HTML)

**Objectif principal** : conversion (inscription / prise de contact).

**Animations autorisées** :

- Reveal au scroll (fade + translation légère).
- Chiffres/statistiques animés (count-up sobre).
- Boutons "magnétiques" (desktop) avec effet léger.
- Parallax léger sur quelques visuels.
- Apparaition courte de BOBODO (salut, 1x, non répétitif).

**Interdits** :

- Animations lourdes continues.
- Sons automatiques.

### 4.2 Authentification (Flutter)

- Transition douce Login ↔ Signup.
- Validation champ animée (success/erreur).
- Bouton loading clair (spinner intégré au bouton, texte figé).
- Succès : toast + animation de check.

### 4.3 Onboarding (Flutter)

- 3–5 écrans maximum.
- BOBODO full-body en acteur principal.
- Points de progression (dots) animés.
- Bouton Skip toujours visible.

### 4.4 Orientation (Flutter + Web)

- Cards filières animées (hover / tap, lift léger).
- Filtres avec transitions smooth.
- Skeleton loaders pendant le chargement des recommandations.
- BOBODO "Thinking" lorsque des recommandations sont en cours de calcul.

### 4.5 Programmes / Universités

- Hover / lift sur les cards (web et mobile adapté).
- Animation discrète sur l’ajout aux favoris.
- Badges "Réduction", "Places limitées" animés très légèrement (pulse très lent, non agressif).

### 4.6 Candidature

- Timeline en haut, toujours visible.
- Validation section par section (avec feedback visuel de complétion).
- Upload documents avec feedback clair et pourcentage réel.
- Soumission :
  - Modal de confirmation.
  - Animation "envoi" (courte).
  - Écran de succès avec BOBODO (🎓 sobre).

### 4.7 Paiement

États strictement définis :

1. Préparation.
2. En cours.
3. Succès.
4. Échec (avec parcours de reprise clair).

**Interdit** : toute animation purement décorative ou ludique.
Animations acceptées : celles qui renforcent la compréhension (loading, sécurité, statut).

### 4.8 Messagerie

- Indicateur de frappe (typing indicator).
- Animation d’envoi de message (slide / fade).
- Réactions micro-animées.
- BOBODO optionnel, surtout pour l’onboarding/explication.

### 4.9 Admin

- Skeleton sur les tables et listes lors du chargement.
- Highlight sur les nouvelles lignes/notifications.
- Toasts de confirmation d’actions (création, mise à jour, suppression).
- **Zéro** animation ludique.


---

## 5. Spécifications techniques – Flutter

### 5.1 Packages recommandés

- `rive`
- `lottie`
- `flutter_animate` (ou équivalent pour animer facilement les widgets).

### 5.2 Gestion des assets

Exemple d’organisation :

- `assets/bobodo/rive/bobodo.riv`
- `assets/bobodo/lottie/bobodo_idle.json`, etc.
- `assets/bobodo/images/bobodo_avatar.png`

À déclarer dans `pubspec.yaml` :

```yaml
flutter:
  assets:
    - assets/bobodo/rive/bobodo.riv
    - assets/bobodo/lottie/
    - assets/bobodo/images/
```

### 5.3 Intégration BOBODO (Rive – widget réutilisable)

- Créer un widget réutilisable de type `BobodoRive` qui :
  - Charge `bobodo.riv`.
  - Expose un paramètre `stateMachineName`.
  - Permet d’activer certains triggers (success, warning, celebrate...).

- L’implémentation exacte devra s’aligner sur les noms des State Machines et inputs définis dans le fichier `.riv`.

### 5.4 Système centralisé des durées & easing

- Maintenir un fichier/dart utilitaire pour :
  - Les durées standards (ex : 150ms, 250ms, 350ms, 600ms).
  - Les courbes d’animation (e.g. `Curves.easeInOut`).

Objectif : cohérence de toutes les animations.

### 5.5 Option "Reduce Motion" (Flutter)

- Utiliser `MediaQuery.of(context).disableAnimations` ou un flag applicatif pour :
  - Remplacer Rive/Lottie par des PNG statiques.
  - Désactiver les confetti et animations non essentielles.

- Prévoir un paramètre utilisateur explicite :
  - Animations : Normal / Réduit / Off.
  - Sauvegardé dans le profil utilisateur.


---

## 6. Spécifications techniques – Site vitrine (Next.js / HTML)

### 6.1 Outils

- **Animations** :
  - `Framer Motion` ou `GSAP`.
- **Lottie** :
  - `lottie-react` (ou équivalent) pour les animations JSON.

### 6.2 Performances & accessibilité

- Respecter `prefers-reduced-motion`.
- Mobile-first.
- Désactivation automatique des animations lourdes sur mobile ou réseau faible.

### 6.3 Intégration BOBODO (web)

- Lottie pour les animations (idle, success, etc.).
- PNG avatar pour le mode reduce-motion.
- Pas d’animations infinies lourdes sur la landing.


---

## 7. Accessibilité & paramètres

### 7.1 Paramètres utilisateur

- Paramètre global : **Animations** = `Normal` / `Réduit` / `Off`.
- Stocké côté backend (profil utilisateur) et appliqué côté client.

### 7.2 Règles d’accessibilité (mouvement)

- Respect des standards WCAG pour les animations/mouvements.
- Limiter les animations répétitives, lumineuses, ou rapides.


---

## 8. Tests & QA

Scénarios à couvrir :

- Téléphones low-end (performance, batteries).
- Connexion lente / instable.
- Paiement interrompu en plein processus.
- Upload incomplet ou en erreur.
- Mode animations désactivées ou réduites.
- Dark mode (si activé dans l’application).


---

## 9. Gamification & parrainage – Rôle de BOBODO

### 9.1 Principes

- BOBODO **annonce** la progression et **explique** les récompenses.
- Il ne doit jamais apparaître comme un gadget qui spamme.
- La gamification sert :
  - À pousser à compléter le profil.
  - À déposer les documents.
  - À soumettre la candidature.
  - À inviter via parrainage (si activé) **avec transparence** sur les règles.

### 9.2 Événements gamification (triggers)

Événements à instrumenter :

- Étapes dossier :
  - `profile_completed`
  - `orientation_completed`
  - `application_draft_created`
  - `documents_uploaded`
  - `application_submitted`
  - `payment_validated`
  - `admission_confirmed`

- Parrainage :
  - `ref_link_copied`
  - `ref_signup_success`
  - `ref_first_action_completed` (profil filleul complété)
  - `ref_conversion_submitted` (dossier filleul soumis)

### 9.3 Types de récompenses

- Badge "Profil prêt".
- Badge "Dossier complet".
- Points de progression.
- Éventuellement rang (Bronze / Silver / Gold) à plus long terme.

BOBODO affiche des messages courts de type :

- « Badge obtenu : Profil prêt ✅ »
- « +{points} points. Continue ! »
- « Ton lien a été copié. Partage-le sur WhatsApp si tu veux. »

### 9.4 Anti-fraude (parrainage)

- Récompenses sur **actions réelles**, pas sur de simples clics.
- Points/bonus techniques accordés uniquement après :
  - Création de compte validée.
  - Profil complété.
  - Candidature soumise.
- Limiter :
  - Répétitions massives d’invitations.
  - Multi-comptes sur le même device (détection soft, signaux faibles).

Récompense parrainage à n’accorder qu’après une étape **significative** (profil complet ou soumission dossier).


---

## 10. Micro-textes BOBODO (ton & exemples)

### 10.1 Règles de ton

- Messages **très courts**, clairs, rassurants.
- Pas d’argot.
- Pas de culpabilisation.
- 1 action maximum par message.
- Toujours proposer une issue : continuer, voir, corriger.

### 10.2 Exemples de micro-textes (sélection)

**Accueil / découverte** :

- « Salut 👋 Je suis Bobodo. Je t’aide à avancer étape par étape. »
- « Tu peux commencer par ton profil : ça prend 2 minutes. »

**Onboarding** :

- « Ici, tu construis ton dossier pour la prochaine rentrée. »
- « On choisit d’abord ton objectif : filière, budget, université. »

**Orientation** :

- « Dis-moi ta série et ce que tu aimes, je te propose des options. »
- « On va comparer 3 filières possibles. »

**Candidature / documents** :

- « Parfait. Ton brouillon est enregistré. »
- « Il te manque une pièce : ajoute-la pour continuer. »
- « Tu es à **{progress}%** de ton dossier. »
- « Téléversement en cours… **{percent}%** »
- « Document reçu ✅ »

**Soumission** :

- « Dernière vérification : tout est bon ? »
- « Dossier soumis ✅ Tu recevras une mise à jour ici. »

**Paiement (mode sérieux)** :

- « Paiement sécurisé. Ne ferme pas la page. »
- « Traitement en cours… »
- « Paiement validé ✅ Reçu disponible. »
- « Échec de paiement. Tu peux réessayer sans perdre ton dossier. »

**Erreurs & blocages** :

- « On dirait qu’il manque une information. »
- « Je te montre où corriger. »
- « Pas grave — on reprend ensemble. »


---

## 11. Plan de livraison produit (phases macro)

### Phase 1 – MVP

- Micro-interactions essentielles.
- Timeline candidature (étudiant).
- Paiement sécurisé (animations de confiance).
- Bobodo chat (idle, typing, success).

### Phase 2 – Expérience premium

- Onboarding animé complet.
- BOBODO Rive avancé (tous les états requis).
- Landing animée web (vitrine) avec BOBODO.

### Phase 3 – Optimisation

- A/B testing des animations (conversion, complétion dossier).
- Analyse de l’impact sur les taux de conversion et d’abandon.
- Ajustements finaux (performance, UX, accessibilité).


---

## 12. Livrables finaux attendus

1. **Design system animation** :
   - Guidelines complètes pour les animations (durées, easing, usages autorisés/interdits).

2. **Assets BOBODO** :
   - Fichiers source (Figma/AI).
   - Fichiers Rive (.riv) + Lottie (.json) + PNG/SVG statiques.

3. **Catalogue d’écrans + animations validées** :
   - Liste des écrans, états, et animations associées.

4. **Implémentation Flutter + Web** :
   - Intégration réelle dans l’app ACADEMIA (Flutter) et le site vitrine (Next.js/HTML).

5. **Documentation dev & QA** :
   - Comment utiliser les widgets BOBODO.
   - Comment étendre les animations.
   - Checklist QA pour tester animations et accessibilité.
