import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from '../../config/env.js';
import type { Database } from '../../database/database.types.js';

/**
 * Client Supabase unique, initialisé avec la SERVICE ROLE KEY.
 *
 * ⚠️ La service role key contourne la RLS : ce client ne doit JAMAIS être
 * exposé côté navigateur. Il vit uniquement dans le backend, derrière la couche
 * d'authentification et la couche Service.
 */
let client: SupabaseClient<Database> | null = null;

export function getSupabase(): SupabaseClient<Database> {
  if (!client) {
    client = createClient<Database>(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
      auth: { autoRefreshToken: false, persistSession: false },
    });
  }
  return client;
}
