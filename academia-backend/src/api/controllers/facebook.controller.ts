import type { Request, Response } from 'express';
import { facebookService } from '../../modules/facebook/index.js';

/**
 * Contrôleurs REST Facebook. Fins et sans logique métier : ils délèguent au
 * FacebookService et formatent la réponse HTTP. La validation est faite en
 * amont par le middleware `validate` (schémas Zod partagés).
 */
export const facebookController = {
  async publishPost(req: Request, res: Response): Promise<void> {
    const result = await facebookService.publishPost(req.body);
    res.status(201).json({ data: result });
  },

  async deletePost(req: Request, res: Response): Promise<void> {
    const result = await facebookService.deletePost(req.params.postId as string);
    res.json({ data: result });
  },

  async listPosts(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit ?? 25);
    const data = await facebookService.listPosts(limit);
    res.json({ data });
  },

  async publishPhoto(req: Request, res: Response): Promise<void> {
    const result = await facebookService.publishPhoto(req.body);
    res.status(201).json({ data: result });
  },

  async publishVideo(req: Request, res: Response): Promise<void> {
    const result = await facebookService.publishVideo(req.body);
    res.status(201).json({ data: result });
  },

  async getComments(req: Request, res: Response): Promise<void> {
    const objectId = String(req.query.objectId);
    const limit = Number(req.query.limit ?? 50);
    const data = await facebookService.getComments(objectId, limit);
    res.json({ data });
  },

  async replyComment(req: Request, res: Response): Promise<void> {
    const result = await facebookService.replyToComment(req.body);
    res.status(201).json({ data: result });
  },

  async listConversations(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit ?? 25);
    const data = await facebookService.listConversations(limit);
    res.json({ data });
  },

  async getMessages(req: Request, res: Response): Promise<void> {
    const conversationId = String(req.query.conversationId);
    const limit = Number(req.query.limit ?? 50);
    const data = await facebookService.getConversationMessages(conversationId, limit);
    res.json({ data });
  },

  async sendMessage(req: Request, res: Response): Promise<void> {
    const result = await facebookService.sendMessage(req.body);
    res.status(201).json({ data: result });
  },

  async getInsights(req: Request, res: Response): Promise<void> {
    const data = await facebookService.getPageInsights(req.body);
    res.json({ data });
  },

  async getEvents(req: Request, res: Response): Promise<void> {
    const limit = Number(req.query.limit ?? 25);
    const data = await facebookService.getPageEvents(limit);
    res.json({ data });
  },
};
