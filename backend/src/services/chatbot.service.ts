import { GoogleGenerativeAI } from '@google/generative-ai';
import { prisma } from '../config/prisma';
import { env } from '../config/env';
import { ApiError } from '../utils/ApiError';
import { logger } from '../utils/logger';

const SYSTEM_PROMPT = `You are MyTransport AI Assistant, a helpful guide for public transportation in Malaysia.
You help users with:
- Planning routes using KL's transit network (KJ Line, Kajang Line, MRT Putrajaya, BRT Sunway, KTM Komuter, ERL/KLIA Express, Monorail)
- Finding the cheapest or fastest routes between destinations in Kuala Lumpur and Klang Valley
- Information about transit stations, fares, and operating hours
- Real-time service alerts and delays
- General travel advice within Malaysia

Always be friendly, concise, and specific. When giving route advice, mention line names, station codes, and approximate fares in Malaysian Ringgit (RM).
Operating hours are generally 06:00–24:00 for most rapid rail lines.
If you don't know something specific, say so honestly and suggest the user check the official Rapid KL or Prasarana website.`;

export const ChatbotService = {
  async sendMessage(userId: string, message: string, sessionId?: string) {
    // Resolve or create session
    let session = sessionId
      ? await prisma.chatSession.findFirst({ where: { id: sessionId, userId } })
      : null;

    if (!session) {
      session = await prisma.chatSession.create({
        data: {
          userId,
          title: message.slice(0, 60),
        },
      });
    }

    // Load history for context (last 10 messages)
    const history = await prisma.chatMessage.findMany({
      where: { sessionId: session.id },
      orderBy: { createdAt: 'asc' },
      take: 20,
    });

    // Save user message
    await prisma.chatMessage.create({
      data: { sessionId: session.id, role: 'USER', content: message },
    });

    let reply: string;

    if (!env.GEMINI_API_KEY) {
      // Fallback if no API key configured
      reply = getFallbackResponse(message);
    } else {
      try {
        const genAI = new GoogleGenerativeAI(env.GEMINI_API_KEY);
        const model = genAI.getGenerativeModel({ model: 'gemini-1.5-flash' });

        const chat = model.startChat({
          history: [
            { role: 'user', parts: [{ text: SYSTEM_PROMPT }] },
            { role: 'model', parts: [{ text: 'Understood! I am MyTransport AI Assistant, ready to help you navigate Malaysia\'s public transport system.' }] },
            ...history.map((m) => ({
              role: m.role === 'USER' ? ('user' as const) : ('model' as const),
              parts: [{ text: m.content }],
            })),
          ],
        });

        const result = await chat.sendMessage(message);
        reply = result.response.text();
      } catch (err) {
        logger.error('Gemini API error', { err });
        reply = getFallbackResponse(message);
      }
    }

    // Save assistant reply
    const assistantMessage = await prisma.chatMessage.create({
      data: { sessionId: session.id, role: 'ASSISTANT', content: reply },
    });

    return { sessionId: session.id, message: assistantMessage };
  },

  async getSessions(userId: string) {
    return prisma.chatSession.findMany({
      where: { userId },
      orderBy: { updatedAt: 'desc' },
      include: {
        _count: { select: { messages: true } },
        messages: { orderBy: { createdAt: 'desc' }, take: 1 },
      },
    });
  },

  async getSession(userId: string, sessionId: string) {
    const session = await prisma.chatSession.findFirst({
      where: { id: sessionId, userId },
      include: { messages: { orderBy: { createdAt: 'asc' } } },
    });
    if (!session) throw ApiError.notFound('Chat session');
    return session;
  },

  async deleteSession(userId: string, sessionId: string) {
    const session = await prisma.chatSession.findFirst({ where: { id: sessionId, userId } });
    if (!session) throw ApiError.notFound('Chat session');
    await prisma.chatSession.delete({ where: { id: sessionId } });
  },
};

function getFallbackResponse(message: string): string {
  const lower = message.toLowerCase();
  if (lower.includes('kl sentral')) {
    return 'KL Sentral (station code KJ15) is the main transit hub in Kuala Lumpur. It connects the KJ Line (LRT), KTM Komuter, ERL (KLIA Express/Transit), Monorail, and intercity trains. It is open from 06:00 to midnight daily.';
  }
  if (lower.includes('fare') || lower.includes('price') || lower.includes('cost')) {
    return 'Fares on the KJ and Kajang LRT lines range from RM1.20 to RM4.80 depending on distance. MRT fares are similar. The KLIA Express to KLIA costs RM55 (standard) and takes 28 minutes. Touch \'n Go cards offer a 10% discount on most rapid rail lines.';
  }
  if (lower.includes('mrt') || lower.includes('putrajaya')) {
    return 'The MRT Putrajaya Line (Laluan Putrajaya) runs from Kwasa Damansara (PY01) to Putrajaya Sentral (PY43), covering 57.7 km with 40 stations. It connects to the KJ Line at Muzium Negara and Pasar Seni stations.';
  }
  return 'I am MyTransport AI, your guide to KL\'s public transport! I can help you plan routes, find station information, check fares, and get transit alerts. What would you like to know?';
}
