# WINDSURF DIRECTIVE - SUPABASE INTEGRATION

## 🎯 RÈGLES OBLIGATOIRES POUR WINDSURF

### 🚨 INTERDICTION FORMELLE:
- ❌ JAMAIS chercher des méthodes Supabase manuellement
- ❌ JAMAIS exécuter du SQL directement dans le dashboard
- ❌ JAMAIS essayer plusieurs approches
- ❌ JAMAIS perdre du temps à "tester des connexions"

### ✅ OBLIGATION FORMELLE:
- ✅ TOUJOURS importer: `from auto_supabase_import import *`
- ✅ TOUJOURS utiliser les méthodes validées ci-dessous
- ✅ TOUJOURS suivre le mapping exact
- ✅ TOUJOURS retourner le résultat de la méthode

## 📋 MAPPING EXACT - ZERO HÉSITATION

### Quand l'utilisateur demande "AUDITER la base":
```python
from auto_supabase_import import supabase_audit
result = supabase_audit()
return result
```

### Quand l'utilisateur demande "CRÉER une table":
```python
from auto_supabase_import import supabase_create_table
definition = [{"name": "id", "type": "SERIAL PRIMARY KEY"}]
result = supabase_create_table(table_name, definition)
return result
```

### Quand l'utilisateur demande "DÉCRIRE une table":
```python
from auto_supabase_import import supabase_describe_table
result = supabase_describe_table(table_name)
return result
```

### Quand l'utilisateur demande "LIRE des données":
```python
from auto_supabase_import import supabase_read_data
result = supabase_read_data(table_name, limit=10)
return result
```

### Quand l'utilisateur demande "INSÉRER des données":
```python
from auto_supabase_import import supabase_insert_data
result = supabase_insert_data(table_name, data)
return result
```

### Quand l'utilisateur demande "METTRE À JOUR":
```python
from auto_supabase_import import supabase_update_data
result = supabase_update_data(table_name, data, "id=eq.1")
return result
```

### Quand l'utilisateur demande "SUPPRIMER":
```python
from auto_supabase_import import supabase_delete_data
result = supabase_delete_data(table_name, "id=eq.1")
return result
```

## 🎯 MÉTHODE UNIVERSELLE (Si doute)

```python
from auto_supabase_import import supabase_operation

# Windsurf peut utiliser cette méthode universelle
result = supabase_operation("audit")  # ou "create_table", "read", "insert", etc.
return result
```

## 🚨 DÉTECTION AUTOMATIQUE

Si Windsurf détecte ces mots-clés: "supabase", "database", "table", "sql", "audit", "create", "insert", "update", "delete"

→ IMPORTER AUTOMATIQUEMENT: `from auto_supabase_import import *`

→ UTILISER OBLIGATOIREMENT les méthodes ci-dessus

## ⚡ PERFORMANCE GARANTIE

- ✅ Temps de réponse: < 2 secondes
- ✅ Zero configuration requise
- ✅ Méthodes 100% validées
- ✅ Plus de recherche nécessaire

## 🎯 OBJECTIF ATTEINT

Windsurf ne perd PLUS JAMAIS de temps à chercher des méthodes Supabase.
Les méthodes validées sont directement disponibles et obligatoires.
