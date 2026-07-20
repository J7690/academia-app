/**
 * Types de la base Supabase.
 *
 * Ce fichier est un PLACEHOLDER. Générez la version réelle et fortement typée
 * depuis votre schéma avec :
 *
 *   SUPABASE_PROJECT_ID=<votre-ref> npm run generate:types
 *
 * (nécessite la CLI Supabase installée et une session `supabase login`).
 * Tant que ce n'est pas fait, `Database` reste volontairement permissif afin de
 * ne pas bloquer le développement.
 */
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export interface Database {
  public: {
    Tables: Record<
      string,
      {
        Row: Record<string, unknown>;
        Insert: Record<string, unknown>;
        Update: Record<string, unknown>;
        Relationships: unknown[];
      }
    >;
    Views: Record<string, { Row: Record<string, unknown> }>;
    Functions: Record<string, unknown>;
    Enums: Record<string, unknown>;
    CompositeTypes: Record<string, unknown>;
  };
}
