import { McpServer } from '@modelcontextprotocol/sdk/server/mcp.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { allTools } from './tools/index.js';
import { logger } from '../utils/logger.js';
import { AppError } from '../utils/errors.js';

/**
 * Serveur MCP Academia — compatible Claude Desktop (transport STDIO).
 *
 * Il fait partie intégrante du backend : il réutilise exactement les mêmes
 * Services que l'API REST. Aucune logique métier ici ; on se contente
 * d'enregistrer les outils du registre et de router les erreurs proprement.
 */
export function buildMcpServer(): McpServer {
  const server = new McpServer({
    name: 'academia-backend',
    version: '0.1.0',
  });

  for (const tool of allTools) {
    server.registerTool(tool.name, tool.config, async (args: unknown) => {
      try {
        return await tool.handler(args);
      } catch (err) {
        const message =
          err instanceof AppError ? err.message : err instanceof Error ? err.message : String(err);
        logger.error({ tool: tool.name, err }, 'Erreur outil MCP');
        return {
          content: [{ type: 'text' as const, text: `Erreur: ${message}` }],
          isError: true,
        };
      }
    });
  }

  logger.info(`MCP: ${allTools.length} outil(s) enregistré(s)`);
  return server;
}

async function main(): Promise<void> {
  const server = buildMcpServer();
  const transport = new StdioServerTransport();
  await server.connect(transport);
  logger.info('Serveur MCP Academia connecté (STDIO)');
}

// Démarrage si exécuté directement (et non importé).
main().catch((err) => {
  logger.error({ err }, 'Échec démarrage serveur MCP');
  process.exit(1);
});
