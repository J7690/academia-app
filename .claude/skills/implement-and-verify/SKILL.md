---
name: implement-and-verify
description: Implementer puis PROUVER que ca marche, avec une commande reellement executee. A utiliser pour toute modification de code, de migration ou d'Edge Function. Contient les commandes de verification exactes par couche.
---

# Implementer, puis prouver

La regle du depot tient en une phrase, tiree de sept defauts payes cher :

> **Ne jamais deduire un etat de ce qu'on ne voit pas.**
> Verifier qu'un fichier est valide ne dit rien de ce qu'il contient.

Une capsule video a ete livree a un etudiant en etant **noire et muette**, avec
un journal affichant « pret ». Le controle regardait la validite du fichier, pas
son contenu. C'est le defaut le plus grave du projet et il doit rester en tete.

## La sequence, sans raccourci

1. **Etablir l'etat de depart.** Lancer la verification AVANT de modifier. Sans
   cela, on ne saura pas distinguer un defaut cree d'un defaut preexistant.
   Sur ce depot c'est indispensable : `flutter analyze` remonte **164
   avertissements et ~1 980 remarques preexistants** pour **0 erreur**. Qui ne
   mesure pas d'abord croira les avoir causes.
2. **Modifier**, le plus petitement possible.
3. **Relancer la meme verification** et comparer aux chiffres de depart.
4. **Regarder la sortie**, pas seulement le code de retour.
5. **Rapporter le chiffre**, pas l'impression. « 0 erreur, 164 avertissements,
   inchange » et non « ca compile ».

## Les commandes, par couche

### Flutter — **depuis `academia_app/`, jamais depuis la racine**

```bash
cd academia_app && flutter analyze --no-pub
```

Compter avant de conclure — `flutter analyze` sort en code 1 des qu'il y a un
avertissement, meme sans aucune erreur :

```bash
cd academia_app && flutter analyze --no-pub > /tmp/a.txt 2>&1; grep -cE "^\s*error -" /tmp/a.txt
```

Tests et compilation reelle :

```bash
cd academia_app && flutter test
cd academia_app && flutter build apk --debug
```

**Piege du code de sortie** : ne jamais lire le code de retour a travers un
`| tail` ou un `| head` — c'est celui du dernier maillon du tuyau, pas celui de
la commande. Rediriger dans un fichier, puis lire le fichier.

### Edge Functions — Deno

```bash
deno test supabase/functions/whiteboard-generate-storyboard/validate_test.ts
deno check supabase/functions/<nom>/index.ts
```

### Worker Python

```bash
python -m py_compile academia_bobodo_backend/whiteboard_vision/*.py
```

Un `py_compile` valide la **syntaxe**, pas les noms. Un correctif applique a
moitie a deja produit un `NameError` a l'execution que `py_compile` ne pouvait
pas voir. Pour les noms, relire le fichier entier apres modification.

### Base de donnees

Aucune ecriture en production sans autorisation explicite de Jocelyn. Une
modification de schema se fait par **migration relue**, jamais par un
`execute_sql` direct. `.claude/settings.json` met `execute_sql` et
`apply_migration` en `ask` : c'est voulu, ne pas contourner.

## Ce qui compte comme preuve, et ce qui n'en est pas une

| Preuve | Pas une preuve |
|---|---|
| la sortie de la commande, citee | « ca devrait marcher » |
| un compteur avant / apres | « j'ai corrige la cause » |
| le contenu mesure du fichier produit | le fichier existe et pese 2 Mo |
| la ligne de journal qui montre le cas | l'absence de message d'erreur |

Le silence n'est pas un succes. Sur ce depot, six defauts sur sept se cachaient
derriere une **absence** de message ; le septieme derriere un message de
**succes**.

## Quand la verification est impossible

Le dire. Ne pas livrer en presentant une supposition comme un resultat.
Formuler : « ceci est etabli : … ; ceci ne l'est pas : … ; pour trancher il
faudrait mesurer … ». C'est une reponse acceptable. Une affirmation non verifiee
ne l'est pas.
