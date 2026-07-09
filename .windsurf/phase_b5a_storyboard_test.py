"""
Script pour Phase B.5A – Storyboard Compatibility Audit
Création et test de Storyboards de test pour différentes matières
"""

import requests
import json
import time
from datetime import datetime

# Configuration
rpc_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc"
admin_url = "https://thevdfcwlcqzdoybfvgs.supabase.co/rest/v1/rpc/admin_execute_sql"
headers = {
    "apikey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM",
    "Content-Type": "application/json"
}

def execute_sql(sql):
    resp = requests.post(admin_url, headers=headers, json={"p_sql": sql}, timeout=30)
    return resp.json()

def call_rpc(rpc_name, params):
    resp = requests.post(f"{rpc_url}/{rpc_name}", headers=headers, json=params, timeout=30)
    return resp.json()

def count_blocks(storyboard):
    count = 0
    for scene in storyboard.get('scenes', []):
        count += len(scene.get('blocks', []))
    return count

def calculate_depth(storyboard):
    max_depth = 0
    
    def traverse(obj, depth):
        nonlocal max_depth
        max_depth = max(max_depth, depth)
        if isinstance(obj, dict):
            for v in obj.values():
                traverse(v, depth + 1)
        elif isinstance(obj, list):
            for v in obj:
                traverse(v, depth + 1)
    
    traverse(storyboard, 0)
    return max_depth

print("=== PHASE B.5A – STORYBOARD COMPATIBILITY AUDIT ===\n")

# Récupérer un student_id valide
sql = "SELECT id FROM app.students LIMIT 1"
result = execute_sql(sql)
student_id = result.get("rows", [{}])[0].get("id") if result.get("ok") and result.get("rows") else None
print(f"Student ID: {student_id}")

if not student_id:
    print("❌ Impossible de récupérer un student_id")
    exit(1)

# Export settings par défaut V1
export_settings = {
    "format": "mp4",
    "resolution": {"width": 1080, "height": 1920},
    "frame_rate": 30,
    "video_codec": "h264",
    "audio_codec": "aac"
}

