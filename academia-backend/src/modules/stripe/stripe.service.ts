import { env } from '../../config/env.js';
import { AppError, ExternalServiceError } from '../../utils/errors.js';

/**
 * Module Stripe. Architecture préparée — paiements, abonnements, factures.
 * Brancher le SDK `stripe` (à ajouter aux dépendances) lors de l'implémentation.
 */
export class StripeService {
  protected requireConfig(): void {
    if (!env.STRIPE_SECRET_KEY) {
      throw new AppError('Configuration Stripe incomplète (STRIPE_SECRET_KEY)', 500, 'STRIPE_NOT_CONFIGURED');
    }
  }

  /** Créer un paiement / une intention de paiement. */
  async createPayment(_input: { amount: number; currency: string; customer?: string }): Promise<unknown> {
    this.requireConfig();
    throw new ExternalServiceError('Stripe', 'createPayment() non encore implémenté');
  }

  /** Créer / gérer un abonnement. */
  async createSubscription(_input: { customer: string; priceId: string }): Promise<unknown> {
    throw new ExternalServiceError('Stripe', 'createSubscription() non encore implémenté');
  }

  /** Créer une facture. */
  async createInvoice(_input: { customer: string; items: Array<{ price: string; quantity: number }> }): Promise<unknown> {
    throw new ExternalServiceError('Stripe', 'createInvoice() non encore implémenté');
  }
}

export const stripeService = new StripeService();
