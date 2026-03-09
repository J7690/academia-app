"""
Système de Sélection d'Agents par Performance Optimale
Choisit l'agent le plus performant selon la complexité réelle de la tâche
"""

import re
from typing import Dict, List, Tuple
from dataclasses import dataclass
from enum import Enum

class ComplexityLevel(Enum):
    SIMPLE = "simple"
    MOYENNE = "moyenne"
    COMPLEXE = "complexe"
    CRITIQUE = "critique"
    ARCHITECTURALE = "architecturale"

class PerformanceTier(Enum):
    STANDARD = "standard"      # Performance de base
    AVANCE = "avance"          # Haute performance
    EXPERT = "expert"          # Performance experte
    MASTER = "master"          # Performance maximale

@dataclass
class AgentProfile:
    """Profil de performance d'un agent"""
    name: str
    tier: PerformanceTier
    specializations: List[str]
    performance_score: float  # 0-100
    complexity_handling: List[ComplexityLevel]
    execution_speed: str  # rapide, moyenne, optimisee
    accuracy_rate: float  # 0-100
    resource_usage: str  # faible, moyenne, elevee
    parallel_capability: bool
    learning_capacity: float  # 0-100

@dataclass
class TaskAnalysis:
    """Analyse détaillée de la complexité d'une tâche"""
    description: str
    complexity_level: ComplexityLevel
    performance_required: PerformanceTier
    systems_involved: List[str]
    risk_factors: List[str]
    precision_required: float  # 0-100
    time_sensitivity: str  # faible, moyenne, elevee
    integration_complexity: float  # 0-100
    data_volume: str  # faible, moyenne, elevee
    security_impact: str  # faible, moyenne, elevee

