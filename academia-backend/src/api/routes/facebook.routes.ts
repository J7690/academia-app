import { Router } from 'express';
import { facebookController } from '../controllers/facebook.controller.js';
import { authenticate, authorize } from '../middlewares/auth.middleware.js';
import { validate } from '../middlewares/validate.middleware.js';
import { asyncHandler } from '../../utils/asyncHandler.js';
import {
  commentTargetSchema,
  conversationMessagesSchema,
  insightsSchema,
  listConversationsSchema,
  listPostsSchema,
  postIdSchema,
  publishPhotoSchema,
  publishPostSchema,
  publishVideoSchema,
  replyCommentSchema,
  sendMessageSchema,
} from '../../modules/facebook/facebook.schemas.js';

/**
 * Routes REST Facebook.
 * Toutes protégées par JWT. Les écritures (publication, réponses, envoi) sont
 * réservées aux rôles admin/gestionnaire ; la lecture est ouverte à tout
 * utilisateur authentifié.
 */
const router = Router();

const writers = authorize('admin', 'gestionnaire');

router.post(
  '/post',
  authenticate,
  writers,
  validate({ body: publishPostSchema }),
  asyncHandler(facebookController.publishPost),
);

router.get(
  '/posts',
  authenticate,
  validate({ query: listPostsSchema }),
  asyncHandler(facebookController.listPosts),
);

router.delete(
  '/post/:postId',
  authenticate,
  writers,
  validate({ params: postIdSchema }),
  asyncHandler(facebookController.deletePost),
);

router.post(
  '/photo',
  authenticate,
  writers,
  validate({ body: publishPhotoSchema }),
  asyncHandler(facebookController.publishPhoto),
);

router.post(
  '/video',
  authenticate,
  writers,
  validate({ body: publishVideoSchema }),
  asyncHandler(facebookController.publishVideo),
);

router.get(
  '/comments',
  authenticate,
  validate({ query: commentTargetSchema }),
  asyncHandler(facebookController.getComments),
);

router.post(
  '/comment/reply',
  authenticate,
  writers,
  validate({ body: replyCommentSchema }),
  asyncHandler(facebookController.replyComment),
);

router.get(
  '/conversations',
  authenticate,
  validate({ query: listConversationsSchema }),
  asyncHandler(facebookController.listConversations),
);

router.get(
  '/messages',
  authenticate,
  validate({ query: conversationMessagesSchema }),
  asyncHandler(facebookController.getMessages),
);

router.post(
  '/message/send',
  authenticate,
  writers,
  validate({ body: sendMessageSchema }),
  asyncHandler(facebookController.sendMessage),
);

router.post(
  '/insights',
  authenticate,
  validate({ body: insightsSchema }),
  asyncHandler(facebookController.getInsights),
);

router.get('/events', authenticate, asyncHandler(facebookController.getEvents));

export default router;
