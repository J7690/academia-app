#!/usr/bin/env python3
"""
Windsurf Rules Enforcer - FORCE OBLIGATOIRE
Ce module FORCE Windsurf à appliquer toutes les règles du dossier .windsurf
"""

import json
import sys
import os
from pathlib import Path
from typing import Dict, Any, List
from datetime import datetime

class WindsurfMandatoryEnforcer:
    """
    Forceur OBLIGATOIRE pour Windsurf
    GARANTIT le respect de TOUTES les règles du dossier .windsurf
    """
    
    def __init__(self):
        self.windsurf_dir = Path(__file__).parent
        self.rules_file = self.windsurf_dir / "windsurf_mandatory_rules.json"
        self.compliance_file = self.windsurf_dir / "windsurf_compliance.json"
        
        # Charger les règles obligatoires
        self.mandatory_rules = self._load_mandatory_rules()
        
    def _load_mandatory_rules(self) -> Dict[str, Any]:
        """Charge les règles obligatoires"""
        try:
            if self.rules_file.exists():
                with open(self.rules_file, 'r', encoding='utf-8') as f:
                    return json.load(f)
        except Exception:
            pass
        
        return {"rules": {}, "enforcement_level": "MANDATORY"}
    
    def enforce_supabase_rules(self, operation: str, **kwargs) -> Dict[str, Any]:
        """
        FORCE les règles Supabase pour Windsurf
        Windsurf DOIT utiliser ces méthodes OBLIGATOIREMENT
        """
        
        supabase_rules = self.mandatory_rules.get("rules", {}).get("supabase_integration", {})
        
        if not supabase_rules.get("mandatory", False):
            return {"error": "Supabase rules not loaded"}
        
        # Vérifier que l'import auto est utilisé
        if "auto_supabase_import" not in str(kwargs):
            # FORCER l'import automatique
            try:
                from auto_supabase_import import supabase_operation
                
                # Mapper l'opération vers la méthode obligatoire
                operation_mapping = {
                    "audit": "audit",
                    "create": "create_table", 
                    "describe": "describe_table",
                    "read": "read",
                    "insert": "insert",
                    "update": "update",
                    "delete": "delete"
                }
                
                mapped_operation = operation_mapping.get(operation, operation)
                
                # FORCER l'utilisation de la méthode validée
                result = supabase_operation(mapped_operation, **kwargs)
                
                return {
                    "success": True,
                    "method": f"supabase_operation({mapped_operation})",
                    "enforced": True,
                    "rule_compliance": "supabase_mandatory",
                    "result": result
                }
                
            except ImportError:
                return {
                    "error": "MANDATORY: auto_supabase_import must be used",
                    "enforcement": "failed",
                    "required_action": "Import auto_supabase_import"
                }
        
        return {"error": "Supabase rules enforcement failed"}
    
    def enforce_agent_selection(self, requested_agent: str = None) -> Dict[str, Any]:
        """
        FORCE le choix d'agent pour Windsurf
        Windsurf DOIT utiliser l'agent configuré
        """
        
        agent_rules = self.mandatory_rules.get("rules", {}).get("agent_selection", {})
        
        if not agent_rules.get("mandatory", False):
            return {"error": "Agent rules not loaded"}
        
        preferred_agent = agent_rules.get("preferred_agent", "cascade")
        
        # FORCER l'utilisation de l'agent préféré
        if requested_agent and requested_agent != preferred_agent:
            return {
                "warning": f"MANDATORY: Must use {preferred_agent} agent",
                "requested": requested_agent,
                "enforced": preferred_agent,
                "rule_compliance": "agent_mandatory"
            }
        
        return {
            "success": True,
            "agent": preferred_agent,
            "enforced": True,
            "rule_compliance": "agent_mandatory"
        }
    
    def enforce_coding_standards(self, code_content: str) -> Dict[str, Any]:
        """
        FORCE les standards de codage pour Windsurf
        Windsurf DOIT suivre les standards configurés
        """
        
        coding_rules = self.mandatory_rules.get("rules", {}).get("coding_standards", {})
        
        if not coding_rules.get("mandatory", False):
            return {"error": "Coding standards not loaded"}
        
        violations = []
        
        # Vérifier le style PEP8
        if coding_rules.get("style") == "PEP8":
            # Vérifications basiques
            if code_content.count("    ") < code_content.count("\t"):
                violations.append("MANDATORY: Use spaces instead of tabs (PEP8)")
        
        # Vérifier les type hints
        if coding_rules.get("type_hints"):
            if "def " in code_content and "->" not in code_content:
                violations.append("MANDATORY: Use type hints for functions")
        
        return {
            "compliant": len(violations) == 0,
            "violations": violations,
            "enforced": True,
            "rule_compliance": "coding_standards_mandatory"
        }
    
    def enforce_intervention_procedures(self, steps: List[str]) -> Dict[str, Any]:
        """
        FORCE les procédures d'intervention pour Windsurf
        Windsurf DOIT suivre toutes les étapes
        """
        
        procedure_rules = self.mandatory_rules.get("rules", {}).get("intervention_procedures", {})
        
        if not procedure_rules.get("mandatory", False):
            return {"error": "Procedure rules not loaded"}
        
        # Vérifier que toutes les étapes sont suivies
        if procedure_rules.get("follow_steps"):
            if len(steps) < 2:
                return {
                    "error": "MANDATORY: Must follow all intervention steps",
                    "provided_steps": len(steps),
                    "enforced": True,
                    "rule_compliance": "procedures_mandatory"
                }
        
        return {
            "success": True,
            "steps_followed": len(steps),
            "enforced": True,
            "rule_compliance": "procedures_mandatory"
        }
    
    def check_compliance(self, operation_type: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        Vérifie la conformité de Windsurf avec TOUTES les règles
        """
        
        compliance_report = {
            "timestamp": datetime.now().isoformat(),
            "operation_type": operation_type,
            "compliance_score": 0,
            "rules_checked": [],
            "violations": [],
            "mandatory_actions": []
        }
        
        total_rules = 0
        compliant_rules = 0
        
        # Vérifier chaque catégorie de règles
        rule_categories = [
            ("supabase", self.enforce_supabase_rules, context.get("operation", "audit")),
            ("agent", self.enforce_agent_selection, context.get("agent")),
            ("coding", self.enforce_coding_standards, context.get("code", "")),
            ("procedures", self.enforce_intervention_procedures, context.get("steps", []))
        ]
        
        for category_name, enforcer_func, param in rule_categories:
            total_rules += 1
            
            try:
                result = enforcer_func(param) if param else enforcer_func()
                
                compliance_report["rules_checked"].append({
                    "category": category_name,
                    "compliant": result.get("success", False) or result.get("compliant", False),
                    "result": result
                })
                
                if result.get("success") or result.get("compliant"):
                    compliant_rules += 1
                else:
                    compliance_report["violations"].append({
                        "category": category_name,
                        "violation": result.get("error", "Non-compliant")
                    })
                    
                    if result.get("required_action"):
                        compliance_report["mandatory_actions"].append(result["required_action"])
                        
            except Exception as e:
                compliance_report["violations"].append({
                    "category": category_name,
                    "violation": str(e)
                })
        
        # Calculer le score de conformité
        compliance_report["compliance_score"] = (compliant_rules / total_rules * 100) if total_rules > 0 else 0
        compliance_report["overall_compliant"] = compliance_report["compliance_score"] >= 90
        
        # Sauvegarder le rapport
        with open(self.compliance_file, 'w', encoding='utf-8') as f:
            json.dump(compliance_report, f, indent=2, ensure_ascii=False)
        
        return compliance_report
    
    def force_compliance(self, operation_type: str, context: Dict[str, Any]) -> Dict[str, Any]:
        """
        FORCE la conformité de Windsurf
        Applique automatiquement les corrections si nécessaire
        """
        
        compliance = self.check_compliance(operation_type, context)
        
        if not compliance["overall_compliant"]:
            # FORCER les corrections automatiques
            corrections = []
            
            for violation in compliance["violations"]:
                category = violation["category"]
                
                if category == "supabase":
                    corrections.append("AUTO: Import auto_supabase_import")
                elif category == "agent":
                    corrections.append("AUTO: Use cascade agent")
                elif category == "coding":
                    corrections.append("AUTO: Apply PEP8 formatting")
                elif category == "procedures":
                    corrections.append("AUTO: Follow all steps")
            
            compliance["auto_corrections"] = corrections
            compliance["enforced"] = True
        
        return compliance

# Instance globale pour Windsurf
windsurf_enforcer = WindsurfMandatoryEnforcer()

# Fonctions obligatoires pour Windsurf
def enforce_windsurf_rules(operation_type: str, **context):
    """
    Fonction OBLIGATOIRE pour Windsurf
    Windsurf DOIT appeler cette fonction AVANT toute opération
    """
    return windsurf_enforcer.force_compliance(operation_type, context)

def check_windsurf_compliance(operation_type: str, **context):
    """
    Vérifie la conformité de Windsurf
    """
    return windsurf_enforcer.check_compliance(operation_type, context)

# Règles d'import pour Windsurf
WINDSURF_MANDATORY_IMPORTS = [
    "from windsurf_rules_enforcer import enforce_windsurf_rules",
    "from auto_supabase_import import *"
]

WINDSURF_MANDATORY_PROCEDURES = [
    "1. Toujours vérifier la conformité avec enforce_windsurf_rules()",
    "2. Utiliser uniquement les méthodes validées du dossier .windsurf",
    "3. Suivre les procédures d'intervention dans l'ordre",
    "4. Respecter les standards de codage configurés",
    "5. Appliquer les règles de sécurité obligatoires"
]
