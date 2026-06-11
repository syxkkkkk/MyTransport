import { Router } from 'express';
import { ChatbotController } from '../controllers/chatbot.controller';
import { authenticate } from '../middleware/authenticate';
import { validate } from '../middleware/validate';
import { sendMessageSchema } from '../validations/chat.schema';

const router = Router();

// All chatbot routes require authentication
router.use(authenticate);

router.post('/message', validate(sendMessageSchema), ChatbotController.sendMessage);
router.get('/sessions', ChatbotController.getSessions);
router.get('/sessions/:sessionId', ChatbotController.getSession);
router.delete('/sessions/:sessionId', ChatbotController.deleteSession);

export default router;
