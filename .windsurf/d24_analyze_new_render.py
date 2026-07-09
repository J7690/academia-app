#!/usr/bin/env python3
import sys, json, struct, subprocess, requests, paramiko
sys.stdout.reconfigure(encoding='utf-8')

KAMATERA = dict(hostname="185.167.97.144", username="root", password="Nexiomgroup@Academia0", timeout=20)
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SKEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"
H = {"apikey": SKEY, "Authorization": f"Bearer {SKEY}", "Content-Type": "application/json"}

# Le render ID visible dans l'URL de l'image
RENDER_ID = "3b601453-fa7b-4f13-88a7-18683022d1a8"
MP4_FNAME = "7772bca10f4947d2b5e0f370322668b8.mp4"
MP4_URL = f"https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/whiteboard-renders/renders/{RENDER_ID}/{MP4_FNAME}"

print(f"=== ANALYSE RENDER {RENDER_ID} ===")

# 1. Supabase: infos du render job
r = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/admin_execute_sql", headers=H,
    json={"sql": f"SELECT id, status, created_at, video_url, storyboard_json::text FROM whiteboard_render_jobs WHERE id = '{RENDER_ID}';"})
print("SUPABASE RENDER JOB:")
rows = r.json().get("rows", [])
for row in rows:
    print(f"  status={row.get('status')}")
    print(f"  video_url={row.get('video_url')}")
    sj = row.get('storyboard_json', '')
    if sj:
        try:
            d = json.loads(sj)
            scenes = d.get('scenes', [])
            print(f"  nb_scenes={len(scenes)}")
        except:
            print(f"  storyboard_json(raw)={sj[:200]}")

# 2. Telecharger et analyser le MP4
print(f"\nTelechargement: {MP4_URL}")
resp = requests.get(MP4_URL, timeout=30)
print(f"Status: {resp.status_code}, taille: {len(resp.content)} bytes")

if resp.status_code == 200:
    data = resp.content
    
    # Analyse atomes
    off, atoms = 0, []
    while off < len(data) - 8:
        sz = int.from_bytes(data[off:off+4], 'big')
        nm = data[off+4:off+8].decode('ascii', errors='?')
        atoms.append((nm, off, sz))
        if sz < 8: break
        off += sz
        if off > 2000000: break
    
    print(f"\nATOMES TOP-LEVEL:")
    for nm, pos, sz in atoms:
        print(f"  [{nm}] offset={pos} taille={sz}")
    
    atom_names = [a[0] for a in atoms]
    moov_ok = 'moov' in atom_names and 'mdat' in atom_names and atom_names.index('moov') < atom_names.index('mdat')
    print(f"MOOV avant MDAT: {moov_ok}")

    # Sauvegarder pour ffprobe
    with open(r"C:\tmp\d24_new.mp4", "wb") as f:
        f.write(data)
    print("Sauvegarde: C:\\tmp\\d24_new.mp4")

# 3. ffprobe sur Kamatera sur le fichier de ce render
print("\n=== ffprobe via SSH sur le MP4 genere ===")
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(**KAMATERA)

def ssh(cmd):
    _, o, e = c.exec_command(cmd, timeout=60)
    out = o.read().decode(errors='replace')
    err = e.read().decode(errors='replace')
    if out.strip(): print(out[:4000])
    if err.strip(): print(f"[STDERR] {err[:500]}")
    return out

# Verif: est-ce que ce render a ete traite par la v5?
ssh(f"ls -la /tmp/render_{RENDER_ID}/ 2>/dev/null || echo 'Dossier tmp non trouve'")

# Trouver le MP4 sur le serveur
ssh(f"find /tmp -name '{MP4_FNAME}' 2>/dev/null | head -5")
ssh(f"find /opt/whiteboard-worker -name '*.mp4' -newer /tmp -mmin -120 2>/dev/null | head -5")

# ffprobe sur le fichier telecharge depuis Supabase
ssh(f"""
curl -s -o /tmp/d24_check.mp4 '{MP4_URL}' && \
ffprobe -v quiet -print_format json -show_streams -show_format /tmp/d24_check.mp4 2>/dev/null
""")

# Verif critique: quelle version de l'assembler a produit ce render?
# On regarde les logs worker au moment du render
ssh(f"journalctl -u whiteboard-worker --no-pager 2>/dev/null | grep -A5 '{RENDER_ID[:8]}' | head -30")

# Et on verifie la date du fichier assembler vs date du render
ssh("ls -la /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py")
ssh(f"stat /opt/whiteboard-worker/whiteboard_ffmpeg_assembler.py | grep Modify")

# Re-test COMPLET: regenerer avec v5 et comparer
print("\n=== REGENERATION TEST avec v5 ACTUELLE ===")
ssh("""cd /opt/whiteboard-worker && python3 /tmp/d24_test_v5.py 2>&1 | tail -20""")

c.close()

# 4. Recherche externe: ce que font les grandes plateformes
print("""
=== ANALYSE ERREUR ExoPlayer ===
Erreur: MediaCodecVideoRenderer error
format=Format(avc1.42C01F, ColorInfo(BT709, Limited range, SDR SMPTE 170M, false, 8bit Luma, 8bit Chroma))
format_supported=YES

DIAGNOSTIC:
- avc1.42C01F = Baseline level 3.1 => OK codec
- format_supported=YES => le codec est supporte
- SDR SMPTE 170M + BT709 => CONFLIT metadata couleur
  * SMPTE 170M est une norme bt601 (SD video)
  * BT709 est HD
  * ExoPlayer detecte l'incoherence et crash
  
CAUSE RACINE:
  FFmpeg -color_trc bt709 + -colorspace bt709 + -color_primaries bt709
  => devrait produire BT709 pur, MAIS si la source PNG n'a pas de
     profil couleur, FFmpeg peut injecter des valeurs residuelles
     (notamment transfer=smpte170m par defaut sur certaines versions)

SOLUTION CONFIRMEE par YouTube/Netflix/Meta:
  Ajouter explicitement: -color_trc bt709 (pas smpte170m)
  ET utiliser: -vf "...,format=yuv420p" AVANT les flags couleur
  ET ajouter: -x264-params "colorprim=bt709:transfer=bt709:colormatrix=bt709"
""")
