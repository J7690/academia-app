---
name: deep-debug
description: Trouver la cause racine d'un defaut au lieu d'en traiter le symptome. A utiliser des qu'un comportement surprend, qu'un correctif n'a pas tenu, ou qu'on s'apprete a tenter une deuxieme variante du meme correctif.
---

# Chercher la cause, pas le symptome

Ce depot a paye sept fois le meme defaut de raisonnement. Le voici, et il a un
nom :

> **Conclure a partir d'une absence.**
> Pas de message d'erreur ne veut pas dire pas d'erreur.

Les sept cas sont recenses dans `docs/STUDIO_VISUEL_ETAT_2026-08-05.md`. Six se
cachaient derriere un silence ; le septieme derriere un message de **succes** —
une video noire et muette livree comme « prete », parce que le controle
verifiait la validite du fichier et non son contenu.

## La sequence

**1. Reproduire, et le prouver.** Une commande, une sortie, citee. Sans
reproduction, tout le reste est une hypothese sur une hypothese.

**2. Enoncer l'hypothese AVANT de la tester,** et dire par quelle mesure elle
sera fausse. Une hypothese qu'aucune mesure ne peut refuter n'est pas une
hypothese.

**3. Mesurer.** Journaux, `ffprobe`, une requete SQL, un `print` temporaire — ce
qui rend un fait, pas une impression.

**4. Corriger a la source.** Un correctif pose la ou le defaut se VOIT n'est pas
un correctif. Les fins de ligne CRLF ont coute trois machines : d'abord un
fichier corrige, puis un `.gitattributes` — qui ne regit que ce que git
*stocke*. Le bon correctif normalisait **a la destination**.

**5. Reverifier par la meme mesure qu'a l'etape 3**, et citer le nouveau chiffre.

## Les pieges deja rencontres, pour ne pas les repayer

| Symptome | Ce que ce n'etait pas | Ce que c'etait |
|---|---|---|
| Objet invisible au rendu | mauvaise camera | modificateur applique a une geometrie sans faces — aucune erreur levee |
| 403 « row-level security » | politique d'ecriture fausse | l'ecrasement obligeait a LIRE un bucket ferme en lecture |
| Capsule muette | TTS en panne | audio jamais telecharge : pas de droit de lecture, repli silencieux |
| « Ca n'avance plus » | processus mort | telechargement de 17 Go en cours, invisible dans la liste des processus |
| `NameError` a l'execution | syntaxe | correctif applique a moitie — `py_compile` ne voit pas les noms |
| Aperçu jamais publie | seuils mal regles | l'exception etait avalee par un `except` en amont |

Le point commun : dans chaque cas, la premiere explication etait plausible et
fausse. **Plausible n'est pas etabli.**

## Ou regarder, concretement

```bash
ssh lws-nexiom "journalctl -u whiteboard-worker --since '2 hours ago' --no-pager | tail -60"
ssh lws-nexiom "systemctl status whiteboard-worker --no-pager | head -15"
```

Côté base, passer par les outils MCP en lecture (`get_logs`, `get_advisors`) ou
une requete relue. Aucune ecriture pour diagnostiquer.

Pour une video : ne jamais se fier a la taille du fichier. Mesurer la
luminosite moyenne et la presence d'une piste audio — c'est exactement ce que
`montage.verifier()` fait depuis le defaut n°7.

## La regle d'arret

**Trois tentatives infructueuses sur la meme piste : arreter.** Le hook
`anti_boucle` le signalera de toute facon a la quatrieme retouche non mesuree.

Alors, formuler a Jocelyn, dans cet ordre :
1. ce qui est **etabli**, avec la mesure a l'appui ;
2. ce qui **ne l'est pas** ;
3. quelle mesure trancherait.

Ce n'est pas un aveu d'echec. Une piste abandonnee proprement coute moins cher
qu'une quatrieme variante posee a l'aveugle.
