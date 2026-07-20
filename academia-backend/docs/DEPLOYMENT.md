# Guide de déploiement

Le backend doit tourner **24h/24**. Choisir une plateforme :

## Railway
1. Nouveau projet → *Deploy from repo* (dossier `academia-backend`).
2. Railway lit `railway.json` (build `npm run build`, start `node dist/index.js`).
3. Renseigner les variables (onglet *Variables*) — voir [ENVIRONMENT.md](ENVIRONMENT.md).
4. Exposer le domaine public → l'utiliser comme Callback URL des webhooks Meta.

## Render
1. *New Web Service* → connecter le repo.
2. Render lit `render.yaml` (build `npm ci && npm run build`, start `node dist/index.js`, health `/api/health`).
3. Ajouter les variables marquées `sync: false`.

## Docker (VPS ou local)
```bash
docker compose up --build -d      # lit .env, expose le port 4000
docker compose logs -f            # suivre les logs
```
Le `Dockerfile` est multi-stage (build TS puis image runtime légère, deps de prod uniquement).

## VPS Ubuntu (systemd, 24/7)
```bash
# 1. Installer Node 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# 2. Déployer
git clone <repo> && cd academia-backend
npm ci && npm run build
cp .env.example .env   # remplir

# 3. Service systemd
sudo tee /etc/systemd/system/academia-backend.service >/dev/null <<UNIT
[Unit]
Description=Academia Backend
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/academia-backend
ExecStart=/usr/bin/node dist/index.js
EnvironmentFile=/opt/academia-backend/.env
Restart=always
RestartSec=5
User=www-data

[Install]
WantedBy=multi-user.target
UNIT

sudo systemctl daemon-reload
sudo systemctl enable --now academia-backend
sudo systemctl status academia-backend
```
Mettre un **reverse proxy** (Nginx/Caddy) devant, avec HTTPS (Let's Encrypt) — obligatoire pour les webhooks Meta.

## Serveur MCP en production
Le MCP (STDIO) est lancé par le client (Claude Desktop) sur le poste utilisateur — voir [MCP.md](MCP.md). Il n'a pas besoin d'être hébergé comme un service web ; il partage le même code et les mêmes variables d'environnement.

## Checklist production
- [ ] `JWT_SECRET` fort et unique
- [ ] `NODE_ENV=production` (désactive `/api/auth/dev-token`)
- [ ] Secrets via la plateforme, pas de `.env` committé
- [ ] HTTPS + domaine stable pour les webhooks
- [ ] RLS Supabase activée avec politiques
- [ ] Logs surveillés (`LOG_LEVEL=info`)
