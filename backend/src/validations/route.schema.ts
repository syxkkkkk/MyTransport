import { z } from 'zod';

export const planRouteSchema = z.object({
  body: z.object({
    fromLat: z.number().min(-90).max(90),
    fromLon: z.number().min(-180).max(180),
    fromName: z.string().min(1),
    toLat: z.number().min(-90).max(90),
    toLon: z.number().min(-180).max(180),
    toName: z.string().min(1),
  }),
});

export const saveLocationSchema = z.object({
  body: z.object({
    label: z.string().min(1).max(50),
    name: z.string().min(1),
    address: z.string().min(1),
    latitude: z.number(),
    longitude: z.number(),
    icon: z.string().optional(),
  }),
});

export type PlanRouteBody = z.infer<typeof planRouteSchema>['body'];
export type SaveLocationBody = z.infer<typeof saveLocationSchema>['body'];