class PerformanceAgentSelector:
    """Sélecteur d'agents optimisé pour la performance"""
    
    def __init__(self):
        self.agents = self._initialize_agents()
        self.complexity_analyzer = ComplexityAnalyzer()
        self.performance_matcher = PerformanceMatcher()
    
    def _initialize_agents(self) -> Dict[str, AgentProfile]:
        """Initialise les profils d'agents avec leurs caractéristiques de performance"""
        return {
            # Agents Flutter
            "flutter_ui_novice": AgentProfile(
                name="flutter_ui_novice",
                tier=PerformanceTier.STANDARD,
                specializations=["widgets simples", "layout basique", "thèmes standards"],
                performance_score=65.0,
                complexity_handling=[ComplexityLevel.SIMPLE],
                execution_speed="rapide",
                accuracy_rate=75.0,
                resource_usage="faible",
                parallel_capability=False,
                learning_capacity=60.0
            ),
            
            "flutter_ui_expert": AgentProfile(
                name="flutter_ui_expert",
                tier=PerformanceTier.EXPERT,
                specializations=["widgets complexes", "animations avancées", "responsive design", "performance UI"],
                performance_score=92.0,
                complexity_handling=[ComplexityLevel.SIMPLE, ComplexityLevel.MOYENNE, ComplexityLevel.COMPLEXE],
                execution_speed="optimisee",
                accuracy_rate=95.0,
                resource_usage="moyenne",
                parallel_capability=True,
                learning_capacity=88.0
            ),
            
            "flutter_ui_master": AgentProfile(
                name="flutter_ui_master",
                tier=PerformanceTier.MASTER,
                specializations=["architecture UI", "custom painters", "performance critique", "animations complexes"],
                performance_score=98.0,
                complexity_handling=[ComplexityLevel.MOYENNE, ComplexityLevel.COMPLEXE, ComplexityLevel.CRITIQUE, ComplexityLevel.ARCHITECTURALE],
                execution_speed="optimisee",
                accuracy_rate=99.0,
                resource_usage="elevee",
                parallel_capability=True,
                learning_capacity=95.0
            ),
            
            # Agents Supabase
            "supabase_standard": AgentProfile(
                name="supabase_standard",
                tier=PerformanceTier.STANDARD,
                specializations=["CRUD basique", "tables simples", "fonctions standards"],
                performance_score=70.0,
                complexity_handling=[ComplexityLevel.SIMPLE],
                execution_speed="rapide",
                accuracy_rate=80.0,
                resource_usage="faible",
                parallel_capability=False,
                learning_capacity=65.0
            ),
            
            "supabase_expert": AgentProfile(
                name="supabase_expert",
                tier=PerformanceTier.EXPERT,
                specializations=["requêtes complexes", "optimisation", "triggers", "RLS avancé"],
                performance_score=90.0,
                complexity_handling=[ComplexityLevel.MOYENNE, ComplexityLevel.COMPLEXE],
                execution_speed="optimisee",
                accuracy_rate=94.0,
                resource_usage="moyenne",
                parallel_capability=True,
                learning_capacity=85.0
            ),
            
            "supabase_master": AgentProfile(
                name="supabase_master",
                tier=PerformanceTier.MASTER,
                specializations=["architecture DB", "migration complexe", "performance critique", "sécurité avancée"],
                performance_score=96.0,
                complexity_handling=[ComplexityLevel.COMPLEXE, ComplexityLevel.CRITIQUE, ComplexityLevel.ARCHITECTURALE],
                execution_speed="optimisee",
                accuracy_rate=98.0,
                resource_usage="elevee",
                parallel_capability=True,
                learning_capacity=92.0
            ),
            
            # Agents d'Intégration
            "integration_standard": AgentProfile(
                name="integration_standard",
                tier=PerformanceTier.STANDARD,
                specializations=["API simples", "connexion basique", "sync standard"],
                performance_score=68.0,
                complexity_handling=[ComplexityLevel.SIMPLE],
                execution_speed="rapide",
                accuracy_rate=78.0,
                resource_usage="faible",
                parallel_capability=False,
                learning_capacity=62.0
            ),
            
            "integration_expert": AgentProfile(
                name="integration_expert",
                tier=PerformanceTier.EXPERT,
                specializations=["API complexes", "optimisation réseau", "gestion d'erreurs avancée", "caching"],
                performance_score=89.0,
                complexity_handling=[ComplexityLevel.MOYENNE, ComplexityLevel.COMPLEXE],
                execution_speed="optimisee",
                accuracy_rate=93.0,
                resource_usage="moyenne",
                parallel_capability=True,
                learning_capacity=84.0
            ),
            
            "integration_master": AgentProfile(
                name="integration_master",
                tier=PerformanceTier.MASTER,
                specializations=["architecture microservices", "performance réseau", "sécurité avancée", "scalabilité"],
                performance_score=95.0,
                complexity_handling=[ComplexityLevel.COMPLEXE, ComplexityLevel.CRITIQUE, ComplexityLevel.ARCHITECTURALE],
                execution_speed="optimisee",
                accuracy_rate=97.0,
                resource_usage="elevee",
                parallel_capability=True,
                learning_capacity=90.0
            ),
            
            # Agent Architecte
            "system_architect": AgentProfile(
                name="system_architect",
                tier=PerformanceTier.MASTER,
                specializations=["architecture globale", "patterns avancés", "scalabilité", "décisions techniques"],
                performance_score=97.0,
                complexity_handling=[ComplexityLevel.CRITIQUE, ComplexityLevel.ARCHITECTURALE],
                execution_speed="optimisee",
                accuracy_rate=96.0,
                resource_usage="elevee",
                parallel_capability=True,
                learning_capacity=94.0
            )
        }
    
    def select_optimal_agents(self, task_description: str) -> Tuple[List[str], TaskAnalysis]:
        """
        Sélectionne les agents les plus performants pour la tâche
        
        Returns:
            Tuple[List[str], TaskAnalysis]: (agents sélectionnés, analyse de la tâche)
        """
        # 1. Analyse approfondie de la complexité
        task_analysis = self.complexity_analyzer.analyze_task_complexity(task_description)
        
        # 2. Détermination du niveau de performance requis
        required_tier = self._determine_required_performance_tier(task_analysis)
        
        # 3. Sélection des agents optimisés pour performance
        selected_agents = self.performance_matcher.match_agents_to_performance(
            self.agents, task_analysis, required_tier
        )
        
        # 4. Optimisation de la combinaison d'agents
        optimized_agents = self._optimize_agent_combination(selected_agents, task_analysis)
        
        return optimized_agents, task_analysis
    
    def _determine_required_performance_tier(self, analysis: TaskAnalysis) -> PerformanceTier:
        """Détermine le niveau de performance requis basé sur l'analyse"""
        
        # Calcul du score de performance requis
        performance_score = (
            analysis.precision_required * 0.3 +
            analysis.integration_complexity * 0.25 +
            (100 if analysis.time_sensitivity == "elevee" else 50 if analysis.time_sensitivity == "moyenne" else 25) * 0.2 +
            (100 if analysis.security_impact == "elevee" else 60 if analysis.security_impact == "moyenne" else 30) * 0.15 +
            (100 if analysis.data_volume == "elevee" else 60 if analysis.data_volume == "moyenne" else 30) * 0.1
        )
        
        # Mapping vers le tier approprié
        if performance_score >= 85:
            return PerformanceTier.MASTER
        elif performance_score >= 70:
            return PerformanceTier.EXPERT
        else:
            return PerformanceTier.STANDARD
    
    def _optimize_agent_combination(self, agents: List[str], analysis: TaskAnalysis) -> List[str]:
        """Optimise la combinaison d'agents pour performance maximale"""
        
        # Si la tâche est complexe, ajouter toujours l'architecte
        if analysis.complexity_level in [ComplexityLevel.CRITIQUE, ComplexityLevel.ARCHITECTURALE]:
            if "system_architect" not in agents:
                agents.append("system_architect")
        
        # Prioriser les agents de plus haut tier disponibles
        def get_agent_tier_priority(agent_name: str) -> int:
            agent = self.agents.get(agent_name)
            if not agent:
                return 0
            tier_priority = {
                PerformanceTier.MASTER: 4,
                PerformanceTier.EXPERT: 3,
                PerformanceTier.AVANCE: 2,
                PerformanceTier.STANDARD: 1
            }
            return tier_priority.get(agent.tier, 0)
        
        # Trier par performance (plus performant d'abord)
        agents.sort(key=get_agent_tier_priority, reverse=True)
        
        return agents


