import { databaseService } from '../database/database.service.js';
import { facebookService } from '../modules/facebook/index.js';
import { instagramService } from '../modules/instagram/instagram.service.js';
import { messengerService } from '../modules/messenger/messenger.service.js';
import { whatsappService } from '../modules/whatsapp/whatsapp.service.js';
import { gmailService } from '../modules/gmail/gmail.service.js';
import { calendarService } from '../modules/calendar/calendar.service.js';
import { stripeService } from '../modules/stripe/stripe.service.js';

/**
 * Registre central des Services (point unique d'injection de dépendances).
 *
 * Contrôleurs REST et outils MCP résolvent leurs dépendances ici plutôt que
 * d'importer chaque module directement, ce qui facilite le remplacement (mocks
 * en test) et garde une vue d'ensemble des connecteurs disponibles.
 */
export const services = {
  database: databaseService,
  facebook: facebookService,
  instagram: instagramService,
  messenger: messengerService,
  whatsapp: whatsappService,
  gmail: gmailService,
  calendar: calendarService,
  stripe: stripeService,
} as const;

export type Services = typeof services;