# Storyboards de test
storyboards = {
    "mathematiques": {
        "version": "1.0",
        "created_at": datetime.now().isoformat(),
        "created_by": student_id,
        "subject": "Mathématiques",
        "renderer": "scientific",
        "theme": "scientific",
        "narration_mode": "none",
        "export_settings": export_settings,
        "scenes": [
            {
                "id": "scene-1",
                "order": 0,
                "title": "Introduction aux équations",
                "duration_ms": 5000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-1",
                        "type": "title",
                        "content": "Équations du second degré",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 24, "font_weight": "bold", "color": "#000000"}
                    },
                    {
                        "id": "block-2",
                        "type": "paragraph",
                        "content": "Une équation du second degré est de la forme ax² + bx + c = 0",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 16, "color": "#333333"}
                    },
                    {
                        "id": "block-3",
                        "type": "formula",
                        "content": "x = (-b ± √(b² - 4ac)) / 2a",
                        "format": "latex",
                        "order": 2,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 18, "color": "#0000FF"}
                    }
                ]
            },
            {
                "id": "scene-2",
                "order": 1,
                "title": "Exemple d'application",
                "duration_ms": 8000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-4",
                        "type": "definition",
                        "term": "Discriminant",
                        "definition": "Le discriminant Δ = b² - 4ac détermine le nombre de solutions",
                        "example": "Pour x² - 5x + 6 = 0, Δ = 25 - 24 = 1",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"term_color": "#FF0000", "definition_color": "#006600", "example_color": "#0000FF"}
                    },
                    {
                        "id": "block-5",
                        "type": "exercise",
                        "question": "Résoudre x² - 4x + 3 = 0",
                        "hint": "Calculez d'abord le discriminant",
                        "solution": "Δ = 16 - 12 = 4, x1 = 1, x2 = 3",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"question_color": "#660066", "hint_color": "#FF9900", "solution_color": "#009900"}
                    }
                ]
            }
        ]
    },
    "physique": {
        "version": "1.0",
        "created_at": datetime.now().isoformat(),
        "created_by": student_id,
        "subject": "Physique",
        "renderer": "scientific",
        "theme": "scientific",
        "narration_mode": "none",
        "export_settings": export_settings,
        "scenes": [
            {
                "id": "scene-1",
                "order": 0,
                "title": "Lois de Newton",
                "duration_ms": 6000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-1",
                        "type": "title",
                        "content": "Première loi de Newton",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 24, "font_weight": "bold", "color": "#000000"}
                    },
                    {
                        "id": "block-2",
                        "type": "paragraph",
                        "content": "Tout corps persévère dans son état de repos ou de mouvement rectiligne uniforme",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 16, "color": "#333333"}
                    },
                    {
                        "id": "block-3",
                        "type": "formula",
                        "content": "ΣF = 0",
                        "format": "latex",
                        "order": 2,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 18, "color": "#0000FF"}
                    }
                ]
            },
            {
                "id": "scene-2",
                "order": 1,
                "title": "Exercice",
                "duration_ms": 7000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-4",
                        "type": "exercise",
                        "question": "Un objet de masse 5kg est immobile. Quelles sont les forces qui s'appliquent?",
                        "hint": "Pensez à la gravité et à la réaction du support",
                        "solution": "Poids P = mg = 5×9.8 = 49N, Réaction R = 49N vers le haut",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"question_color": "#660066", "hint_color": "#FF9900", "solution_color": "#009900"}
                    }
                ]
            }
        ]
    },
    "chimie": {
        "version": "1.0",
        "created_at": datetime.now().isoformat(),
        "created_by": student_id,
        "subject": "Chimie",
        "renderer": "scientific",
        "theme": "scientific",
        "narration_mode": "none",
        "export_settings": export_settings,
        "scenes": [
            {
                "id": "scene-1",
                "order": 0,
                "title": "Tableau périodique",
                "duration_ms": 5000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-1",
                        "type": "title",
                        "content": "Les éléments chimiques",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 24, "font_weight": "bold", "color": "#000000"}
                    },
                    {
                        "id": "block-2",
                        "type": "definition",
                        "term": "Numéro atomique",
                        "definition": "Nombre de protons dans le noyau d'un atome",
                        "example": "Le carbone a 6 protons, donc Z = 6",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"term_color": "#FF0000", "definition_color": "#006600", "example_color": "#0000FF"}
                    }
                ]
            }
        ]
    },
    "histoire": {
        "version": "1.0",
        "created_at": datetime.now().isoformat(),
        "created_by": student_id,
        "subject": "Histoire",
        "renderer": "notebook",
        "theme": "notebook",
        "narration_mode": "none",
        "export_settings": export_settings,
        "scenes": [
            {
                "id": "scene-1",
                "order": 0,
                "title": "La Révolution française",
                "duration_ms": 8000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-1",
                        "type": "title",
                        "content": "1789 : L'année de tous les changements",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 24, "font_weight": "bold", "color": "#000000"}
                    },
                    {
                        "id": "block-2",
                        "type": "paragraph",
                        "content": "La prise de la Bastille le 14 juillet 1789 marque le début de la Révolution française",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 16, "color": "#333333"}
                    },
                    {
                        "id": "block-3",
                        "type": "paragraph",
                        "content": "La Déclaration des droits de l'homme et du citoyen est adoptée le 26 août 1789",
                        "order": 2,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 16, "color": "#333333"}
                    }
                ]
            }
        ]
    },
    "langues": {
        "version": "1.0",
        "created_at": datetime.now().isoformat(),
        "created_by": student_id,
        "subject": "Langues",
        "renderer": "notebook",
        "theme": "notebook",
        "narration_mode": "none",
        "export_settings": export_settings,
        "scenes": [
            {
                "id": "scene-1",
                "order": 0,
                "title": "Grammaire anglaise",
                "duration_ms": 6000,
                "transition": None,
                "blocks": [
                    {
                        "id": "block-1",
                        "type": "title",
                        "content": "Present Perfect",
                        "order": 0,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"font_size": 24, "font_weight": "bold", "color": "#000000"}
                    },
                    {
                        "id": "block-2",
                        "type": "definition",
                        "term": "Forme",
                        "definition": "have/has + participe passé",
                        "example": "I have eaten, She has gone",
                        "order": 1,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"term_color": "#FF0000", "definition_color": "#006600", "example_color": "#0000FF"}
                    },
                    {
                        "id": "block-3",
                        "type": "exercise",
                        "question": "Conjuguez 'to go' au present perfect pour 'they'",
                        "hint": "Utilisez 'have' + participe passé",
                        "solution": "They have gone",
                        "order": 2,
                        "visible": True,
                        "animation": None,
                        "position": None,
                        "style": {"question_color": "#660066", "hint_color": "#FF9900", "solution_color": "#009900"}
                    }
                ]
            }
        ]
    }
}

