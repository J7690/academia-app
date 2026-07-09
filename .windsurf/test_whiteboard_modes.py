#!/usr/bin/env python3
"""
Script de test des 4 modes du Smart Whiteboard via l'API Supabase

Ce script teste :
- Mode A : Sujet simple
- Mode B : Texte complet
- Mode C : Plan
- Mode D : Cours existant
"""

import asyncio
import json
import time
from typing import Dict, Any, Optional
import httpx

# Configuration
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
# TODO: Remplacer par la vraie clé service_role
SUPABASE_KEY = "YOUR_SERVICE_ROLE_KEY"

class WhiteboardTester:
    def __init__(self):
        self.client = httpx.Client(
            base_url=SUPABASE_URL,
            headers={
                "apikey": SUPABASE_KEY,
                "Authorization": f"Bearer {SUPABASE_KEY}",
                "Content-Type": "application/json",
            }
        )
        self.results = {
            "Mode A": {},
            "Mode B": {},
            "Mode C": {},
            "Mode D": {},
        }

    def call_rpc(self, rpc_name: str, params: Dict[str, Any]) -> Optional[Dict]:
        """Appelle une RPC Supabase"""
        try:
            response = self.client.post(
                f"/rest/v1/rpc/{rpc_name}",
                json=params
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            print(f"Erreur RPC {rpc_name}: {e}")
            return None

    def test_mode_a(self):
        """Test Mode A : Sujet simple"""
        print("\n=== TEST MODE A : SUJET SIMPLE ===")
        
        # Créer un projet
        params = {
            "p_user_id": "test_user",
            "p_subject": "Dérivée d'une fonction",
            "p_content": None,
            "p_mode": "simple",
            "p_theme_id": "scientific",
            "p_renderer_id": "scientific",
            "p_narration_mode": "none",
        }
        
        result = self.call_rpc("whiteboard_create_project", params)
        if result:
            project_id = result.get("id")
            print(f"✅ Projet créé: {project_id}")
            self.results["Mode A"]["creation"] = "OK"
        else:
            print("❌ Échec création projet")
            self.results["Mode A"]["creation"] = "FAIL"
            return

        # Générer le storyboard
        gen_params = {
            "p_project_id": project_id,
        }
        
        gen_result = self.call_rpc("whiteboard_generate_storyboard", gen_params)
        if gen_result:
            print("✅ Storyboard généré")
            self.results["Mode A"]["generation"] = "OK"
        else:
            print("❌ Échec génération storyboard")
            self.results["Mode A"]["generation"] = "FAIL"
            return

        # Créer un job de rendu
        render_params = {
            "p_project_id": project_id,
        }
        
        render_result = self.call_rpc("whiteboard_create_render_job", render_params)
        if render_result:
            render_id = render_result.get("id")
            print(f"✅ Job de rendu créé: {render_id}")
            self.results["Mode A"]["render"] = "OK"
        else:
            print("❌ Échec création job rendu")
            self.results["Mode A"]["render"] = "FAIL"
            return

        # Attendre le rendu
        print("⏳ Attente du rendu...")
        for i in range(30):  # 30 secondes max
            time.sleep(1)
            status = self.call_rpc("whiteboard_get_render_status", {"p_render_id": render_id})
            if status:
                status_value = status.get("status")
                print(f"  Statut: {status_value}")
                if status_value == "done":
                    print("✅ Rendu terminé")
                    self.results["Mode A"]["render_status"] = "done"
                    break
                elif status_value == "failed":
                    print(f"❌ Rendu échoué: {status.get('error_message')}")
                    self.results["Mode A"]["render_status"] = "failed"
                    break
        else:
            print("⏱️ Timeout rendu")
            self.results["Mode A"]["render_status"] = "timeout"

    def test_mode_b(self):
        """Test Mode B : Texte complet"""
        print("\n=== TEST MODE B : TEXTE COMPLET ===")
        
        params = {
            "p_user_id": "test_user",
            "p_subject": "Théorème de Pythagore",
            "p_content": "Le théorème de Pythagore est un théorème de géométrie euclidienne...",
            "p_mode": "full_text",
            "p_theme_id": "notebook",
            "p_renderer_id": "notebook",
            "p_narration_mode": "tts",
        }
        
        result = self.call_rpc("whiteboard_create_project", params)
        if result:
            project_id = result.get("id")
            print(f"✅ Projet créé: {project_id}")
            self.results["Mode B"]["creation"] = "OK"
        else:
            print("❌ Échec création projet")
            self.results["Mode B"]["creation"] = "FAIL"
            return

        # Générer le storyboard
        gen_params = {"p_project_id": project_id}
        gen_result = self.call_rpc("whiteboard_generate_storyboard", gen_params)
        if gen_result:
            print("✅ Storyboard généré")
            self.results["Mode B"]["generation"] = "OK"
        else:
            print("❌ Échec génération storyboard")
            self.results["Mode B"]["generation"] = "FAIL"
            return

        # Créer un job de rendu
        render_params = {"p_project_id": project_id}
        render_result = self.call_rpc("whiteboard_create_render_job", render_params)
        if render_result:
            render_id = render_result.get("id")
            print(f"✅ Job de rendu créé: {render_id}")
            self.results["Mode B"]["render"] = "OK"
        else:
            print("❌ Échec création job rendu")
            self.results["Mode B"]["render"] = "FAIL"
            return

    def test_mode_c(self):
        """Test Mode C : Plan"""
        print("\n=== TEST MODE C : PLAN ===")
        
        params = {
            "p_user_id": "test_user",
            "p_subject": "Les équations différentielles",
            "p_content": "I. Définition\nII. Types\nIII. Résolution\nIV. Applications",
            "p_mode": "plan",
            "p_theme_id": "scientific",
            "p_renderer_id": "scientific",
            "p_narration_mode": "recording",
        }
        
        result = self.call_rpc("whiteboard_create_project", params)
        if result:
            project_id = result.get("id")
            print(f"✅ Projet créé: {project_id}")
            self.results["Mode C"]["creation"] = "OK"
        else:
            print("❌ Échec création projet")
            self.results["Mode C"]["creation"] = "FAIL"
            return

        # Générer le storyboard
        gen_params = {"p_project_id": project_id}
        gen_result = self.call_rpc("whiteboard_generate_storyboard", gen_params)
        if gen_result:
            print("✅ Storyboard généré")
            self.results["Mode C"]["generation"] = "OK"
        else:
            print("❌ Échec génération storyboard")
            self.results["Mode C"]["generation"] = "FAIL"
            return

    def test_mode_d(self):
        """Test Mode D : Cours existant"""
        print("\n=== TEST MODE D : COURS EXISTANT ===")
        
        params = {
            "p_user_id": "test_user",
            "p_subject": "La photosynthèse",
            "p_content": "La photosynthèse est le processus par lequel les plantes...",
            "p_mode": "existing_course",
            "p_theme_id": "notebook",
            "p_renderer_id": "notebook",
            "p_narration_mode": "none",
        }
        
        result = self.call_rpc("whiteboard_create_project", params)
        if result:
            project_id = result.get("id")
            print(f"✅ Projet créé: {project_id}")
            self.results["Mode D"]["creation"] = "OK"
        else:
            print("❌ Échec création projet")
            self.results["Mode D"]["creation"] = "FAIL"
            return

        # Générer le storyboard
        gen_params = {"p_project_id": project_id}
        gen_result = self.call_rpc("whiteboard_generate_storyboard", gen_params)
        if gen_result:
            print("✅ Storyboard généré")
            self.results["Mode D"]["generation"] = "OK"
        else:
            print("❌ Échec génération storyboard")
            self.results["Mode D"]["generation"] = "FAIL"
            return

    def print_summary(self):
        """Affiche le résumé des tests"""
        print("\n=== RÉSUMÉ DES TESTS ===")
        for mode, results in self.results.items():
            print(f"\n{mode}:")
            for step, status in results.items():
                print(f"  {step}: {status}")

    def run_all_tests(self):
        """Exécute tous les tests"""
        print("DÉBUT DES TESTS SMART WHITEBOARD")
        self.test_mode_a()
        self.test_mode_b()
        self.test_mode_c()
        self.test_mode_d()
        self.print_summary()

if __name__ == "__main__":
    tester = WhiteboardTester()
    tester.run_all_tests()
