# Vérification ciblée — republier la balise de santé LWS (lecture + une seule action)

**Destinataire** : Windsurf.
**Contexte** : le rapport d'audit du 25 juillet affirme que la publication de la balise
vers `app.whiteboard_engine_health` a réussi (HTTP 204). Vérification indépendante côté
Claude (requête SQL directe sur Supabase) : la table indique toujours `host: vps122603`
(Kamatera), dernière mise à jour le 23 juillet à 12h34 — **aucune trace de LWS, ni
d'aujourd'hui**. Il y a donc une contradiction à lever avant de considérer la Phase 1
comme validée.

## Règle

Une seule action autorisée : exécuter `healthcheck.py` avec les variables d'environnement
correctement chargées, et coller la sortie **brute et complète**, sans la résumer ni
l'interpréter. Aucune autre modification.

## À exécuter

```bash
ssh lws-nexiom "hostname
echo '--- variables presentes (noms seulement) ---'
set -a; source /opt/whiteboard-worker/.env; set +a
echo SUPABASE_URL=\$SUPABASE_URL
echo SUPABASE_SERVICE_KEY_est_definie=\$([ -n \"\$SUPABASE_SERVICE_KEY\" ] && echo oui || echo non)
echo '--- execution healthcheck.py ---'
cd /opt/whiteboard-engine-remotion
python3 healthcheck.py
echo '--- code de sortie ---'
echo \$?"
```

## Rapport à rendre

Colle la sortie complète du bloc ci-dessus telle quelle (hostname, confirmation que les
variables sont chargées, sortie exacte de `healthcheck.py` — y compris la ligne
`[health] publié pour ... (HTTP ...)` ou `[health] échec publication: ...`, et le code de
sortie final). Puis arrête-toi. Claude relira `app.whiteboard_engine_health` côté
Supabase immédiatement après pour confirmer si la ligne a changé.
