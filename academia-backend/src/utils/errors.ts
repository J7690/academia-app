/**
 * Hiérarchie d'erreurs applicative. Toutes les erreurs "attendues" héritent de
 * AppError et portent un statut HTTP + un code machine, ce qui permet au
 * middleware d'erreurs de répondre de façon cohérente.
 */
export class AppError extends Error {
  public readonly statusCode: number;
  public readonly code: string;
  public readonly isOperational: boolean;
  public readonly details?: unknown;

  constructor(
    message: string,
    statusCode = 500,
    code = 'INTERNAL_ERROR',
    details?: unknown,
  ) {
    super(message);
    this.name = new.target.name;
    this.statusCode = statusCode;
    this.code = code;
    this.isOperational = true;
    this.details = details;
    Error.captureStackTrace?.(this, new.target);
  }
}

export class BadRequestError extends AppError {
  constructor(message = 'Requête invalide', details?: unknown) {
    super(message, 400, 'BAD_REQUEST', details);
  }
}

export class UnauthorizedError extends AppError {
  constructor(message = 'Non authentifié') {
    super(message, 401, 'UNAUTHORIZED');
  }
}

export class ForbiddenError extends AppError {
  constructor(message = 'Accès refusé') {
    super(message, 403, 'FORBIDDEN');
  }
}

export class NotFoundError extends AppError {
  constructor(message = 'Ressource introuvable') {
    super(message, 404, 'NOT_FOUND');
  }
}

/** Erreur renvoyée par un connecteur externe (Meta, Stripe, Google...). */
export class ExternalServiceError extends AppError {
  constructor(service: string, message: string, details?: unknown) {
    super(`[${service}] ${message}`, 502, 'EXTERNAL_SERVICE_ERROR', details);
  }
}