class ComplexityAnalyzer:
    """Analyseur de complexité de tâches"""
    
    def analyze_task_complexity(self, description: str) -> TaskAnalysis:
        """Analyse en profondeur la complexité de la tâche"""
        
        # Nettoyage et normalisation du texte
        clean_desc = description.lower().strip()
        
        # Analyse multi-dimensionnelle
        complexity_level = self._evaluate_complexity_level(clean_desc)
        systems_involved = self._identify_systems(clean_desc)
        risk_factors = self._identify_risk_factors(clean_desc)
        precision_required = self._evaluate_precision_requirement(clean_desc)
        time_sensitivity = self._evaluate_time_sensitivity(clean_desc)
        integration_complexity = self._evaluate_integration_complexity(clean_desc)
        data_volume = self._evaluate_data_volume(clean_desc)
        security_impact = self._evaluate_security_impact(clean_desc)
        
        # Détermination du tier de performance requis
        performance_required = self._determine_performance_tier(
            complexity_level, precision_required, security_impact
        )
        
        return TaskAnalysis(
            description=description,
            complexity_level=complexity_level,
            performance_required=performance_required,
            systems_involved=systems_involved,
            risk_factors=risk_factors,
            precision_required=precision_required,
            time_sensitivity=time_sensitivity,
            integration_complexity=integration_complexity,
            data_volume=data_volume,
            security_impact=security_impact
        )
    
    def _evaluate_complexity_level(self, description: str) -> ComplexityLevel:
        """Évalue le niveau de complexité basé sur des indicateurs sémantiques"""
        
        # Mots et expressions indicateurs par niveau
        complexity_indicators = {
            ComplexityLevel.ARCHITECTURALE: [
                "architecture", "refactorisation complète", "migration", "reconception",
                "système entier", "fondamental", "structure globale", "patterns",
                "scalabilité", "décision architecturale"
            ],
            ComplexityLevel.CRITIQUE: [
                "critique", "urgent", "production", "sécurité", "performance critique",
                "perte de données", "corruption", "faille", "vulnérabilité",
                "dysfonctionnement majeur", "impact utilisateur"
            ],
            ComplexityLevel.COMPLEXE: [
                "complexe", "multiple", "plusieurs", "différents", "intégration",
                "optimisation", "avancé", "personnalisé", "algorithmique",
                "multi-étapes", "interdépendant", "cascade"
            ],
            ComplexityLevel.MOYENNE: [
                "améliorer", "modifier", "ajouter fonctionnalité", "mettre à jour",
                "adapter", "connecter", "intégrer", "optimiser légèrement"
            ],
            ComplexityLevel.SIMPLE: [
                "simple", "basique", "ajouter", "supprimer", "modifier",
                "changer", "mettre à jour", "corriger", "ajuster"
            ]
        }
        
        # Calcul du score par niveau
        level_scores = {}
        for level, indicators in complexity_indicators.items():
            score = sum(1 for indicator in indicators if indicator in description)
            level_scores[level] = score
        
        # Sélection du niveau avec le score le plus élevé
        if level_scores[ComplexityLevel.ARCHITECTURALE] > 0:
            return ComplexityLevel.ARCHITECTURALE
        elif level_scores[ComplexityLevel.CRITIQUE] > 0:
            return ComplexityLevel.CRITIQUE
        elif level_scores[ComplexityLevel.COMPLEXE] > 1:
            return ComplexityLevel.COMPLEXE
        elif level_scores[ComplexityLevel.MOYENNE] > 0:
            return ComplexityLevel.MOYENNE
        else:
            return ComplexityLevel.SIMPLE
    
    def _identify_systems(self, description: str) -> List[str]:
        """Identifie les systèmes concernés"""
        systems = []
        
        # Indicateurs Flutter
        flutter_indicators = ["flutter", "ui", "interface", "widget", "écran", "page", "design", "animation"]
        if any(indicator in description for indicator in flutter_indicators):
            systems.append("flutter")
        
        # Indicateurs Supabase
        supabase_indicators = ["supabase", "base de données", "table", "données", "sql", "schéma", "migration"]
        if any(indicator in description for indicator in supabase_indicators):
            systems.append("supabase")
        
        # Indicateurs d'intégration
        integration_indicators = ["api", "connexion", "appel", "réseau", "sync", "intégration", "endpoint"]
        if any(indicator in description for indicator in integration_indicators):
            systems.append("integration")
        
        # Indicateurs d'authentification
        auth_indicators = ["auth", "connexion", "inscription", "login", "sécurité", "permission"]
        if any(indicator in description for indicator in auth_indicators):
            systems.append("auth")
        
        return systems if systems else ["general"]
    
    def _identify_risk_factors(self, description: str) -> List[str]:
        """Identifie les facteurs de risque"""
        risks = []
        
        risk_indicators = {
            "suppression": ["supprimer", "suppression", "supprimé", "effacer", "remove"],
            "modification_critique": ["critique", "production", "majeur", "fondamental"],
            "securite": ["sécurité", "auth", "permission", "vulnérable", "exposé"],
            "performance": ["performance", "lent", "optimisation", "vitesse"],
            "donnees": ["données", "perte", "corruption", "migration"]
        }
        
        for risk, indicators in risk_indicators.items():
            if any(indicator in description for indicator in indicators):
                risks.append(risk)
        
        return risks
    
    def _evaluate_precision_requirement(self, description: str) -> float:
        """Évalue le niveau de précision requis (0-100)"""
        precision_indicators = {
            "eleve": ["précis", "exact", "parfait", "sans erreur", "rigoureux", "méticuleux"],
            "moyen": ["correct", "fonctionnel", "approprié", "bon"],
            "faible": ["approximatif", "simple", "basique", "rapidement"]
        }
        
        if any(indicator in description for indicator in precision_indicators["eleve"]):
            return 90.0
        elif any(indicator in description for indicator in precision_indicators["moyen"]):
            return 70.0
        else:
            return 50.0
    
    def _evaluate_time_sensitivity(self, description: str) -> str:
        """Évalue la sensibilité au temps"""
        urgent_indicators = ["urgent", "rapidement", "immédiatement", "aujourd'hui", "asap"]
        normal_indicators = ["bientôt", "cette semaine", "prochainement"]
        
        if any(indicator in description for indicator in urgent_indicators):
            return "elevee"
        elif any(indicator in description for indicator in normal_indicators):
            return "moyenne"
        else:
            return "faible"
    
    def _evaluate_integration_complexity(self, description: str) -> float:
        """Évalue la complexité d'intégration (0-100)"""
        complexity_score = 0.0
        
        # Systèmes multiples
        system_count = len(self._identify_systems(description))
        complexity_score += min(system_count * 20, 40)
        
        # Indicateurs d'intégration complexe
        complex_integration = ["microservices", "multi-api", "sync temps réel", "websocket", "streaming"]
        if any(indicator in description for indicator in complex_integration):
            complexity_score += 30
        
        return min(complexity_score, 100.0)
    
    def _evaluate_data_volume(self, description: str) -> str:
        """Évalue le volume de données"""
        high_volume = ["millions", "gros volume", "massif", "beaucoup", "énorme"]
        medium_volume = ["milliers", "plusieurs", "multiple", "beaucoup"]
        
        if any(indicator in description for indicator in high_volume):
            return "elevee"
        elif any(indicator in description for indicator in medium_volume):
            return "moyenne"
        else:
            return "faible"
    
    def _evaluate_security_impact(self, description: str) -> str:
        """Évalue l'impact sur la sécurité"""
        high_security = ["auth", "sécurité", "permission", "privé", "sensible", "personnel"]
        medium_security = ["accès", "utilisateur", "compte", "profil"]
        
        if any(indicator in description for indicator in high_security):
            return "elevee"
        elif any(indicator in description for indicator in medium_security):
            return "moyenne"
        else:
            return "faible"
    
    def _determine_performance_tier(self, complexity: ComplexityLevel, precision: float, security: str) -> PerformanceTier:
        """Détermine le tier de performance requis"""
        
        if complexity == ComplexityLevel.ARCHITECTURALE:
            return PerformanceTier.MASTER
        elif complexity == ComplexityLevel.CRITIQUE:
            return PerformanceTier.MASTER
        elif complexity == ComplexityLevel.COMPLEXE:
            return PerformanceTier.EXPERT if precision > 80 else PerformanceTier.AVANCE
        elif precision > 85 or security == "elevee":
            return PerformanceTier.EXPERT
        else:
            return PerformanceTier.STANDARD


