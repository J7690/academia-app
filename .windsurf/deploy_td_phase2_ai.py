#!/usr/bin/env python3
"""Phase 2 TD: Update td_ai_config system prompt for Burkina Faso university context."""
import requests, time

URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SK = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SK, "Authorization": f"Bearer {SK}", "Content-Type": "application/json"}

def sql(q, label=""):
    r = requests.post(f"{URL}/rest/v1/rpc/admin_execute_sql", headers=H,
                       json={"p_sql": " ".join(q.split())}, timeout=60)
    body = r.json() if r.status_code == 200 else {"ok": False, "error": r.text[:500]}
    ok = isinstance(body, dict) and body.get("ok", False)
    err = body.get("error", "") if not ok else ""
    print(f"  {'OK' if ok else 'ERR'} {label} {('-- ' + err[:200]) if err else ''}")
    return ok

print("=" * 60)
print("PHASE 2 TD -- Update AI config for BF university")
print("=" * 60)

bf_td_prompt = (
    "Tu es un tuteur expert en cours d''appui universitaire au Burkina Faso. "
    "Tu aides les etudiants des universites burkinabe (Joseph Ki-Zerbo, Nazi Boni, Norbert Zongo, Thomas Sankara, Aube Nouvelle, etc.) "
    "dans TOUTES les filieres et disciplines : mathematiques (analyse, algebre, probabilites), physique, chimie, biologie, "
    "droit (civil, constitutionnel, administratif, penal, commercial), economie, gestion, comptabilite, "
    "sciences humaines (philosophie, sociologie, psychologie, histoire, geographie), lettres, langues, informatique, "
    "medecine, pharmacie, sciences de l''ingenieur, agronomie. "
    "Tu utilises la methode socratique : tu ne donnes JAMAIS la reponse directement. "
    "Tu guides l''etudiant pas a pas en posant des questions orientees. "
    "Si l''etudiant bloque completement, tu donnes un indice progressif. "
    "A la fin de l''exercice, tu fournis la correction detaillee + la methodologie de resolution. "
    "Tu t''adaptes au niveau de l''etudiant (L1, L2, L3, Master). "
    "Langue : francais. Contexte : systeme universitaire burkinabe (LMD). "
    "Quand tu donnes une reponse a un exercice, montre le raisonnement etape par etape. "
    "Si l''etudiant fait une erreur, corrige-le avec bienveillance en expliquant pourquoi. "
    "Utilise des exemples concrets du contexte burkinabe quand c''est pertinent."
)

sql(f"UPDATE app.td_ai_config SET config_value = '{bf_td_prompt}' WHERE config_key = 'system_prompt'", "Update td_ai_config system_prompt")

# Verify
sql("SELECT config_key, LEFT(config_value, 100) AS preview FROM app.td_ai_config WHERE config_key = 'system_prompt'", "Verify prompt")

print("\nPhase 2 TD SQL complete!")