# Tester chaque storyboard
results = {}
for subject, storyboard in storyboards.items():
    print(f"\n=== TEST STORYBOARD: {subject.upper()} ===")
    
    # Mesurer le storyboard
    json_size = len(json.dumps(storyboard))
    block_count = count_blocks(storyboard)
    depth = calculate_depth(storyboard)
    
    print(f"Taille JSON: {json_size} octets")
    print(f"Nombre de blocs: {block_count}")
    print(f"Profondeur JSON: {depth}")
    
    # Créer le projet
    start_time = time.time()
    params = {
        "p_subject": subject,
        "p_renderer_id": storyboard["renderer"],
        "p_theme_id": storyboard["theme"],
        "p_narration_mode": storyboard["narration_mode"],
        "p_storyboard_json": storyboard,
        "p_student_id": student_id
    }
    result = call_rpc("whiteboard_create_project", params)
    create_time = (time.time() - start_time) * 1000
    
    print(f"Création: {create_time:.2f}ms")
    print(f"Résultat: {result}")
    
    if result.get("success"):
        project_id = result.get("project_id")
        print(f"✅ Projet créé: {project_id}")
        
        # Lire le projet
        start_time = time.time()
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        result = call_rpc("whiteboard_get_project", params)
        read_time = (time.time() - start_time) * 1000
        
        print(f"Lecture: {read_time:.2f}ms")
        
        if result.get("success"):
            stored_storyboard = result.get("project", {}).get("storyboard_json")
            print(f"✅ Projet lu")
            
            # Vérifier l'intégrité
            if stored_storyboard == storyboard:
                print(f"✅ Intégrité vérifiée")
            else:
                print(f"❌ Intégrité compromise")
            
            # Modifier le projet
            start_time = time.time()
            modified_storyboard = storyboard.copy()
            modified_storyboard["scenes"][0]["blocks"][0]["content"] = f"{subject} - Modifié"
            params = {
                "p_project_id": project_id,
                "p_storyboard_json": modified_storyboard,
                "p_student_id": student_id
            }
            result = call_rpc("whiteboard_update_project", params)
            update_time = (time.time() - start_time) * 1000
            
            print(f"Mise à jour: {update_time:.2f}ms")
            
            if result.get("success"):
                print(f"✅ Projet modifié")
                
                # Créer un render job
                start_time = time.time()
                params = {
                    "p_project_id": project_id,
                    "p_student_id": student_id
                }
                result = call_rpc("whiteboard_create_render_job", params)
                render_time = (time.time() - start_time) * 1000
                
                print(f"Render Job: {render_time:.2f}ms")
                
                if result.get("success"):
                    render_id = result.get("render_id")
                    print(f"✅ Render Job créé: {render_id}")
                else:
                    print(f"❌ Render Job échoué")
            else:
                print(f"❌ Modification échouée")
        else:
            print(f"❌ Lecture échouée")
        
        # Nettoyer
        params = {
            "p_project_id": project_id,
            "p_student_id": student_id
        }
        call_rpc("whiteboard_delete_project", params)
        print(f"✅ Projet supprimé")
        
        results[subject] = {
            "json_size": json_size,
            "block_count": block_count,
            "depth": depth,
            "create_time": create_time,
            "read_time": read_time,
            "update_time": update_time,
            "render_time": render_time,
            "success": True
        }
    else:
        print(f"❌ Création échouée")
        results[subject] = {
            "success": False
        }

print("\n=== RÉSUMÉ DES TESTS ===\n")
for subject, result in results.items():
    if result.get("success"):
        print(f"{subject.upper()}: ✅")
        print(f"  Taille: {result['json_size']} octets")
        print(f"  Blocs: {result['block_count']}")
        print(f"  Profondeur: {result['depth']}")
        print(f"  Création: {result['create_time']:.2f}ms")
        print(f"  Lecture: {result['read_time']:.2f}ms")
        print(f"  Mise à jour: {result['update_time']:.2f}ms")
        print(f"  Render Job: {result['render_time']:.2f}ms")
    else:
        print(f"{subject.upper()}: ❌")

print("\n=== TESTS TERMINÉS ===\n")
