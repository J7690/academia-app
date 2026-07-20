import { facebookTools, type McpToolDefinition } from './facebook.tools.js';

/**
 * Registre central des outils MCP. Pour ajouter un connecteur (Instagram,
 * WhatsApp, Stripe...), créez `<connector>.tools.ts` puis étalez-le ici.
 */
export const allTools: McpToolDefinition[] = [
  ...facebookTools,
  // ...instagramTools,
  // ...whatsappTools,
  // ...stripeTools,
];

export type { McpToolDefinition };
