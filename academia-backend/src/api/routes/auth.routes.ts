import { Router } from 'express';
import { authController } from '../controllers/auth.controller.js';

const router = Router();

router.post('/refresh', authController.refresh);
router.post('/dev-token', authController.issueDevToken); // désactivé en production

export default router;
