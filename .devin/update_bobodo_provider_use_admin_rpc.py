#!/usr/bin/env python3
"""
Mettre à jour BobodoProvider pour utiliser la RPC app_get_or_create_bobodo_session_admin
avec le student_id passé en paramètre, pour garantir la réutilisation de session côté serveur.
"""

import os
import re

# Lire le fichier actuel
provider_path = os.path.join(os.path.dirname(__file__), "..", "academia_app", "lib", "providers", "bobodo_provider.dart")

with open(provider_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remplacer l'appel RPC pour utiliser la version admin avec student_id
# On va récupérer le student_id depuis Supabase auth.currentSession?.user?.id

new_create_session = '''
Future<void> createSession({String? title}) async {
    _setLoading(true);
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final result = await _client
          .rpc('app_get_or_create_bobodo_session_admin', params: {
            'p_student_id': user.id,
            'p_title': title,
          });
      final sessionId = result?.toString();
      _currentSessionId = sessionId;
      _messages.clear();
      notifyListeners();

      // Persister la session Bobodo pour la réutiliser lors des prochains
      // lancements de l'application.
      if (sessionId != null && sessionId.isNotEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_sessionPrefKey, sessionId);
        } catch (_) {
          // On ignore les erreurs de persistance pour ne pas bloquer l'UX.
        }
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }'''

# Remplacer la fonction createSession
pattern = r'Future<void> createSession\(\{String\? title\}\) async \{[^}]*\}'
content = re.sub(pattern, new_create_session.strip(), content, flags=re.DOTALL)

# Écrire le fichier mis à jour
with open(provider_path, "w", encoding="utf-8") as f:
    f.write(content)

print("BobodoProvider mis à jour pour utiliser app_get_or_create_bobodo_session_admin")
