---
name: independent-review
description: Faire relire un travail par un regard qui n'a pas participe a sa fabrication, et refuter ses conclusions avant de les rapporter. A utiliser avant une poussee, avant de declarer une tache terminee, ou quand un resultat semble trop beau.
---

# Se faire contredire, exprès

Celui qui a ecrit le code est le plus mal place pour le relire : il relit son
intention, pas son texte. Cette competence organise le desaccord.

## Les relecteurs disponibles

| Agent | Ce qu'il cherche | Quand |
|---|---|---|
| `pr-review-toolkit:silent-failure-hunter` | echecs avales, replis abusifs, `catch` muets | **le plus utile ici** — cf. plus bas |
| `pr-review-toolkit:code-reviewer` | conformite aux regles du depot | avant poussee |
| `pr-review-toolkit:pr-test-analyzer` | ce que les tests ne couvrent pas | quand on ajoute du comportement |
| `pr-review-toolkit:comment-analyzer` | commentaires qui mentent sur le code | apres une grosse documentation |
| `feature-dev:code-reviewer` | bogues et securite | changement large |
| `independent-reviewer` (ce depot) | tout ce qui precede, avec le contexte Academia | par defaut |

`silent-failure-hunter` est celui qui compte : le defaut le plus grave du projet
a ete une video **noire et muette** livree avec un journal affichant « pret ».
Six autres defauts se cachaient derriere une absence de message.

## La regle qui rend la relecture utile

**Une alerte n'est retenue que si on a essaye de la refuter et echoue.**

Une relecture qui rend quinze remarques dont douze fausses est pire que pas de
relecture : elle noie les trois vraies, et on apprend a ignorer l'outil. Donc,
pour chaque alerte, avant de la rapporter :

1. aller **lire le code soi-meme** — ne pas faire confiance a la preuve avancee ;
2. chercher ce qui la rendrait **fausse** ;
3. **en cas de doute, l'ecarter.** Un faux positif coute plus cher qu'un
   avertissement manquant, parce qu'il detruit la confiance dans tous les autres.

C'est une methode eprouvee sur ce depot : une relecture a signale un ecran
« alimente par un tout autre enregistrement » ; la contre-verification a montre
que l'Edge Function lisait bien la fiche du conseiller pour la construire. La
premiere lecture etait plausible et fausse.

## Ce qu'un rapport doit contenir

Pour chaque alerte retenue :

- **fichier:ligne** ;
- ce qui a ete **reellement observe** (pas ce qui est suppose) ;
- le **scenario d'echec** : quelle entree, quel etat, quel resultat faux ;
- la gravite : **bloquant** / **a surveiller**.

Et, aussi important : **dire ce qui a ete verifie et n'a rien donne.** « Les
quatre suppressions ne laissent aucune reference morte, verifie symbole par
symbole » est un resultat, pas un vide.

## Ce qui doit toujours etre relu

- Tout ce qui touche **paiements**, **credits**, **authentification** →
  competence `security-review` en plus.
- Toute **suppression** de fichier : chercher les references restantes avant de
  conclure.
- Tout **repli** (`catch`, valeur par defaut, mode degrade) : est-il **bruyant** ?
  Un repli qui se tait est un defaut en attente.

## Avant de declarer termine

Trois questions, honnetement :

1. Quelle commande ai-je reellement executee, et qu'a-t-elle rendu ?
2. Qu'est-ce que je n'ai **pas** verifie ?
3. Si ceci est faux, comment le saurait-on ?

Si la reponse a la premiere est « aucune », ce n'est pas termine.
