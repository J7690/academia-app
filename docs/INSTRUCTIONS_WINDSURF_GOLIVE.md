# GO-LIVE moteur Remotion — Windows (sans rsync ni sshpass)

Contexte : la machine est **Windows**. `rsync`/`sshpass`/`wsl` ne sont PAS disponibles, mais
`ssh` et `scp` (OpenSSH intégré à Windows) le sont. On les utilise, avec le mot de passe tapé
à la main (interactif). Le mot de passe SSH est **fourni par le propriétaire** (root@185.167.97.144).

Deux façons : **Option A** (toi, Ouedraogo, dans ton terminal — le plus simple) ou
**Option B** (clé SSH, pour que Windsurf puisse le faire non-interactivement).

---

## RÈGLES ABSOLUES (si c'est Windsurf qui exécute)
- Fais EXACTEMENT les commandes ci-dessous, rien d'autre. Aucune initiative.
- Ne modifie/crée/supprime AUCUN fichier du dépôt ; ne touche à aucun autre service
  (LiveKit, compress, vocal, videoasset, vision_engine, Nginx, Redis) ni à Supabase.
- À la moindre erreur ou sortie inattendue → **STOP + rapport**. Ne tente pas de contourner.

---

## OPTION A — exécution manuelle (recommandée, par le propriétaire)
Ouvre **PowerShell** ou **Terminal**, place-toi à la racine du dépôt `academia/`, puis lance
ces commandes **une par une**. À chaque fois, tape le mot de passe SSH quand il est demandé.

```powershell
# 1. Préparer le dossier cible sur le serveur (repartir propre)
ssh root@185.167.97.144 "rm -rf /opt/whiteboard-engine-remotion"

# 2. Copier le dossier moteur (scp -r, pas rsync)
scp -r whiteboard_engine_remotion root@185.167.97.144:/opt/whiteboard-engine-remotion

# 3. Copier le worker mis à jour
scp academia_bobodo_backend/whiteboard_render_worker.py root@185.167.97.144:/opt/whiteboard-worker/

# 4. Lancer le script d'installation (déjà présent sur le serveur après l'étape 2)
ssh root@185.167.97.144 "bash /opt/whiteboard-engine-remotion/deploy/go_live.sh"
```

Copie **toute la sortie** de la commande 4 : c'est le rapport.

---

## OPTION B — clé SSH (pour que Windsurf agisse sans mot de passe)
À faire **une seule fois** (le propriétaire tape le mot de passe pendant l'installation de la clé) :

```powershell
# 1. Générer une clé (si tu n'en as pas déjà une)
ssh-keygen -t ed25519 -f $env:USERPROFILE\.ssh\academia_key -N '""'

# 2. Installer la clé publique sur le serveur (demande le mot de passe UNE fois)
type $env:USERPROFILE\.ssh\academia_key.pub | ssh root@185.167.97.144 "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```
Ensuite, Windsurf peut exécuter les 4 commandes de l'Option A en ajoutant
`-i $env:USERPROFILE\.ssh\academia_key` à chaque `ssh`/`scp` — **sans mot de passe**.

---

## CE QUE LA SORTIE DOIT MONTRER (sinon STOP + rapport)
- `node -v` : une version (v20.x).
- Étape « Test moteur isolé » : `✅ Rendu de test produit : /tmp/pro.mp4` + un `ffprobe`
  affichant `profile=Main level=40 720 1280`.
- « Redémarrage du worker » : `✅ worker redémarré`.
- « Balise de santé » : se termine sans erreur.

## RAPPORT À RENDRE
Colle la sortie complète de la commande 4 (le script), la ligne `ffprobe`, et le statut
final (« terminé sans erreur » ou « arrêté à l'étape X »). Puis arrête-toi.
Claude relira `app.whiteboard_engine_health` côté Supabase pour la validation finale.

## NOTE
- On n'utilise plus `rsync` (absent de Windows) : `scp -r` fait le même travail ici.
- Le dossier `whiteboard_engine_remotion/` du dépôt ne contient PAS `node_modules` : la copie
  est légère, et `npm ci` (dans le script) installe les dépendances sur le serveur.