class PerformanceMatcher:
    """Matcheur optimisé pour la performance"""
    
    def match_agents_to_performance(self, agents: Dict[str, AgentProfile], analysis: TaskAnalysis, required_tier: PerformanceTier) -> List[str]:
        """Sélectionne les agents les plus performants pour la tâche"""
        
        selected_agents = []
        systems = analysis.systems_involved
        
        # Mapping système -> agents par performance
        system_agents = {
            "flutter": ["flutter_ui_master", "flutter_ui_expert", "flutter_ui_novice"],
            "supabase": ["supabase_master", "supabase_expert", "supabase_standard"],
            "integration": ["integration_master", "integration_expert", "integration_standard"],
            "auth": ["supabase_master", "supabase_expert"],
            "general": ["flutter_ui_expert", "supabase_expert", "integration_expert"]
        }
        
        # Sélectionner le meilleur agent pour chaque système
        for system in systems:
            if system in system_agents:
                # Choisir l'agent le plus performant disponible
                for agent_name in system_agents[system]:
                    agent = agents.get(agent_name)
                    if agent and self._is_agent_suitable(agent, analysis, required_tier):
                        selected_agents.append(agent_name)
                        break
        
        return list(set(selected_agents))  # Éviter les doublons
    
    def _is_agent_suitable(self, agent: AgentProfile, analysis: TaskAnalysis, required_tier: PerformanceTier) -> bool:
        """Vérifie si l'agent est adapté à la tâche"""
        
        # Vérifier le tier de performance
        tier_priority = {
            PerformanceTier.MASTER: 4,
            PerformanceTier.EXPERT: 3,
            PerformanceTier.AVANCE: 2,
            PerformanceTier.STANDARD: 1
        }
        
        agent_priority = tier_priority.get(agent.tier, 0)
        required_priority = tier_priority.get(required_tier, 1)
        
        # L'agent doit avoir un tier égal ou supérieur à celui requis
        if agent_priority < required_priority:
            return False
        
        # Vérifier la complexité gérable
        if analysis.complexity_level not in agent.complexity_handling:
            return False
        
        # Vérifier la précision requise
        if agent.accuracy_rate < analysis.precision_required:
            return False
        
        return True


