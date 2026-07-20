import { z } from 'zod';

/**
 * Schémas d'entrée Zod PARTAGÉS entre l'API REST et les outils MCP.
 * Ils constituent le contrat unique du module Facebook : une seule source de
 * vérité pour la validation, réutilisée partout.
 */

export const publishPostSchema = z.object({
  message: z.string().min(1, 'Le message ne peut pas être vide'),
  link: z.string().url().optional(),
  published: z.boolean().optional(),
});

export const publishPhotoSchema = z.object({
  imageUrl: z.string().url('imageUrl doit être une URL valide'),
  caption: z.string().optional(),
});

export const publishVideoSchema = z.object({
  videoUrl: z.string().url('videoUrl doit être une URL valide'),
  title: z.string().optional(),
  description: z.string().optional(),
});

export const postIdSchema = z.object({
  postId: z.string().min(1),
});

export const listPostsSchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(25),
});

export const commentTargetSchema = z.object({
  objectId: z.string().min(1, 'objectId (post ou commentaire) requis'),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export const replyCommentSchema = z.object({
  commentId: z.string().min(1),
  message: z.string().min(1),
});

export const listConversationsSchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(25),
});

export const conversationMessagesSchema = z.object({
  conversationId: z.string().min(1),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export const sendMessageSchema = z.object({
  recipientId: z.string().min(1, 'PSID du destinataire requis'),
  message: z.string().min(1),
});

export const insightsSchema = z.object({
  metrics: z.array(z.string().min(1)).min(1).default(['page_impressions', 'page_engaged_users']),
  period: z.enum(['day', 'week', 'days_28']).default('week'),
});

export type PublishPostInput = z.infer<typeof publishPostSchema>;
export type PublishPhotoInput = z.infer<typeof publishPhotoSchema>;
export type PublishVideoInput = z.infer<typeof publishVideoSchema>;
export type ReplyCommentInput = z.infer<typeof replyCommentSchema>;
export type SendMessageInput = z.infer<typeof sendMessageSchema>;
export type InsightsInput = z.infer<typeof insightsSchema>;
