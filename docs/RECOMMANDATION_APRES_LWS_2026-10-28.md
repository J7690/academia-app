# Recommandation — après la perte du serveur LWS (28/10/2026)

## Les faits (mesurés ou lus, rien de supposé)

- Le VPS LWS `VPS-122603` a expiré le **22/09/2026** et a été suspendu le soir
  même pour non-paiement. Le 28/10, l'espace client (compte LWS-785951) ne
  porte **plus aucun serveur** : le VPS et ses données sont supprimés.
- Tournaient dessus : le **tableau manuscrit** (`whiteboard-worker`), la
  **préparation de la 3D** (`studio-preparateur`, sans laquelle le pod GPU ne
  démarre jamais) et `video-worker`. Ces trois services sont arrêtés depuis
  environ **cinq semaines**.
- **En ce moment même**, un étudiant qui demande un tableau ou une animation 3D
  attend jusqu'à **45 minutes** une vidéo qui ne viendra pas. Essai réel du
  28/10, 13:33 : la capsule « paléontologie » est restée en `a_preparer`.
- **Ce qui marche sans LWS**, mesuré le 28/10 :

| | mesure |
|---|---|
| l'IA écrit la capsule (Supabase) | 9,8 s en médiane, 50 sujets |
| `studio-voix` (Supabase) : voix de la scène 1 | 2,5 s ; les 5 voix en 5,7 s |
| lecteur sur le TECNO (Mali-G52) | 58,6 i/s en palier léger |
| appui → première image parlée | ≈ 3,1 s après la capsule, soit ≈ 13 s en tout |
| export MP4 sur le TECNO | 10 s de vidéo en 21,2 s |

## La recommandation

> **Ne pas racheter de serveur. Tout jouer sur le téléphone.**

Un nouveau VPS ramènerait l'ancienne chaîne : 2 à 5 minutes d'attente, des
machines à surveiller, et une réinstallation complète, puisque le `.env`, la
musique de fond et les versions déployées non commitées sont perdus. La
nouvelle voie fait mieux sans lui, et elle est déjà construite et mesurée pour
la 3D.

## Dans l'ordre

| # | Quoi | Pourquoi d'abord | Effort (estimé) | Qui |
|---|---|---|---|---|
| **1** | **Arrêter l'attente qui ne finira jamais.** 3D : le lecteur seul, et si le téléphone ne peut pas jouer, un message clair au lieu de 45 min d'attente. Tableau : « momentanément indisponible » au lieu d'une commande qui ne produit rien. | des étudiants peuvent payer des crédits pour rien **aujourd'hui** | ½ jour | agent |
| **2** | **Mettre en ligne** : commit, push sur `main` (Netlify publie alors le lecteur sous `/lecteur/`), puis nouvel AAB. | sans `/lecteur/` en ligne, l'application n'a rien à ouvrir | ½ jour | **Jocelyn** (commit, push, Play Console) |
| **3** | **Déployer la génération v2** (décors corps et gouttes), testée sur 50 sujets. | c'est elle qui donne le rendu de la référence | 1 h | **accord de Jocelyn** |
| **4** | **Le partage** : export MP4 sur le téléphone, en tâche de fond (≈ 3 min pour 90 s), à la place de la vidéo du serveur. | le seul usage qui exigeait encore un fichier | 1–2 jours | agent |
| **5** | **Le tableau manuscrit joué sur le téléphone**, comme la 3D. C'est déjà une page HTML animée en CSS ; il faut porter son générateur (Python, qui tournait sur LWS) dans une Edge Function, et reprendre `studio-voix` pour la voix. | il est hors service ; c'est la seule façon de le rendre sans serveur | 3–5 jours | agent |
| **6** | **Compiler ailleurs que sur ce PC** (GitHub Actions ou Codemagic). | le 28/10, quatre compilations ont échoué à cause du poste : disque plein, caches Gradle et Pub corrompus. Le code n'était pas en cause | ½ jour | agent, puis accord |

**Ce qu'on abandonne** : le pod RunPod sur le chemin de l'étudiant, LWS, et la
dépendance à un serveur qu'il faut payer et surveiller. La génération en
Supabase reste, et le plan Pro couvre déjà les appels.

## Ce qui reste fragile, et qu'il faut dire

- Les téléphones **sans WebGL2**, ou plus faibles que le TECNO, ne sont pas
  mesurés : ils auront un message, pas de vidéo.
- L'**application web** (Netlify) n'intègre pas encore le lecteur.
- Le **coût de la voix** (≈ 0,01 à 0,02 $ par capsule) est proche du prix payé
  par l'étudiant (≈ 0,02 $) : la décision de prix reste ouverte.
- Le **lot 4** n'a pas été vu tourner dans l'application : l'essai a échoué sur
  la page de test en `http` local, et la recompilation n'a pas abouti à cause
  du poste. Le repli, lui, a fonctionné (2 s).