# Point d'entrée principal
def select_performance_optimized_agents(task_description: str) -> Tuple[List[str], Dict]:
    """
    Point d'entrée principal pour la sélection d'agents optimisés pour performance
    
    Args:
        task_description: Description de la tâche
        
    Returns:
        Tuple[List[str], Dict]: (agents sélectionnés, analyse détaillée)
    """
    selector = PerformanceAgentSelector()
    agents, analysis = selector.select_optimal_agents(task_description)
    
    # Formater l'analyse pour retour
    analysis_dict = {
        "complexity_level": analysis.complexity_level.value,
        "performance_required": analysis.performance_required.value,
        "systems_involved": analysis.systems_involved,
        "risk_factors": analysis.risk_factors,
        "precision_required": analysis.precision_required,
        "time_sensitivity": analysis.time_sensitivity,
        "integration_complexity": analysis.integration_complexity,
        "data_volume": analysis.data_volume,
        "security_impact": analysis.security_impact
    }
    
    return agents, analysis_dict


# Exemple d'utilisation
if __name__ == "__main__":
    # Test avec différentes complexités
    test_tasks = [
        "Ajouter un bouton simple sur la page d'accueil",
        "Créer une interface utilisateur complexe avec animations avancées et gestion d'état",
        "Refactoriser complètement l'architecture de l'application pour améliorer la scalabilité",
        "Optimiser les performances des requêtes Supabase pour gérer des millions d'utilisateurs"
    ]
    
    for task in test_tasks:
        agents, analysis = select_performance_optimized_agents(task)
        print(f"\nTâche: {task}")
        print(f"Complexité: {analysis['complexity_level']}")
        print(f"Performance requise: {analysis['performance_required']}")
        print(f"Agents sélectionnés: {agents}")
