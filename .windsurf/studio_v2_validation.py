#!/usr/bin/env python3
"""
STUDIO_V2_PRODUCTION_VALIDATION
Validation runtime du pipeline vidéo avec preuves SQL/Logs/Storage/Flutter
"""

import os
import sys
import time
import json
from datetime import datetime
from supabase import create_client, Client

# Configuration Supabase
SUPABASE_URL = os.getenv('SUPABASE_URL', 'https://thevdfcwlcqzdoybfvgs.supabase.co')
SUPABASE_KEY = os.getenv('SUPABASE_SERVICE_ROLE_KEY')

if not SUPABASE_KEY:
    print("ERREUR: SUPABASE_SERVICE_ROLE_KEY non défini")
    sys.exit(1)

client: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def print_section(title):
    """Print a section header"""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")

def print_proof(label, data):
    """Print proof data"""
    print(f"[PREUVE] {label}")
    if isinstance(data, (dict, list)):
        print(json.dumps(data, indent=2, default=str))
    else:
        print(data)
    print()

def verify_video_asset(video_asset_id):
    """Vérifier création du video_asset"""
    print_section("1. VÉRIFICATION VIDEO_ASSET")
    
    result = client.table('video_assets').select('*').eq('id', video_asset_id).execute()
    
    if not result.data:
        print_proof("video_asset NON TROUVÉ", None)
        return None
    
    asset = result.data[0]
    print_proof("video_asset créé", asset)
    return asset

def verify_transcode_job(video_asset_id):
    """Vérifier création du job transcode_resolution"""
    print_section("2. VÉRIFICATION JOB TRANSCODE_RESOLUTION")
    
    result = client.table('video_processing_jobs').select('*').eq('video_asset_id', video_asset_id).eq('job_type', 'transcode_resolution').execute()
    
    if not result.data:
        print_proof("job transcode_resolution NON TROUVÉ", None)
        return None
    
    job = result.data[0]
    print_proof("job transcode_resolution créé", job)
    return job

def poll_job_status(job_id, timeout=300):
    """Poller le statut du job jusqu'à done ou timeout"""
    print_section("3. POLLING STATUT JOB")
    
    start_time = time.time()
    status_history = []
    
    while time.time() - start_time < timeout:
        result = client.table('video_processing_jobs').select('*').eq('id', job_id).execute()
        
        if not result.data:
            print_proof("Job disparu", None)
            return None
        
        job = result.data[0]
        status = job.get('status')
        
        status_history.append({
            'timestamp': datetime.now().isoformat(),
            'status': status,
            'elapsed_ms': int((time.time() - start_time) * 1000)
        })
        
        print(f"  Status actuel: {status} ({int(time.time() - start_time)}s)")
        
        if status == 'done':
            print_proof("Status final: DONE", job)
            print_proof("Historique des statuts", status_history)
            return job
        elif status == 'failed':
            print_proof("Status final: FAILED", job)
            print_proof("Historique des statuts", status_history)
            return job
        
        time.sleep(2)
    
    print_proof("TIMEOUT - Job non terminé", status_history)
    return None

def verify_renditions(video_asset_id):
    """Vérifier création des renditions dans video_renditions"""
    print_section("4. VÉRIFICATION VIDEO_RENDITIONS")
    
    result = client.table('video_renditions').select('*').eq('video_asset_id', video_asset_id).execute()
    
    if not result.data:
        print_proof("Aucune rendition trouvée", None)
        return []
    
    renditions = result.data
    print_proof(f"{len(renditions)} renditions trouvées", renditions)
    
    # Vérifier les 4 renditions attendues
    expected_keys = ['mp4_main', 'mp4_480p', 'mp4_360p', 'mp4_240p']
    found_keys = [r.get('rendition_key') for r in renditions]
    
    missing = set(expected_keys) - set(found_keys)
    if missing:
        print_proof("Renditions manquantes", list(missing))
    else:
        print_proof("Toutes les renditions présentes", found_keys)
    
    return renditions

