import { Router } from 'express';
import { webhookController } from '../controllers/webhook.controller.js';

/** Routes webhooks (publiques — Meta appelle sans JWT). */
const router = Router();

router.get('/', webhookController.verify);
router.post('/', webhookController.receive);

export default router;
