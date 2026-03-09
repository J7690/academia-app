#!/usr/bin/env python3
"""
Scheduler Automatique Supabase
Exécute les tâches automatiquement à intervalles réguliers
"""

import schedule
import time
import json
from datetime import datetime
from pathlib import Path
from typing import Dict, Any
from supabase_auto_manager_fixed import SupabaseAutoManagerFixed

class SupabaseAutoScheduler:
    """
    Scheduler qui exécute automatiquement les tâches Supabase
    sans aucune intervention manuelle
    """
    
    def __init__(self):
        self.windsurf_dir = Path(__file__).parent
        self.log_file = self.windsurf_dir / "auto_scheduler_log.json"
        self.manager = SupabaseAutoManagerFixed()
        
        # Charger l'historique
        self.history = self.load_history()
    
    def load_history(self) -> Dict[str, Any]:
        """Charge l'historique des exécutions"""
        try:
            if self.log_file.exists():
                with open(self.log_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception:
            pass
        
        return {
            "started_at": datetime.now().isoformat(),
            "executions": [],
            "stats": {
                "total_executions": 0,
                "successful_executions": 0,
                "failed_executions": 0
            }
        }
    
    def save_history(self):
        """Sauvegarde l'historique des exécutions"""
        try:
            with open(self.log_file, 'w', encoding='utf-8') as f:
                json.dump(self.history, f, indent=2, ensure_ascii=False)
        except Exception as e:
            print(f"⚠️ Erreur sauvegarde historique: {e}")
    
    def log_execution(self, task_name: str, result: Dict[str, Any]):
        """Enregistre une exécution dans l'historique"""
        execution = {
            "timestamp": datetime.now().isoformat(),
            "task": task_name,
            "status": result.get("final_status", "unknown"),
            "steps_completed": len(result.get("steps_completed", [])),
            "steps_failed": len(result.get("steps_failed", [])),
            "details": result
        }
        
        self.history["executions"].append(execution)
        self.history["stats"]["total_executions"] += 1
        
        if result.get("final_status") == "success":
            self.history["stats"]["successful_executions"] += 1
        else:
            self.history["stats"]["failed_executions"] += 1
        
        # Garder seulement les 100 dernières exécutions
        if len(self.history["executions"]) > 100:
            self.history["executions"] = self.history["executions"][-100:]
        
        self.save_history()
    
    def hourly_health_check(self):
        """Vérification de santé toutes les heures"""
        print(f"🔍 [{datetime.now().strftime('%H:%M')}] Health check automatique...")
        
        result = self.manager.manage_flutter_supabase_tasks_auto("vérifier l'état du système Supabase")
        
        self.log_execution("health_check", result)
        
        if result["final_status"] == "success":
            print("✅ Health check réussi")
        else:
            print("⚠️ Health check avec problèmes")
    
    def daily_audit(self):
        """Audit complet quotidien"""
        print(f"📊 [{datetime.now().strftime('%H:%M')}] Audit automatique quotidien...")
        
        result = self.manager.manage_flutter_supabase_tasks_auto("auditer la base de données")
        
        self.log_execution("daily_audit", result)
        
        if result["final_status"] == "success":
            print("✅ Audit quotidien réussi")
        else:
            print("⚠️ Audit quotidien avec problèmes")
    
    def weekly_optimization(self):
        """Optimization hebdomadaire"""
        print(f"🚀 [{datetime.now().strftime('%H:%M')}] Optimization hebdomadaire...")
        
        # Vérification complète
        result = self.manager.manage_flutter_supabase_tasks_auto("optimisation complète du système")
        
        self.log_execution("weekly_optimization", result)
        
        if result["final_status"] == "success":
            print("✅ Optimization hebdomadaire réussie")
        else:
            print("⚠️ Optimization hebdomadaire avec problèmes")
    
    def generate_report(self):
        """Génère un rapport d'activité"""
        stats = self.history["stats"]
        success_rate = (stats["successful_executions"] / stats["total_executions"] * 100) if stats["total_executions"] > 0 else 0
        
        report = f"""
# 📊 RAPPORT D'ACTIVITÉ AUTOMATIQUE SUPABASE

## 📈 Statistiques
- **Exécutions totales**: {stats['total_executions']}
- **Exécutions réussies**: {stats['successful_executions']}
- **Exécutions échouées**: {stats['failed_executions']}
- **Taux de réussite**: {success_rate:.1f}%

## 🕐 Dernières exécutions
"""
        
        for execution in self.history["executions"][-5:]:
            timestamp = execution["timestamp"][:19].replace("T", " ")
            status_emoji = "✅" if execution["status"] == "success" else "⚠️"
            report += f"- {status_emoji} {timestamp} - {execution['task']} ({execution['steps_completed']}/{execution['steps_completed'] + execution['steps_failed']} étapes)\n"
        
        # Sauvegarder le rapport
        report_file = self.windsurf_dir / "auto_activity_report.md"
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write(report)
        
        print(f"📋 Rapport généré: {report_file}")
        return report
    
    def setup_schedule(self):
        """Configure le planning des tâches automatiques"""
        print("⏰ Configuration du planning automatique...")
        
        # Toutes les heures: health check
        schedule.every().hour.do(self.hourly_health_check)
        
        # Tous les jours à 2h du matin: audit complet
        schedule.every().day.at("02:00").do(self.daily_audit)
        
        # Tous les dimanches à 3h du matin: optimization
        schedule.every().sunday.at("03:00").do(self.weekly_optimization)
        
        # Toutes les 6 heures: génération de rapport
        schedule.every(6).hours.do(self.generate_report)
        
        print("✅ Planning configuré:")
        print("   • Health check: toutes les heures")
        print("   • Audit complet: tous les jours à 02:00")
        print("   • Optimization: tous les dimanches à 03:00")
        print("   • Rapport: toutes les 6 heures")
    
    def run_scheduler(self):
        """Démarre le scheduler"""
        print("🚀 Démarrage du scheduler automatique Supabase...")
        print("🔄 Le système va exécuter les tâches automatiquement")
        print("⏹️  Ctrl+C pour arrêter")
        
        # Exécuter une première fois
        self.hourly_health_check()
        
        try:
            while True:
                schedule.run_pending()
                time.sleep(60)  # Vérifier chaque minute
                
        except KeyboardInterrupt:
            print("\n⏹️  Arrêt du scheduler")
            self.generate_report()
            print("📋 Rapport final généré")
    
    def run_once(self):
        """Exécute toutes les tâches une fois"""
        print("🚀 Exécution unique de toutes les tâches...")
        
        tasks = [
            ("Health Check", self.hourly_health_check),
            ("Audit Complet", self.daily_audit),
            ("Optimization", self.weekly_optimization)
        ]
        
        for task_name, task_func in tasks:
            print(f"\n📋 Exécution: {task_name}")
            task_func()
            time.sleep(2)  # Pause entre les tâches
        
        print("\n📊 Génération du rapport...")
        self.generate_report()
        
        print("\n🎉 Toutes les tâches exécutées avec succès!")

def main():
    """Point d'entrée principal"""
    import sys
    
    scheduler = SupabaseAutoScheduler()
    
    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        # Exécuter une fois
        scheduler.run_once()
    else:
        # Démarrer le scheduler continu
        scheduler.setup_schedule()
        scheduler.run_scheduler()

if __name__ == "__main__":
    main()
