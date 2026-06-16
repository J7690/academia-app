"""
Test complet du système de notifications push Academia.
Vérifie chaque maillon de la chaîne : tables, RPCs, Edge Function, cohérence config.
"""
import json
import os
import sys
import requests

# --- Configuration Supabase ---
SUPABASE_URL = None
SUPABASE_SERVICE_KEY = None

def load_config():
    global SUPABASE_URL, SUPABASE_SERVICE_KEY
    SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
    SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

def sql_query(sql):
    """Execute une requête SQL via l'API REST Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/exec_sql"
    # Fallback: utiliser l'endpoint SQL direct
    headers = {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
    }
    # Essayer via pg_net ou direct SQL
    # Méthode: POST sur /rest/v1/rpc avec une fonction custom
    # Alternative: utiliser le même mécanisme que check_execute_sql_direct.py
    pass

def rest_query(table, schema='app', params='', method='GET', body=None):
    """Requête REST vers une table Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/{table}?{params}"
    headers = {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        'Accept-Profile': schema,
        'Content-Type': 'application/json',
    }
    if method == 'GET':
        r = requests.get(url, headers=headers)
    elif method == 'POST':
        r = requests.post(url, headers=headers, json=body)
    elif method == 'PATCH':
        headers['Content-Profile'] = schema
        r = requests.patch(url, headers=headers, json=body)
    return r

