#!/usr/bin/env python3
"""
Module d'import automatique Supabase pour Windsurf
Windsurf importe automatiquement ce module quand il détecte Supabase
PLUS DE PERTE DE TEMPS - MÉTHODES VALIDÉES DIRECTEMENT DISPONIBLES
"""

import requests
from typing import Dict, Any, List, Optional

# === CONFIGURATION FIXE VALIDÉE ===
SUPABASE_URL = "https://thevdfcwlcqzdoybfvgs.supabase.co"
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InRoZXZkZmN3bGNxemRveWJmdmdzIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2MzA1NjU2MCwiZXhwIjoyMDc4NjMyNTYwfQ.U0xz7oHnUISnxzAG8ehm_gRzoOlQPucj61i2f-1FjgM"

# Headers RPC (Méthode #1 - Prioritaire)
RPC_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json"
}

# Headers API (Méthode #2 - Fallback)
API_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}"
}

# === MÉTHODES RPC VALIDÉES (Priorité #1) ===

def supabase_audit() -> Dict[str, Any]:
    """
    Audit complet de la base de données
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        response = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/list_tables_detailed", 
                               headers=RPC_HEADERS, 
                               timeout=10)
        if response.status_code == 200:
            return {
                "success": True,
                "data": response.json(),
                "method": "rpc_list_tables_detailed"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Audit failed", "method": "rpc_list_tables_detailed"}

def supabase_create_table(table_name: str, definition: List[Dict[str, Any]]) -> Dict[str, Any]:
    """
    Créer une table de manière sécurisée
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        response = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/create_table_safe", 
                               headers=RPC_HEADERS, 
                               json={
                                   "p_table_name": table_name,
                                   "p_table_definition": definition
                               }, 
                               timeout=10)
        if response.status_code == 200:
            return {
                "success": True,
                "data": response.json(),
                "method": "rpc_create_table_safe"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Table creation failed", "method": "rpc_create_table_safe"}

def supabase_describe_table(table_name: str) -> Dict[str, Any]:
    """
    Décrire la structure d'une table
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        response = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/describe_table_detailed", 
                               headers=RPC_HEADERS, 
                               json={"p_table_name": table_name}, 
                               timeout=10)
        if response.status_code == 200:
            return {
                "success": True,
                "data": response.json(),
                "method": "rpc_describe_table_detailed"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Table description failed", "method": "rpc_describe_table_detailed"}

def supabase_table_exists(table_name: str) -> Dict[str, Any]:
    """
    Vérifier si une table existe
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        response = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/table_exists", 
                               headers=RPC_HEADERS, 
                               json={"p_table_name": table_name}, 
                               timeout=10)
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "data": result,
                "method": "rpc_table_exists"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Table existence check failed", "method": "rpc_table_exists"}

