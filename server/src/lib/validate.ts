import type { z } from 'zod';

import { badRequest } from './errors.js';

export function parse<T extends z.ZodTypeAny>(schema: T, data: unknown): z.infer<T> {
  const r = schema.safeParse(data);
  if (!r.success) {
    const first = r.error.issues[0];
    throw badRequest('invalid_request', first ? `${first.path.join('.') || 'body'}: ${first.message}` : 'invalid');
  }
  return r.data;
}
