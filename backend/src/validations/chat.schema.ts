import { z } from 'zod';

export const sendMessageSchema = z.object({
  body: z.object({
    sessionId: z.string().optional(),
    message: z.string().min(1).max(2000),
  }),
});

export type SendMessageBody = z.infer<typeof sendMessageSchema>['body'];
