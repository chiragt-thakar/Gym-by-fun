import { OAuth2Client } from 'google-auth-library';
import type { FastifyBaseLogger } from 'fastify';

import type { Config } from '../config.js';

export interface SmsSender {
  sendOtp(phoneE164: string, code: string): Promise<void>;
}

export interface WhatsAppSender {
  sendText(phoneE164: string, body: string): Promise<void>;
}

export interface GoogleVerifier {
  /** Returns the Google account subject for a valid ID token, else null. */
  verify(idToken: string): Promise<{ sub: string; name?: string } | null>;
}

/** Development only: logs that an OTP was sent, never the code in production. */
export class ConsoleSms implements SmsSender {
  constructor(private readonly log: FastifyBaseLogger) {}
  async sendOtp(phone: string, code: string) {
    this.log.info({ phone: `${phone.slice(0, 5)}*****`, code }, 'DEV OTP (console provider)');
  }
}

/** MSG91 OTP API. */
export class Msg91Sms implements SmsSender {
  constructor(
    private readonly authKey: string,
    private readonly templateId: string,
  ) {}
  async sendOtp(phone: string, code: string) {
    const res = await fetch('https://control.msg91.com/api/v5/otp', {
      method: 'POST',
      headers: { authkey: this.authKey, 'content-type': 'application/json' },
      body: JSON.stringify({ template_id: this.templateId, mobile: phone.replace('+', ''), otp: code }),
    });
    if (!res.ok) throw new Error(`MSG91 responded ${res.status}`);
  }
}

export class ConsoleWhatsApp implements WhatsAppSender {
  constructor(private readonly log: FastifyBaseLogger) {}
  async sendText(phone: string, body: string) {
    this.log.info({ phone: `${phone.slice(0, 5)}*****`, body }, 'DEV WhatsApp (console provider)');
  }
}

/** Generic BSP (WhatsApp Business Solution Provider) HTTP adapter. */
export class HttpWhatsApp implements WhatsAppSender {
  constructor(
    private readonly url: string,
    private readonly token: string,
  ) {}
  async sendText(phone: string, body: string) {
    const res = await fetch(this.url, {
      method: 'POST',
      headers: { authorization: `Bearer ${this.token}`, 'content-type': 'application/json' },
      body: JSON.stringify({ to: phone, type: 'text', text: { body } }),
    });
    if (!res.ok) throw new Error(`WhatsApp provider responded ${res.status}`);
  }
}

export class GoogleIdTokenVerifier implements GoogleVerifier {
  private readonly client = new OAuth2Client();
  constructor(private readonly clientId: string) {}
  async verify(idToken: string) {
    if (!this.clientId) return null;
    try {
      const ticket = await this.client.verifyIdToken({ idToken, audience: this.clientId });
      const p = ticket.getPayload();
      if (!p?.sub || p.email_verified === false) return null;
      return { sub: p.sub, name: p.given_name };
    } catch {
      return null;
    }
  }
}

export interface Providers {
  sms: SmsSender;
  whatsapp: WhatsAppSender;
  google: GoogleVerifier;
}

export function defaultProviders(config: Config, log: FastifyBaseLogger): Providers {
  return {
    sms: config.SMS_PROVIDER === 'msg91' ? new Msg91Sms(config.MSG91_AUTH_KEY, config.MSG91_TEMPLATE_ID) : new ConsoleSms(log),
    whatsapp:
      config.WHATSAPP_PROVIDER === 'http'
        ? new HttpWhatsApp(config.WHATSAPP_API_URL, config.WHATSAPP_API_TOKEN)
        : new ConsoleWhatsApp(log),
    google: new GoogleIdTokenVerifier(config.GOOGLE_CLIENT_ID),
  };
}
