import type { PostgrestError } from '@supabase/supabase-js';
import { getSupabase } from '../modules/supabase/supabase.client.js';
import { AppError, NotFoundError } from '../utils/errors.js';
import { logger } from '../utils/logger.js';

/**
 * Couche Service générique d'accès aux données.
 *
 * RÈGLE D'ARCHITECTURE : aucun autre module ne doit importer directement le
 * client Supabase pour lire/écrire des tables métier. Toutes les opérations CRUD
 * passent par ce service (ou par un service métier qui l'utilise). Cela centralise
 * la gestion d'erreurs, le logging et facilite un futur changement de base.
 */

export interface ListOptions {
  /** Filtres d'égalité simples : { colonne: valeur }. */
  filters?: Record<string, string | number | boolean | null>;
  /** Colonnes à sélectionner (défaut '*'). */
  columns?: string;
  /** Tri : nom de colonne. */
  orderBy?: string;
  ascending?: boolean;
  limit?: number;
  offset?: number;
}

function fail(operation: string, table: string, error: PostgrestError): never {
  logger.error({ table, operation, error }, 'Erreur base de données');
  throw new AppError(
    `Erreur ${operation} sur "${table}": ${error.message}`,
    500,
    'DATABASE_ERROR',
    { pgCode: error.code, hint: error.hint },
  );
}

export class DatabaseService {
  private get db() {
    return getSupabase();
  }

  /** Liste des lignes avec filtres/pagination optionnels. */
  async list<T = Record<string, unknown>>(
    table: string,
    options: ListOptions = {},
  ): Promise<T[]> {
    const { filters = {}, columns = '*', orderBy, ascending = true, limit, offset } = options;

    let query = this.db.from(table).select(columns);
    for (const [key, value] of Object.entries(filters)) {
      query = query.eq(key, value as never);
    }
    if (orderBy) query = query.order(orderBy, { ascending });
    if (typeof limit === 'number') {
      const start = offset ?? 0;
      query = query.range(start, start + limit - 1);
    }

    const { data, error } = await query;
    if (error) fail('list', table, error);
    return (data ?? []) as T[];
  }

  /** Récupère une ligne par clé primaire (défaut colonne "id"). */
  async getById<T = Record<string, unknown>>(
    table: string,
    id: string | number,
    idColumn = 'id',
  ): Promise<T | null> {
    const { data, error } = await this.db
      .from(table)
      .select('*')
      .eq(idColumn, id)
      .maybeSingle();
    if (error) fail('getById', table, error);
    return (data as T) ?? null;
  }

  /** Comme getById mais lève NotFoundError si absent. */
  async getByIdOrFail<T = Record<string, unknown>>(
    table: string,
    id: string | number,
    idColumn = 'id',
  ): Promise<T> {
    const row = await this.getById<T>(table, id, idColumn);
    if (!row) throw new NotFoundError(`"${table}" #${id} introuvable`);
    return row;
  }

  /** Insertion d'une ou plusieurs lignes ; retourne les lignes créées. */
  async insert<T = Record<string, unknown>>(
    table: string,
    values: Record<string, unknown> | Record<string, unknown>[],
  ): Promise<T[]> {
    const { data, error } = await this.db
      .from(table)
      .insert(values as never)
      .select();
    if (error) fail('insert', table, error);
    return (data ?? []) as T[];
  }

  /** Mise à jour par clé primaire ; retourne la ligne mise à jour. */
  async update<T = Record<string, unknown>>(
    table: string,
    id: string | number,
    patch: Record<string, unknown>,
    idColumn = 'id',
  ): Promise<T> {
    const { data, error } = await this.db
      .from(table)
      .update(patch as never)
      .eq(idColumn, id)
      .select()
      .maybeSingle();
    if (error) fail('update', table, error);
    if (!data) throw new NotFoundError(`"${table}" #${id} introuvable`);
    return data as T;
  }

  /** Suppression par clé primaire. */
  async remove(table: string, id: string | number, idColumn = 'id'): Promise<void> {
    const { error } = await this.db.from(table).delete().eq(idColumn, id);
    if (error) fail('remove', table, error);
  }

  /** Appel d'une fonction RPC Postgres (procédures stockées). */
  async rpc<T = unknown>(fn: string, args: Record<string, unknown> = {}): Promise<T> {
    const { data, error } = await this.db.rpc(fn, args as never);
    if (error) {
      logger.error({ fn, error }, 'Erreur RPC');
      throw new AppError(`Erreur RPC "${fn}": ${error.message}`, 500, 'DATABASE_RPC_ERROR');
    }
    return data as T;
  }
}

/** Instance partagée (singleton léger). */
export const databaseService = new DatabaseService();
