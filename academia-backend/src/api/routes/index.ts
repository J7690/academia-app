import { Router } from 'express';
import authRoutes from './auth.routes.js';
import facebookRoutes from './facebook.routes.js';

/**
 * Aggrégateur de l'API REST (monté sous /api).
 * Les webhooks sont montés à part (hors /api) car appelés par des tiers.
 */
const router = Router();

router.get('/health', (_req, res) => {
  res.json({ status: 'ok', service: 'academia-backend', time: new Date().toISOString() });
});

router.use('/auth', authRoutes);
router.use('/facebook', facebookRoutes);

// Futurs connecteurs :
// router.use('/instagram', instagramRoutes);
// router.use('/whatsapp', whatsappRoutes);
// router.use('/calendar', calendarRoutes);
// router.use('/stripe', stripeRoutes);

export default router;
