import { z } from 'zod';
import { facebookService } from '../../modules/facebook/index.js';
import {
  commentTargetSchema,
  conversationMessagesSchema,
  insightsSchema,
  listPostsSchema,
  postIdSchema,
  publishPhotoSchema,
  publishPostSchema,
  publishVideoSchema,
  replyCommentSchema,
  sendMessageSchema,
} from '../../modules/facebook/facebook.schemas.js';

/**
 * Définitions des outils MCP Facebook.
 *
 * RÈGLE : aucun outil ne contient de logique métier. Chacun valide ses entrées
 * (schéma Zod partagé avec l'API REST) puis délègue au FacebookService.
 *
 * Chaque définition expose la forme Zod « brute » (`.shape`) attendue par
 * `server.registerTool` du SDK MCP officiel, ainsi qu'un handler renvoyant du
 * texte JSON.
 */

type ToolResult = { content: Array<{ type: 'text'; text: string }>; isError?: boolean };

function ok(data: unknown): ToolResult {
  return { content: [{ type: 'text', text: JSON.stringify(data, null, 2) }] };
}

export interface McpToolDefinition {
  name: string;
  config: {
    title: string;
    description: string;
    inputSchema: z.ZodRawShape;
  };
  handler: (args: unknown) => Promise<ToolResult>;
}

export const facebookTools: McpToolDefinition[] = [
  {
    name: 'facebook_publish_post',
    config: {
      title: 'Publier une publication Facebook',
      description: 'Publie une publication texte (avec lien optionnel) sur la Page Facebook.',
      inputSchema: publishPostSchema.shape,
    },
    handler: async (args) => ok(await facebookService.publishPost(publishPostSchema.parse(args))),
  },
  {
    name: 'facebook_delete_post',
    config: {
      title: 'Supprimer une publication',
      description: 'Supprime une publication de la Page à partir de son identifiant.',
      inputSchema: postIdSchema.shape,
    },
    handler: async (args) => ok(await facebookService.deletePost(postIdSchema.parse(args).postId)),
  },
  {
    name: 'facebook_list_posts',
    config: {
      title: 'Lister les publications',
      description: 'Liste les dernières publications de la Page Facebook.',
      inputSchema: listPostsSchema.shape,
    },
    handler: async (args) => ok(await facebookService.listPosts(listPostsSchema.parse(args).limit)),
  },
  {
    name: 'facebook_get_comments',
    config: {
      title: 'Lire les commentaires',
      description: "Lit les commentaires d'une publication (ou les réponses d'un commentaire).",
      inputSchema: commentTargetSchema.shape,
    },
    handler: async (args) => {
      const { objectId, limit } = commentTargetSchema.parse(args);
      return ok(await facebookService.getComments(objectId, limit));
    },
  },
  {
    name: 'facebook_reply_comment',
    config: {
      title: 'Répondre à un commentaire',
      description: 'Publie une réponse à un commentaire donné.',
      inputSchema: replyCommentSchema.shape,
    },
    handler: async (args) =>
      ok(await facebookService.replyToComment(replyCommentSchema.parse(args))),
  },
  {
    name: 'facebook_get_messages',
    config: {
      title: 'Lire les messages Messenger',
      description: "Lit l'historique des messages d'une conversation Messenger.",
      inputSchema: conversationMessagesSchema.shape,
    },
    handler: async (args) => {
      const { conversationId, limit } = conversationMessagesSchema.parse(args);
      return ok(await facebookService.getConversationMessages(conversationId, limit));
    },
  },
  {
    name: 'facebook_send_message',
    config: {
      title: 'Envoyer un message Messenger',
      description: "Envoie un message Messenger à un utilisateur (PSID) ayant écrit à la Page.",
      inputSchema: sendMessageSchema.shape,
    },
    handler: async (args) => ok(await facebookService.sendMessage(sendMessageSchema.parse(args))),
  },
  {
    name: 'facebook_get_page_insights',
    config: {
      title: 'Statistiques de la Page',
      description: 'Récupère les statistiques (insights) de la Page pour une période donnée.',
      inputSchema: insightsSchema.shape,
    },
    handler: async (args) => ok(await facebookService.getPageInsights(insightsSchema.parse(args))),
  },
  {
    name: 'facebook_publish_photo',
    config: {
      title: 'Publier une image',
      description: "Publie une image sur la Page à partir d'une URL, avec légende optionnelle.",
      inputSchema: publishPhotoSchema.shape,
    },
    handler: async (args) =>
      ok(await facebookService.publishPhoto(publishPhotoSchema.parse(args))),
  },
  {
    name: 'facebook_publish_video',
    config: {
      title: 'Publier une vidéo',
      description: "Publie une vidéo sur la Page à partir d'une URL, avec titre/description.",
      inputSchema: publishVideoSchema.shape,
    },
    handler: async (args) =>
      ok(await facebookService.publishVideo(publishVideoSchema.parse(args))),
  },
];
