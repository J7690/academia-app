# Docker Hub — procédure exacte, sans jamais livrer le mot de passe principal

**Date : 11/08/2026.** À exécuter par **Jocelyn**. Je ne crée pas de compte, je ne
saisis pas d'identifiant, et **je ne dois jamais voir le jeton**.

---

## Pourquoi cette étape existe

RunPod ne démarre une machine qu'à partir d'une image publiée dans un **registre**.
Aujourd'hui, chaque pod réinstalle Node, Chromium et Blender après son démarrage — et
RunPod **efface le disque du conteneur à chaque arrêt**. Tant que c'est le cas, un pod
arrêté redémarre nu : l'arrêt automatique deviendrait une panne, pas une économie.

LWS sait construire l'image (Docker 29.6.2, 136 Go libres). Il ne sait pas la publier
sans un dépôt et un jeton.

---

## 1. Créer le dépôt

1. Se connecter sur **hub.docker.com** avec le compte habituel.
2. **Repositories → Create repository**
3. Renseigner :

   | Champ | Valeur |
   |---|---|
   | Namespace | ton identifiant Docker Hub |
   | Repository Name | **`academia-studio`** |
   | Visibility | **Private** |

> **Private, et pas Public.** L'image contient le moteur de rendu, les contours SVG et
> les scripts d'agent. Le plan gratuit de Docker Hub inclut **un** dépôt privé — c'est
> exactement ce qu'il nous faut, mais s'il est déjà pris par un autre projet, il faudra
> soit libérer celui-là, soit passer au plan payant. À vérifier avant de continuer.

Le nom complet de l'image sera donc : `<ton-identifiant>/academia-studio`

---

## 2. Créer un jeton d'accès — **jamais le mot de passe**

1. **Account Settings → Security → Personal access tokens → Generate new token**
2. Renseigner :

   | Champ | Valeur |
   |---|---|
   | Description | `academia-lws-publication` |
   | Expiration | 90 jours |
   | Access permissions | **Read & Write** |

3. Docker Hub affiche le jeton **une seule fois**. Ne le colle nulle part d'autre que
   dans l'étape 3.

**Pourquoi un jeton et pas le mot de passe :** il est limité à ce dépôt, révocable en un
clic sans changer le mot de passe, il expire tout seul, et il n'ouvre pas l'accès au
compte. Si LWS était compromis, on révoque le jeton et rien d'autre n'est touché.

---

## 3. L'installer sur LWS — sans qu'il transite par la conversation

Depuis ton poste, ouvre une session sur LWS et lance :

```bash
ssh lws-nexiom "docker login -u <ton-identifiant>"
```

Docker demande alors le mot de passe : **colle le JETON**, pas le mot de passe du compte.
La saisie est masquée.

Docker enregistre l'autorisation dans `/root/.docker/config.json` sur LWS. Elle y reste :
la commande n'est à faire **qu'une fois**.

> **Ne me communique pas le jeton, même après.** Je n'en ai pas besoin : `docker push`
> utilisera l'autorisation déjà enregistrée sur la machine. Un jeton qui apparaît dans
> une conversation est un jeton à révoquer.

---

## 4. Me dire deux choses

Une fois les trois étapes faites, il me suffit de savoir :

1. **ton identifiant Docker Hub** (pas le jeton) — pour composer le nom de l'image ;
2. que **`docker login` a réussi** sur LWS.

Je vérifierai moi-même que l'autorisation fonctionne, sans lire le fichier, par :

```bash
ssh lws-nexiom "docker system info --format '{{.IndexServerAddress}}'; test -f /root/.docker/config.json && echo 'autorisation enregistree'"
```

---

## 5. Ce que je fais ensuite

1. Construire l'image sur LWS depuis `academia_bobodo_backend/studio_visuel/image/`.
2. La publier en `<ton-identifiant>/academia-studio:1.0.0` **et** `:latest`.
3. Poser `STUDIO_IMAGE` dans les secrets Supabase pour que `runpod-control` la déploie.
4. Créer un pod **depuis cette image**, et vérifier qu'il démarre seul : GPU détecté,
   EGL présent, Chromium sur `--use-angle=gl-egl`, sonde produisant une **vraie image**,
   agent déclaré prêt — **sans aucune intervention SSH**.

Ce n'est qu'après cette preuve que la migration s'applique et que `runpod-control` se
déploie. Et l'arrêt automatique attend encore le test complet de bout en bout.

---

## Ce qui pourrait mal tourner, et que je surveillerai

| Risque | Signe | Réponse |
|---|---|---|
| Dépôt privé déjà consommé | Docker Hub refuse `Private` | libérer l'autre dépôt, ou plan payant |
| Image trop lourde | poussée très longue | Blender (~300 Mo) + Chromium (~150 Mo) + CUDA (~2 Go) : compter **3 à 4 Go**, une poussée de plusieurs minutes |
| RunPod ne peut pas tirer une image privée | pod en `ERROR` au démarrage | renseigner les identifiants de registre côté RunPod, ou rendre le dépôt public **sans** y mettre de secret |
| Jeton expiré à 90 jours | `docker push` refusé | en régénérer un, refaire l'étape 3 |

Le troisième mérite attention : **RunPod doit pouvoir s'authentifier auprès de Docker Hub**
pour tirer une image privée. Cela se règle dans les paramètres de conteneur du compte
RunPod. Si c'est trop compliqué, l'alternative est un dépôt public — acceptable
uniquement si l'image ne contient **aucune clé** : c'est le cas, tous les secrets
arrivent par variables d'environnement au démarrage, jamais dans l'image.
