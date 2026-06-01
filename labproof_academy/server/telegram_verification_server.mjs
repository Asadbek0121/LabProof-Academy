import { createHash, randomInt, randomUUID } from 'node:crypto';
import { createServer } from 'node:http';
import { readFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';

loadDotEnv();

const port = Number(process.env.PORT || 8787);
const botToken = process.env.TELEGRAM_BOT_TOKEN;
let botUsername = process.env.TELEGRAM_BOT_USERNAME || 'LabProof_Support_bot';
let updateOffset = 0;

const sessions = new Map();
const ttlMs = 5 * 60 * 1000;

const server = createServer(async (request, response) => {
  setCors(response);

  if (request.method === 'OPTIONS') {
    response.writeHead(204);
    response.end();
    return;
  }

  try {
    if (request.method === 'GET' && request.url === '/health') {
      sendJson(response, 200, {
        ok: true,
        botConfigured: Boolean(botToken),
        botUsername,
      });
      return;
    }

    if (request.method === 'POST' && request.url === '/auth/telegram/request-code') {
      if (!botToken) {
        sendJson(response, 503, { error: 'Telegram bot token sozlanmagan.' });
        return;
      }

      const body = await readJson(request);
      const fullName = String(body.fullName || '').trim();
      const phone = normalizePhone(String(body.phone || ''));
      const password = String(body.password || '');

      if (!fullName || !phone || !password) {
        sendJson(response, 400, { error: 'Ism familiya, telefon va parol majburiy.' });
        return;
      }

      if (!phone.startsWith('+998') || phone.length < 13) {
        sendJson(response, 400, { error: 'Telefon raqam +998 bilan boshlanishi kerak.' });
        return;
      }

      const sessionId = randomUUID();
      const code = String(randomInt(1000, 10000));
      sessions.set(sessionId, {
        sessionId,
        fullName,
        phone,
        passwordHash: sha256(password),
        code,
        createdAt: Date.now(),
        expiresAt: Date.now() + ttlMs,
        confirmed: false,
        chatId: null,
        botState: 'awaiting_start',
      });

      sendJson(response, 200, {
        sessionId,
        botLink: `https://t.me/${botUsername}?start=${encodeURIComponent(sessionId)}`,
        expiresIn: Math.floor(ttlMs / 1000),
      });
      return;
    }

    if (request.method === 'POST' && request.url === '/auth/telegram/verify-code') {
      const body = await readJson(request);
      const sessionId = String(body.sessionId || '');
      const code = String(body.code || '').trim();
      const session = sessions.get(sessionId);

      if (!session || session.expiresAt < Date.now()) {
        sessions.delete(sessionId);
        sendJson(response, 400, { verified: false, error: 'Kod muddati tugagan.' });
        return;
      }

      if (session.code !== code) {
        sendJson(response, 400, { verified: false, error: 'Kod noto‘g‘ri.' });
        return;
      }

      sessions.delete(sessionId);
      sendJson(response, 200, { verified: true });
      return;
    }

    sendJson(response, 404, { error: 'Topilmadi.' });
  } catch (error) {
    console.error(error);
    sendJson(response, 500, { error: 'Server xatosi.' });
  }
});

server.listen(port, '127.0.0.1', async () => {
  console.log(`LabProof verification server: http://localhost:${port}`);
  if (!botToken) {
    console.warn('TELEGRAM_BOT_TOKEN topilmadi. .env faylga token kiriting.');
    return;
  }

  try {
    const me = await telegram('getMe');
    botUsername = me.result.username || botUsername;
    console.log(`Telegram bot ulandi: @${botUsername}`);
    pollTelegram().catch((error) => console.error(error));
  } catch (error) {
    console.error('Telegram botga ulanishda xatolik:', error.message);
  }
});

async function pollTelegram() {
  while (true) {
    try {
      const updates = await telegram('getUpdates', {
        offset: updateOffset,
        timeout: 25,
        allowed_updates: ['message', 'callback_query'],
      });

      for (const update of updates.result || []) {
        updateOffset = update.update_id + 1;
        await handleUpdate(update);
      }
    } catch (error) {
      console.error('Polling xatosi:', error.message);
      await sleep(2500);
    }

    cleanupSessions();
  }
}

async function handleUpdate(update) {
  if (update.message?.text?.startsWith('/start')) {
    const chatId = update.message.chat.id;
    const [, sessionId] = update.message.text.split(/\s+/, 2);
    const session = sessions.get(sessionId);

    if (!session || session.expiresAt < Date.now()) {
      await sendMessage(chatId, 'Tasdiqlash sessiyasi topilmadi yoki muddati tugagan. Ilovadan qayta urinib ko‘ring.');
      return;
    }

    session.chatId = chatId;
    session.botState = 'awaiting_name';
    session.nameConfirmed = false;

    await telegram('sendMessage', {
      chat_id: chatId,
      text: 'Xush kelibsiz! Iltimos, ilovada yozgan ism familiyangizni xuddi shunday qilib kiriting:',
      reply_markup: { remove_keyboard: true },
    });
    return;
  }

  if (update.message) {
    const chatId = update.message.chat.id;
    const session = Array.from(sessions.values()).find(s => s.chatId === chatId && s.botState !== 'completed');

    if (!session || session.expiresAt < Date.now()) {
      return;
    }

    if (session.botState === 'awaiting_name' && update.message.text) {
      if (!namesMatch(session.fullName, update.message.text)) {
        await telegram('sendMessage', {
          chat_id: chatId,
          text: 'Ism familiya ilovadagi bilan mos kelmadi. Iltimos, ilovada qanday yozgan bo‘lsangiz xuddi shunday qayta yozing:',
          reply_markup: { remove_keyboard: true }
        });
        return;
      }

      session.nameConfirmed = true;
      session.botState = 'awaiting_contact';
      await telegram('sendMessage', {
        chat_id: chatId,
        text: 'Ism familiya tasdiqlandi. Endi telefon raqamingizni qo‘lda yozmasdan, pastdagi tugma orqali yuboring.',
        reply_markup: {
          keyboard: [[{ text: 'Raqamni yuborish', request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true
        }
      });
      return;
    }

    if (update.message.contact) {
      if (!session.nameConfirmed) {
        await telegram('sendMessage', {
          chat_id: chatId,
          text: 'Avval ilovada yozgan ism familiyangizni xuddi shunday qilib kiriting.',
          reply_markup: { remove_keyboard: true }
        });
        return;
      }

      const contactOwnerId = update.message.contact.user_id;
      const telegramUserId = update.message.from?.id;
      if (contactOwnerId && telegramUserId && contactOwnerId !== telegramUserId) {
        await telegram('sendMessage', {
          chat_id: chatId,
          text: 'Faqat o‘zingizning Telegram hisobingizga ulangan raqamni yuboring.'
        });
        return;
      }

      const contactPhone = normalizePhone(update.message.contact.phone_number);
      if (contactPhone === session.phone) {
        session.botState = 'completed';
        session.confirmed = true;
        await telegram('sendMessage', {
          chat_id: chatId,
          text: `Tasdiqlash kodingiz: <code><b>${session.code}</b></code>\n\nUshbu kodni LabProof Academy ilovasiga kiritib, ro‘yxatdan o‘tishni yakunlang.`,
          parse_mode: 'HTML',
          reply_markup: { remove_keyboard: true }
        });
      } else {
        await telegram('sendMessage', {
          chat_id: chatId,
          text: 'Yuborilgan telefon raqam ilovadagi bilan mos kelmadi. Iltimos, ilovada ko‘rsatilgan o‘z raqamingizni yuboring.'
        });
      }
    } else {
      await telegram('sendMessage', {
        chat_id: chatId,
        text: session.nameConfirmed
          ? 'Telefon raqamni qo‘lda yozish mumkin emas. Pastdagi "Raqamni yuborish" tugmasini bosing.'
          : 'Avval ilovada yozgan ism familiyangizni xuddi shunday qilib kiriting.',
        reply_markup: session.nameConfirmed
          ? {
              keyboard: [[{ text: 'Raqamni yuborish', request_contact: true }]],
              resize_keyboard: true,
              one_time_keyboard: true
            }
          : { remove_keyboard: true }
      });
    }
    return;
  }
}

async function telegram(method, payload = {}) {
  const response = await fetch(`https://api.telegram.org/bot${botToken}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  const body = await response.json();
  if (!body.ok) {
    throw new Error(body.description || `Telegram ${method} failed`);
  }
  return body;
}

async function sendMessage(chatId, text) {
  return telegram('sendMessage', { chat_id: chatId, text });
}

function cleanupSessions() {
  const now = Date.now();
  for (const [sessionId, session] of sessions) {
    if (session.expiresAt < now) {
      sessions.delete(sessionId);
    }
  }
}

function setCors(response) {
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Content-Type');
}

function sendJson(response, statusCode, payload) {
  response.writeHead(statusCode, { 'Content-Type': 'application/json; charset=utf-8' });
  response.end(JSON.stringify(payload));
}

function readJson(request) {
  return new Promise((resolveRead, rejectRead) => {
    let data = '';
    request.on('data', (chunk) => {
      data += chunk;
      if (data.length > 1_000_000) {
        request.destroy();
        rejectRead(new Error('Request body too large'));
      }
    });
    request.on('end', () => {
      try {
        resolveRead(data ? JSON.parse(data) : {});
      } catch (error) {
        rejectRead(error);
      }
    });
    request.on('error', rejectRead);
  });
}

function normalizePhone(phone) {
  const digits = phone.replace(/\D/g, '');
  if (digits.startsWith('998')) return `+${digits}`;
  return `+998${digits}`;
}

function namesMatch(appName, telegramName) {
  return normalizeName(appName) === normalizeName(telegramName);
}

function normalizeName(value) {
  return String(value)
    .toLowerCase()
    .replace(/[’‘`']/g, "'")
    .replace(/[^a-zа-яёғқўҳ0-9'\s-]/giu, '')
    .replace(/\s+/g, ' ')
    .trim();
}

function sha256(value) {
  return createHash('sha256').update(value).digest('hex');
}

function sleep(ms) {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
}

function loadDotEnv() {
  const envPath = resolve(process.cwd(), '.env');
  if (!existsSync(envPath)) return;

  const contents = readFileSync(envPath, 'utf8');
  for (const line of contents.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const separator = trimmed.indexOf('=');
    if (separator === -1) continue;
    const key = trimmed.slice(0, separator).trim();
    const value = trimmed.slice(separator + 1).trim().replace(/^["']|["']$/g, '');
    if (!process.env[key]) process.env[key] = value;
  }
}