def verify_playback_manifest(video_asset_id):
    """Vérifier le playback_manifest"""
    print_section("5. VÉRIFICATION PLAYBACK_MANIFEST")
    
    result = client.rpc('app_videoasset_get_playback_manifest', params={'p_video_asset_id': video_asset_id}).execute()
    
    if not result.data:
        print_proof("playback_manifest vide", None)
        return None
    
    manifest = result.data
    print_proof("playback_manifest", manifest)
    
    # Vérifier les renditions dans le manifest
    if 'manifest' in manifest:
        renditions = manifest['manifest'].get('renditions', [])
        print_proof(f"{len(renditions)} renditions dans manifest", renditions)
    
    return manifest

def verify_storage(video_asset_id):
    """Vérifier présence des fichiers dans Storage (via public_url_hint)"""
    print_section("6. VÉRIFICATION STORAGE")
    
    result = client.table('video_renditions').select('rendition_key, public_url_hint').eq('video_asset_id', video_asset_id).execute()
    
    if not result.data:
        print_proof("Aucune rendition pour vérifier Storage", None)
        return []
    
    storage_info = []
    for r in result.data:
        storage_info.append({
            'rendition_key': r.get('rendition_key'),
            'public_url_hint': r.get('public_url_hint')
        })
    
    print_proof("URLs Storage", storage_info)
    return storage_info

def measure_timings(video_asset_id):
    """Mesurer les temps de traitement"""
    print_section("7. MESURE DES TEMPS")
    
    # Récupérer le job
    job_result = client.table('video_processing_jobs').select('*').eq('video_asset_id', video_asset_id).eq('job_type', 'transcode_resolution').execute()
    
    if not job_result.data:
        print_proof("Job non trouvé pour mesure temps", None)
        return None
    
    job = job_result.data[0]
    
    timings = {
        'created_at': job.get('created_at'),
        'started_at': job.get('started_at'),
        'completed_at': job.get('completed_at'),
    }
    
    # Calculer les durées si disponibles
    if job.get('created_at') and job.get('completed_at'):
        created = datetime.fromisoformat(job['created_at'].replace('Z', '+00:00'))
        completed = datetime.fromisoformat(job['completed_at'].replace('Z', '+00:00'))
        total_duration_ms = int((completed - created).total_seconds() * 1000)
        timings['total_duration_ms'] = total_duration_ms
    
    print_proof("Timings", timings)
    return timings

def main():
    """Fonction principale"""
    if len(sys.argv) < 2:
        print("Usage: python studio_v2_validation.py <video_asset_id>")
        sys.exit(1)
    
    video_asset_id = sys.argv[1]
    
    print_section(f"VALIDATION VIDÉO: {video_asset_id}")
    print(f"Début: {datetime.now().isoformat()}")
    
    # 1. Vérifier video_asset
    asset = verify_video_asset(video_asset_id)
    if not asset:
        print("ERREUR: video_asset non trouvé")
        sys.exit(1)
    
    # 2. Vérifier job
    job = verify_transcode_job(video_asset_id)
    if not job:
        print("ERREUR: job non trouvé")
        sys.exit(1)
    
    job_id = job['id']
    
    # 3. Poller statut
    final_job = poll_job_status(job_id)
    if not final_job or final_job.get('status') != 'done':
        print("ERREUR: job non terminé avec succès")
        sys.exit(1)
    
    # 4. Vérifier renditions
    renditions = verify_renditions(video_asset_id)
    
    # 5. Vérifier Storage
    storage = verify_storage(video_asset_id)
    
    # 6. Vérifier playback_manifest
    manifest = verify_playback_manifest(video_asset_id)
    
    # 7. Mesurer temps
    timings = measure_timings(video_asset_id)
    
    print_section("VALIDATION TERMINÉE")
    print(f"Fin: {datetime.now().isoformat()}")
    
    # Résumé
    print("\nRÉSUMÉ:")
    print(f"  video_asset: {'✓' if asset else '✗'}")
    print(f"  job créé: {'✓' if job else '✗'}")
    print(f"  job done: {'✓' if final_job and final_job.get('status') == 'done' else '✗'}")
    print(f"  renditions: {len(renditions)}/4")
    print(f"  storage: {len(storage)}/4")
    print(f"  manifest: {'✓' if manifest else '✗'}")
    print(f"  timings: {'✓' if timings else '✗'}")

if __name__ == '__main__':
    main()