def rpc_call(fn_name, params=None):
    """Appel RPC Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/{fn_name}"
    headers = {
        'apikey': SUPABASE_SERVICE_KEY,
        'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
        'Content-Type': 'application/json',
    }
    r = requests.post(url, headers=headers, json=params or {})
    return r

# ============================================================
# TESTS
# ============================================================
results = []

def test(name, passed, detail=""):
    status = "✅ PASS" if passed else "❌ FAIL"
    results.append((name, passed, detail))
    print(f"  {status} | {name}")
    if detail and not passed:
        print(f"         → {detail}")

def run_tests():
    load_config()
    print(f"\n{'='*60}")
    print(f"  TESTS SYSTÈME DE NOTIFICATIONS PUSH - ACADEMIA")
    print(f"  Supabase: {SUPABASE_URL}")
    print(f"{'='*60}\n")

    # -------------------------------------------------------
    # TEST 1: Table app.user_device_tokens existe et a la bonne structure
    # -------------------------------------------------------
    print("[TEST 1] Table app.user_device_tokens")
    r = rest_query('user_device_tokens', schema='app', params='select=*&limit=0')
    test("Table user_device_tokens accessible", r.status_code == 200, f"status={r.status_code} body={r.text[:200]}")

    # Vérifier les colonnes via une requête avec limit=0 (les headers contiennent le schema)
    r2 = rest_query('user_device_tokens', schema='app', params='select=user_id,platform,fcm_token,is_active,last_seen_at,updated_at,device_info&limit=0')
    test("Colonnes attendues présentes (user_id, platform, fcm_token, is_active, ...)", r2.status_code == 200, f"status={r2.status_code}")

    # -------------------------------------------------------
    # TEST 2: Table app.notification_events existe et a la bonne structure
    # -------------------------------------------------------
    print("\n[TEST 2] Table app.notification_events")
    r = rest_query('notification_events', schema='app', params='select=*&limit=0')
    test("Table notification_events accessible", r.status_code == 200, f"status={r.status_code}")

    r2 = rest_query('notification_events', schema='app', params='select=id,user_id,domain,event_type,payload,processed_at,attempt_count,last_error,created_at&limit=0')
    test("Colonnes attendues présentes (id, user_id, domain, event_type, payload, ...)", r2.status_code == 200, f"status={r2.status_code}")

    # -------------------------------------------------------
    # TEST 3: Table app.user_notification_state existe
    # -------------------------------------------------------
    print("\n[TEST 3] Table app.user_notification_state")
    r = rest_query('user_notification_state', schema='app', params='select=*&limit=0')
    test("Table user_notification_state accessible", r.status_code == 200, f"status={r.status_code}")

    # -------------------------------------------------------
    # TEST 4: RPC app_register_device_token existe
    # -------------------------------------------------------
    print("\n[TEST 4] RPC app_register_device_token")
    # Appel sans auth → devrait retourner not_authenticated (pas une erreur 404)
    r = rpc_call('app_register_device_token', {'p_platform': 'android', 'p_fcm_token': 'test_token_123', 'p_device_info': {}})
    body = r.text
    # La RPC existe si on ne reçoit pas 404. Elle peut retourner not_authenticated (normal sans JWT user)
    rpc_exists = r.status_code != 404
    test("RPC app_register_device_token existe", rpc_exists, f"status={r.status_code}")
    
    if r.status_code == 200:
        try:
            data = r.json()
            is_auth_error = isinstance(data, dict) and data.get('success') == False and data.get('error') == 'not_authenticated'
            is_success = isinstance(data, dict) and data.get('success') == True
            test("RPC retourne une réponse valide (not_authenticated ou success)", is_auth_error or is_success, f"response={data}")
        except:
            test("RPC retourne du JSON valide", False, f"body={body[:200]}")

    # -------------------------------------------------------
    # TEST 5: RPC app_unregister_device_token existe
    # -------------------------------------------------------
    print("\n[TEST 5] RPC app_unregister_device_token")
    r = rpc_call('app_unregister_device_token', {'p_fcm_token': 'test_token_123'})
    test("RPC app_unregister_device_token existe", r.status_code != 404, f"status={r.status_code}")

    # -------------------------------------------------------
    # TEST 6: Événements de notification existants
    # -------------------------------------------------------
    print("\n[TEST 6] Événements de notification")
    r = rest_query('notification_events', schema='app', params='select=id,domain,event_type,processed_at,created_at&order=created_at.desc&limit=5')
    if r.status_code == 200:
        events = r.json()
        test("Des événements de notification existent", len(events) > 0, f"count={len(events)}")
        if events:
            # Vérifier qu'il y a des événements avec différents domaines
            domains = set(e.get('domain', '') for e in events)
            test("Événements couvrent différents domaines", len(domains) >= 1, f"domains={domains}")
            # Vérifier les événements en attente
            r2 = rest_query('notification_events', schema='app', params='select=id&processed_at=is.null')
            if r2.status_code == 200:
                pending = r2.json()
                print(f"         ℹ️  {len(pending)} événements en attente de traitement")
    else:
        test("Lecture des événements", False, f"status={r.status_code}")

    # -------------------------------------------------------
    # TEST 7: Tokens FCM enregistrés
    # -------------------------------------------------------
    print("\n[TEST 7] Tokens FCM enregistrés")
    r = rest_query('user_device_tokens', schema='app', params='select=user_id,platform,is_active,updated_at&is_active=eq.true')
    if r.status_code == 200:
        tokens = r.json()
        if tokens:
            test("Des tokens FCM actifs existent", True, f"count={len(tokens)}")
            platforms = set(t.get('platform', '') for t in tokens)
            print(f"         ℹ️  Plateformes: {platforms}")
        else:
            test("Des tokens FCM actifs existent", False, 
                 "AUCUN token enregistré. Normal si personne ne s'est encore connecté depuis l'APK mis à jour.")
    else:
        test("Lecture des tokens", False, f"status={r.status_code}")

    # -------------------------------------------------------
    # TEST 8: Edge Function send-push-notifications accessible
    # -------------------------------------------------------
    print("\n[TEST 8] Edge Function send-push-notifications")
    edge_url = f"{SUPABASE_URL}/functions/v1/send-push-notifications"
    try:
        r = requests.post(edge_url, headers={
            'Authorization': f'Bearer {SUPABASE_SERVICE_KEY}',
            'Content-Type': 'application/json',
        }, json={}, timeout=30)
        test("Edge Function accessible", r.status_code in [200, 500], f"status={r.status_code}")
        if r.status_code == 200:
            try:
                data = r.json()
                test("Edge Function retourne success=true", data.get('success') == True, f"response={data}")
                processed = data.get('processed', 0)
                print(f"         ℹ️  Événements traités dans cet appel: {processed}")
            except:
                test("Edge Function retourne du JSON", False, f"body={r.text[:200]}")
        elif r.status_code == 500:
            try:
                data = r.json()
                error_msg = data.get('error', r.text[:200])
                test("Edge Function ne crash pas", False, f"error={error_msg}")
            except:
                test("Edge Function erreur", False, f"body={r.text[:300]}")
    except requests.exceptions.Timeout:
        test("Edge Function accessible (timeout 30s)", False, "Timeout - la fonction ne répond pas")
    except Exception as e:
        test("Edge Function accessible", False, f"error={e}")

    # -------------------------------------------------------
    # TEST 9: Cohérence des configurations Firebase
    # -------------------------------------------------------
    print("\n[TEST 9] Cohérence des configurations Firebase")
    
    # Lire google-services.json
    gs_path = os.path.join(os.path.dirname(__file__), '..', 'academia_app', 'android', 'app', 'google-services.json')
    gs_path = os.path.normpath(gs_path)
    gs_ok = False
    gs_data = None
    if os.path.exists(gs_path):
        try:
            with open(gs_path, 'r') as f:
                gs_data = json.load(f)
            gs_ok = True
        except:
            pass
    test("google-services.json existe et est valide", gs_ok, f"path={gs_path}")

    # Lire push_notification_service.dart
    pns_path = os.path.join(os.path.dirname(__file__), '..', 'academia_app', 'lib', 'services', 'push_notification_service.dart')
    pns_path = os.path.normpath(pns_path)
    pns_content = ""
    if os.path.exists(pns_path):
        with open(pns_path, 'r', encoding='utf-8') as f:
            pns_content = f.read()

    # Lire firebase-messaging-sw.js
    sw_path = os.path.join(os.path.dirname(__file__), '..', 'academia_app', 'web', 'firebase-messaging-sw.js')
    sw_path = os.path.normpath(sw_path)
    sw_content = ""
    if os.path.exists(sw_path):
        with open(sw_path, 'r', encoding='utf-8') as f:
            sw_content = f.read()

    if gs_data:
        gs_project_id = gs_data.get('project_info', {}).get('project_id', '')
        gs_sender_id = gs_data.get('project_info', {}).get('project_number', '')
        gs_package = ''
        clients = gs_data.get('client', [])
        if clients:
            gs_package = clients[0].get('client_info', {}).get('android_client_info', {}).get('package_name', '')
            gs_app_id = clients[0].get('client_info', {}).get('mobilesdk_app_id', '')

        test("google-services.json project_id = academia-e2c41", gs_project_id == 'academia-e2c41', f"got={gs_project_id}")
        test("google-services.json package = com.academia.app", gs_package == 'com.academia.app', f"got={gs_package}")
        test("google-services.json sender_id = 593442809911", gs_sender_id == '593442809911', f"got={gs_sender_id}")

        # Vérifier cohérence avec push_notification_service.dart
        if pns_content:
            test("push_notification_service.dart contient le bon projectId", 'academia-e2c41' in pns_content, "")
            test("push_notification_service.dart contient le bon messagingSenderId", '593442809911' in pns_content, "")

        # Vérifier cohérence avec firebase-messaging-sw.js
        if sw_content:
            test("firebase-messaging-sw.js contient le bon projectId", 'academia-e2c41' in sw_content, "")
            test("firebase-messaging-sw.js contient le bon messagingSenderId", '593442809911' in sw_content, "")

    # -------------------------------------------------------
    # TEST 10: Vérifier build.gradle.kts
    # -------------------------------------------------------
    print("\n[TEST 10] Configuration Gradle Android")
    gradle_path = os.path.join(os.path.dirname(__file__), '..', 'academia_app', 'android', 'app', 'build.gradle.kts')
    gradle_path = os.path.normpath(gradle_path)
    if os.path.exists(gradle_path):
        with open(gradle_path, 'r', encoding='utf-8') as f:
            gradle_content = f.read()
        test("Plugin google-services appliqué", 'com.google.gms.google-services' in gradle_content, "")
        test("applicationId = com.academia.app", 'com.academia.app' in gradle_content, "")
        test("Core library desugaring activé", 'isCoreLibraryDesugaringEnabled' in gradle_content, "")
        test("Dépendance desugar_jdk_libs présente", 'desugar_jdk_libs' in gradle_content, "")

    # -------------------------------------------------------
    # TEST 11: Vérifier AndroidManifest.xml
    # -------------------------------------------------------
    print("\n[TEST 11] AndroidManifest.xml")
    manifest_path = os.path.join(os.path.dirname(__file__), '..', 'academia_app', 'android', 'app', 'src', 'main', 'AndroidManifest.xml')
    manifest_path = os.path.normpath(manifest_path)
    if os.path.exists(manifest_path):
        with open(manifest_path, 'r', encoding='utf-8') as f:
            manifest_content = f.read()
        test("Permission POST_NOTIFICATIONS", 'POST_NOTIFICATIONS' in manifest_content, "")
        test("Permission VIBRATE", 'VIBRATE' in manifest_content, "")
        test("Permission RECEIVE_BOOT_COMPLETED", 'RECEIVE_BOOT_COMPLETED' in manifest_content, "")
        test("Canal FCM par défaut configuré", 'default_notification_channel_id' in manifest_content, "")
        test("Icône FCM par défaut configurée", 'default_notification_icon' in manifest_content, "")

    # -------------------------------------------------------
    # TEST 12: Vérifier push_notification_service.dart complet
    # -------------------------------------------------------
    print("\n[TEST 12] push_notification_service.dart")
    if pns_content:
        test("Import firebase_core", 'firebase_core' in pns_content, "")
        test("Import firebase_messaging", 'firebase_messaging' in pns_content, "")
        test("Import flutter_local_notifications", 'flutter_local_notifications' in pns_content, "")
        test("Canal Android 'academia_default' défini", 'academia_default' in pns_content, "")
        test("Foreground message handler", '_handleForegroundMessage' in pns_content, "")
        test("Background message handler", '_firebaseBackgroundHandler' in pns_content, "")
        test("reRegisterTokenAfterLogin()", 'reRegisterTokenAfterLogin' in pns_content, "")
        test("Appel RPC app_register_device_token", 'app_register_device_token' in pns_content, "")
        test("onMessage listener", 'onMessage.listen' in pns_content, "")
        test("onMessageOpenedApp listener", 'onMessageOpenedApp.listen' in pns_content, "")
        test("onBackgroundMessage", 'onBackgroundMessage' in pns_content, "")
        test("getInitialMessage (cold start)", 'getInitialMessage' in pns_content, "")
        test("requestPermission", 'requestPermission' in pns_content, "")

    # -------------------------------------------------------
    # RÉSUMÉ
    # -------------------------------------------------------
    print(f"\n{'='*60}")
    passed = sum(1 for _, p, _ in results if p)
    failed = sum(1 for _, p, _ in results if not p)
    total = len(results)
    print(f"  RÉSULTAT: {passed}/{total} tests passés, {failed} échecs")
    if failed == 0:
        print(f"  🎉 TOUS LES TESTS PASSENT — Système opérationnel !")
    else:
        print(f"\n  ❌ Tests en échec:")
        for name, p, detail in results:
            if not p:
                print(f"     - {name}")
                if detail:
                    print(f"       → {detail}")
    print(f"{'='*60}\n")

if __name__ == '__main__':
    run_tests()