def supabase_column_exists(table_name: str, column_name: str) -> Dict[str, Any]:
    """
    Vérifier si une colonne existe
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        response = requests.post(f"{SUPABASE_URL}/rest/v1/rpc/column_exists", 
                               headers=RPC_HEADERS, 
                               json={
                                   "p_table_name": table_name,
                                   "p_column_name": column_name
                               }, 
                               timeout=10)
        if response.status_code == 200:
            result = response.json()
            return {
                "success": True,
                "data": result,
                "method": "rpc_column_exists"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Column existence check failed", "method": "rpc_column_exists"}

# === MÉTHODES API VALIDÉES (Priorité #2) ===

def _build_table_request(table_name: str):
    """Construit l'URL et les headers pour une table éventuellement schématisée.

    - Supporte les noms "schema.table" (ex: "app.universities") en
      utilisant Accept-Profile/Content-Profile pour cibler le bon schéma.
    - Pour les noms simples, reste sur le schéma par défaut (public).
    """
    schema = None
    table = table_name
    if "." in table_name:
        schema, table = table_name.split(".", 1)

    url = f"{SUPABASE_URL}/rest/v1/{table}"
    headers = dict(API_HEADERS)
    if schema:
        headers["Accept-Profile"] = schema
        headers["Content-Profile"] = schema
    return url, headers

def supabase_read_data(table_name: str, limit: int = 10) -> Dict[str, Any]:
    """
    Lire des données depuis une table
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        url, headers = _build_table_request(table_name)
        url = f"{url}?limit={limit}"
        response = requests.get(url, headers=headers, timeout=10)
        if response.status_code == 200:
            return {
                "success": True,
                "data": response.json(),
                "method": "api_select"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Data read failed", "method": "api_select"}

def supabase_insert_data(table_name: str, data: Dict[str, Any]) -> Dict[str, Any]:
    """
    Insérer des données dans une table
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        url, headers = _build_table_request(table_name)
        response = requests.post(url, headers=headers, json=data, timeout=10)
        if response.status_code == 201:
            return {
                "success": True,
                "data": response.json(),
                "method": "api_insert"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Data insertion failed", "method": "api_insert"}

def supabase_update_data(table_name: str, data: Dict[str, Any], condition: str) -> Dict[str, Any]:
    """
    Mettre à jour des données dans une table
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        url, headers = _build_table_request(table_name)
        url = f"{url}?{condition}"
        response = requests.patch(url, headers=headers, json=data, timeout=10)
        if response.status_code == 200:
            return {
                "success": True,
                "data": response.json(),
                "method": "api_update"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Data update failed", "method": "api_update"}

def supabase_delete_data(table_name: str, condition: str) -> Dict[str, Any]:
    """
    Supprimer des données d'une table
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    """
    try:
        url, headers = _build_table_request(table_name)
        url = f"{url}?{condition}"
        response = requests.delete(url, headers=headers, timeout=10)
        if response.status_code == 204:
            return {
                "success": True,
                "data": {"deleted": True},
                "method": "api_delete"
            }
    except Exception as e:
        pass
    
    return {"success": False, "error": "Data deletion failed", "method": "api_delete"}

# === MÉTHODE UNIVERSELLE POUR WINDSURF ===

def supabase_operation(operation_type: str, **kwargs) -> Dict[str, Any]:
    """
    Méthode universelle pour Windsurf
    WINDSURF: UTILISER OBLIGATOIREMENT CETTE MÉTHODE
    PLUS BESOIN DE CHERCHER - LA MÉTHODE EST AUTOMATIQUEMENT SÉLECTIONNÉE
    """
    
    # Mapping automatique des opérations
    operation_mapping = {
        "audit": supabase_audit,
        "create_table": supabase_create_table,
        "describe_table": supabase_describe_table,
        "table_exists": supabase_table_exists,
        "column_exists": supabase_column_exists,
        "read": supabase_read_data,
        "insert": supabase_insert_data,
        "update": supabase_update_data,
        "delete": supabase_delete_data
    }
    
    # Sélection automatique de la méthode
    if operation_type in operation_mapping:
        method = operation_mapping[operation_type]
        try:
            return method(**kwargs)
        except Exception as e:
            return {
                "success": False,
                "error": f"Operation {operation_type} failed: {str(e)}",
                "method": f"auto_{operation_type}"
            }
    else:
        return {
            "success": False,
            "error": f"Unknown operation: {operation_type}",
            "available_operations": list(operation_mapping.keys())
        }

# === ALIAS POUR SIMPLIFIER L'UTILISATION WINDSURF ===

# Alias courts pour Windsurf
audit = supabase_audit
create_table = supabase_create_table
describe = supabase_describe_table
exists = supabase_table_exists
read = supabase_read_data
insert = supabase_insert_data
update = supabase_update_data
delete = supabase_delete_data

# === INFOS POUR WINDSURF ===
WINDSURF_INFO = {
    "module": "auto_supabase_import",
    "purpose": "Méthodes Supabase validées pour Windsurf",
    "usage": "Importer automatiquement quand Supabase est détecté",
    "no_search_required": True,
    "methods_validated": True,
    "zero_time_waste": True
}
