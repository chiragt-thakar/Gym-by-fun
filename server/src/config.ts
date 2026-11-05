import { z } from 'zod';

const base64Key = z
  .string()
  .refine((s) => Buffer.from(s, 'base64').length === 32, 'must be 32 bytes, base64');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().default(8080),
  DATABASE_URL: z.string().url(),
  REDIS_URL: z.string().url().default('redis://localhost:6379'),
  JWT_SECRET: z.string().min(32),
  PII_ENCRYPTION_KEY: base64Key,
  PII_HASH_PEPPER: z.string().min(16),
  ADMIN_API_KEY: z.string().min(24),
  GOOGLE_CLIENT_ID: z.string().default(''),
  REVENUECAT_WEBHOOK_AUTH: z.string().min(16),
  RAZORPAY_WEBHOOK_SECRET: z.string().min(16),
  SMS_PROVIDER: z.enum(['console', 'msg91']).default('console'),
  MSG91_AUTH_KEY: z.string().default(''),
  MSG91_TEMPLATE_ID: z.string().default(''),
  WHATSAPP_PROVIDER: z.enum(['console', 'http']).default('console'),
  WHATSAPP_API_URL: z.string().default(''),
  WHATSAPP_API_TOKEN: z.string().default(''),
  ACCESS_TOKEN_TTL_S: z.coerce.number().int().default(15 * 60),
  REFRESH_TOKEN_TTL_DAYS: z.coerce.number().int().default(60),
  DELETION_GRACE_DAYS: z.coerce.number().int().default(30),
  CONTENT_DIR: z.string().default('../content/levels'),
});

export type Config = z.infer<typeof schema>;

export function loadConfig(env: NodeJS.ProcessEnv = process.env): Config {
  const parsed = schema.safeParse(env);
  if (!parsed.success) {
    const issues = parsed.error.issues.map((i) => `${i.path.join('.')}: ${i.message}`);
    throw new Error(`Invalid configuration:\n  ${issues.join('\n  ')}`);
  }
  if (parsed.data.NODE_ENV === 'production') {
    if (parsed.data.SMS_PROVIDER === 'console') throw new Error('SMS_PROVIDER=console is not allowed in production');
    if (parsed.data.WHATSAPP_PROVIDER === 'console') throw new Error('WHATSAPP_PROVIDER=console is not allowed in production');
  }
  return parsed.data;
}
