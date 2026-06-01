import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
};

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const telegramToken = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const botUsername =
  Deno.env.get("TELEGRAM_BOT_USERNAME") ?? "LabProof_Support_bot";

const admin = createClient(supabaseUrl, serviceRoleKey, {
  auth: { autoRefreshToken: false, persistSession: false },
});

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  const url = new URL(request.url);
  const path = url.pathname.replace(/^\/auth/, "");

  try {
    if (request.method === "GET" && path === "/health") {
      return json({
        ok: true,
        botConfigured: Boolean(telegramToken),
        botUsername,
      });
    }

    if (request.method === "POST" && path === "/phone/status") {
      return await phoneStatus(request);
    }

    if (request.method === "POST" && path === "/telegram/request-code") {
      return await requestTelegramCode(request);
    }

    if (request.method === "POST" && path === "/telegram/request-reset-code") {
      return await requestPasswordResetCode(request);
    }

    if (request.method === "POST" && path === "/telegram/verify-code") {
      return await verifyTelegramCode(request);
    }

    if (request.method === "POST" && path === "/telegram/send-admin-reply") {
      return await sendAdminReply(request);
    }

    if (request.method === "POST" && path === "/telegram/mark-inbox-read") {
      return await markAdminInboxRead(request);
    }

    if (request.method === "POST" && path === "/notifications/mark-read") {
      return await markNotificationRead(request);
    }

    if (request.method === "POST" && path === "/profile/update") {
      return await updateProfile(request);
    }

    if (request.method === "POST" && path === "/telegram/webhook") {
      return await telegramWebhook(request);
    }

    return json({ error: "Topilmadi." }, 404);
  } catch (error) {
    console.error(error);
    return json({ error: "Server xatosi." }, 500);
  }
});

async function phoneStatus(request: Request) {
  const body = await request.json();
  const phone = normalizePhone(String(body.phone ?? ""));

  if (!phone.startsWith("+998") || phone.length !== 13) {
    return json({ error: "Telefon raqam +998 formatida bo‘lishi kerak." }, 400);
  }

  const authEmail = phoneAuthEmail(phone);
  const existingUser = await findUserByPhoneOrEmail(phone, authEmail);
  return json({ exists: Boolean(existingUser) });
}

async function requestTelegramCode(request: Request) {
  if (!telegramToken) {
    return json({ error: "Telegram bot token sozlanmagan." }, 503);
  }

  const body = await request.json();
  const fullName = String(body.fullName ?? "").trim();
  const phone = normalizePhone(String(body.phone ?? ""));
  const password = String(body.password ?? "");

  if (!fullName || !phone || !password) {
    return json({ error: "Ism familiya, telefon va parol majburiy." }, 400);
  }

  if (password.length < 6) {
    return json({ error: "Parol kamida 6 ta belgi bo‘lishi kerak." }, 400);
  }

  if (!phone.startsWith("+998") || phone.length !== 13) {
    return json({ error: "Telefon raqam +998 formatida bo‘lishi kerak." }, 400);
  }

  const authEmail = phoneAuthEmail(phone);
  const existingUser = await findUserByPhoneOrEmail(phone, authEmail);
  if (existingUser) {
    return json(
      {
        error:
          "Bu telefon raqam bilan akkaunt mavjud. Parol esdan chiqqan bo‘lsa, parolni tiklang.",
      },
      409,
    );
  }

  const code = String(crypto.getRandomValues(new Uint32Array(1))[0])
    .padStart(10, "0")
    .slice(0, 4);

  await admin.from("telegram_verifications").delete().eq("phone", phone);

  const { data, error } = await admin
    .from("telegram_verifications")
    .insert({
      full_name: fullName,
      phone,
      code,
      purpose: "register",
      expires_at: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
    })
    .select("id")
    .single();

  if (error) {
    return json({ error: error.message }, 400);
  }

  return json({
    sessionId: data.id,
    botLink: `https://t.me/${botUsername}?start=${encodeURIComponent(data.id)}`,
    expiresIn: 120,
  });
}

async function requestPasswordResetCode(request: Request) {
  if (!telegramToken) {
    return json({ error: "Telegram bot token sozlanmagan." }, 503);
  }

  const body = await request.json();
  const phone = normalizePhone(String(body.phone ?? ""));

  if (!phone.startsWith("+998") || phone.length !== 13) {
    return json({ error: "Telefon raqam +998 formatida bo‘lishi kerak." }, 400);
  }

  const authEmail = phoneAuthEmail(phone);
  const existingUser = await findUserByPhoneOrEmail(phone, authEmail);
  if (!existingUser) {
    return json({ error: "Bu telefon raqam bilan akkaunt topilmadi." }, 404);
  }

  const profile = await getProfile(existingUser.id);
  const fullName = String(
    profile?.full_name ?? existingUser.user_metadata?.full_name ?? "Student",
  ).trim();

  const code = String(crypto.getRandomValues(new Uint32Array(1))[0])
    .padStart(10, "0")
    .slice(0, 4);

  await admin.from("telegram_verifications").delete().eq("phone", phone);

  const { data, error } = await admin
    .from("telegram_verifications")
    .insert({
      full_name: fullName,
      phone,
      code,
      purpose: "password_reset",
      name_confirmed: true,
      expires_at: new Date(Date.now() + 2 * 60 * 1000).toISOString(),
    })
    .select("id")
    .single();

  if (error) {
    return json({ error: error.message }, 400);
  }

  return json({
    sessionId: data.id,
    botLink: `https://t.me/${botUsername}?start=${encodeURIComponent(data.id)}`,
    expiresIn: 120,
  });
}

async function verifyTelegramCode(request: Request) {
  const body = await request.json();
  const sessionId = String(body.sessionId ?? "");
  const code = String(body.code ?? "").trim();
  const password = String(body.password ?? "");

  if (!sessionId || !code || !password) {
    return json(
      { verified: false, error: "Kod yoki parol yetishmayapti." },
      400,
    );
  }

  if (password.length < 6) {
    return json(
      { verified: false, error: "Parol kamida 6 ta belgi bo‘lishi kerak." },
      400,
    );
  }

  const { data: session, error } = await admin
    .from("telegram_verifications")
    .select(
      "id, full_name, phone, code, confirmed, expires_at, purpose, chat_id",
    )
    .eq("id", sessionId)
    .maybeSingle();

  if (error || !session) {
    return json({ verified: false, error: "Sessiya topilmadi." }, 400);
  }

  if (new Date(session.expires_at).getTime() < Date.now()) {
    await admin.from("telegram_verifications").delete().eq("id", sessionId);
    return json({ verified: false, error: "Kod muddati tugagan." }, 400);
  }

  if (session.code !== code) {
    return json({ verified: false, error: "Kod noto‘g‘ri." }, 400);
  }

  if (!session.confirmed) {
    return json(
      {
        verified: false,
        error: "Telefon raqam Telegram orqali tasdiqlanmagan.",
      },
      400,
    );
  }

  if (session.purpose === "password_reset") {
    return await resetPasswordForExistingUser(session, password, sessionId);
  }

  let authUser: any = null;
  const authEmail = phoneAuthEmail(session.phone);
  const { data: userData, error: createError } =
    await admin.auth.admin.createUser({
      email: authEmail,
      password,
      email_confirm: true,
      user_metadata: {
        full_name: session.full_name,
        phone: session.phone,
        role: "student",
      },
    });

  if (createError) {
    const existingUser = await findUserByPhoneOrEmail(session.phone, authEmail);
    if (existingUser) {
      return json(
        {
          verified: false,
          error:
            "Bu telefon raqam bilan akkaunt mavjud. Parol esdan chiqqan bo‘lsa, parolni tiklang.",
        },
        409,
      );
    }

    return json(
      { verified: false, error: friendlyAuthError(createError.message) },
      400,
    );
  } else {
    authUser = userData.user;
  }

  if (authUser) {
    const role = authUser.user_metadata?.role ?? "student";
    await admin.from("profiles").upsert({
      id: authUser.id,
      full_name: session.full_name,
      phone: session.phone,
      role,
      telegram_chat_id: session.chat_id ?? null,
      telegram_last_seen_at: session.chat_id ? new Date().toISOString() : null,
    });
  }

  await admin.from("telegram_verifications").delete().eq("id", sessionId);
  return json({ verified: true });
}

async function resetPasswordForExistingUser(
  session: {
    full_name: string;
    phone: string;
    chat_id?: string | null;
  },
  password: string,
  sessionId: string,
) {
  const authEmail = phoneAuthEmail(session.phone);
  const existingUser = await findUserByPhoneOrEmail(session.phone, authEmail);
  if (!existingUser) {
    return json(
      { verified: false, error: "Akkaunt topilmadi. Qayta ro‘yxatdan o‘ting." },
      404,
    );
  }

  const { error } = await admin.auth.admin.updateUserById(existingUser.id, {
    email: authEmail,
    password,
    email_confirm: true,
    user_metadata: {
      ...(existingUser.user_metadata ?? {}),
      full_name: session.full_name,
      phone: session.phone,
      role: existingUser.user_metadata?.role ?? "student",
    },
  });

  if (error) {
    return json(
      { verified: false, error: friendlyAuthError(error.message) },
      400,
    );
  }

  await admin.from("profiles").upsert({
    id: existingUser.id,
    full_name: session.full_name,
    phone: session.phone,
    role: existingUser.user_metadata?.role ?? "student",
    telegram_chat_id: session.chat_id ?? null,
    telegram_last_seen_at: session.chat_id ? new Date().toISOString() : null,
  });

  await admin.from("telegram_verifications").delete().eq("id", sessionId);
  return json({ verified: true, mode: "password_reset" });
}

async function updateProfile(request: Request) {
  const accessToken = request.headers
    .get("Authorization")
    ?.replace("Bearer ", "")
    .trim();
  if (!accessToken) {
    return json({ error: "Sessiya topilmadi. Qayta kiring." }, 401);
  }

  const { data: authData, error: authError } =
    await admin.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return json({ error: "Sessiya tasdiqlanmadi. Qayta kiring." }, 401);
  }

  const user = authData.user;
  const body = await request.json();
  const firstName = String(body.firstName ?? "").trim();
  const lastName = String(body.lastName ?? "").trim();
  const phone = normalizePhone(String(body.phone ?? ""));
  const gender = String(body.gender ?? "").trim();
  const ageValue = body.age;
  const age =
    typeof ageValue === "number"
      ? Math.round(ageValue)
      : String(ageValue ?? "").trim()
        ? Number(String(ageValue).trim())
        : null;
  const region = String(body.region ?? "").trim();
  const district = String(body.district ?? "").trim();
  const mahalla = String(body.mahalla ?? "").trim();
  const street = String(body.street ?? "").trim();
  const avatarUrl = String(body.avatarUrl ?? "").trim();
  const fullName = `${firstName} ${lastName}`.trim();

  if (firstName.length < 2 || fullName.length < 3) {
    return json({ error: "Ism va familiyani to‘liq kiriting." }, 400);
  }

  if (!phone.startsWith("+998") || phone.length !== 13) {
    return json({ error: "Telefon raqam +998 formatida bo‘lishi kerak." }, 400);
  }

  if (
    gender &&
    !["erkak", "ayol", "male", "female"].includes(gender.toLowerCase())
  ) {
    return json({ error: "Jins maydoni noto‘g‘ri." }, 400);
  }

  if (age !== null && (!Number.isFinite(age) || age < 10 || age > 120)) {
    return json({ error: "Yosh 10 dan 120 gacha bo‘lishi kerak." }, 400);
  }

  const nextEmail = phoneAuthEmail(phone);
  const duplicateUser = await findUserByPhoneOrEmail(phone, nextEmail);
  if (duplicateUser && duplicateUser.id !== user.id) {
    return json(
      { error: "Bu telefon raqam boshqa akkauntga biriktirilgan." },
      409,
    );
  }

  const currentMetadata = user.user_metadata ?? {};
  const { error: updateAuthError } = await admin.auth.admin.updateUserById(
    user.id,
    {
      email: nextEmail,
      email_confirm: true,
      user_metadata: {
        ...currentMetadata,
        full_name: fullName,
        phone,
        gender,
        age,
        region,
        district,
        mahalla,
        street,
      },
    },
  );

  if (updateAuthError) {
    return json({ error: friendlyAuthError(updateAuthError.message) }, 400);
  }

  const currentProfile = await getProfile(user.id);
  const role = currentProfile?.role ?? currentMetadata.role ?? "student";
  const { error: profileError } = await admin.from("profiles").upsert({
    id: user.id,
    full_name: fullName,
    phone,
    role,
    avatar_url: avatarUrl || currentProfile?.avatar_url || null,
    gender,
    age,
    region,
    district,
    mahalla,
    street,
    updated_at: new Date().toISOString(),
  });

  if (profileError) {
    return json({ error: profileError.message }, 400);
  }

  return json({
    ok: true,
    profile: {
      full_name: fullName,
      phone,
      gender,
      age,
      region,
      district,
      mahalla,
      street,
      avatar_url: avatarUrl || currentProfile?.avatar_url || "",
    },
  });
}

async function findUserByPhoneOrEmail(phone: string, email: string) {
  const normalizedPhone = normalizePhone(phone);
  const normalizedEmail = email.toLowerCase();

  for (let page = 1; page <= 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({
      page,
      perPage: 1000,
    });

    if (error) {
      console.error(error);
      return null;
    }

    const users = data.users ?? [];
    const found = users.find(
      (user: any) =>
        normalizePhone(user.phone ?? user.user_metadata?.phone ?? "") ===
          normalizedPhone ||
        String(user.email ?? "").toLowerCase() === normalizedEmail,
    );

    if (found) return found;
    if (users.length < 1000) return null;
  }

  return null;
}

function friendlyAuthError(message: string) {
  const lower = message.toLowerCase();
  if (
    lower.includes("password should be at least") ||
    (lower.includes("password") && lower.includes("6"))
  ) {
    return "Parol kamida 6 ta belgi bo‘lishi kerak.";
  }

  return message;
}

async function telegramWebhook(request: Request) {
  if (!telegramToken) {
    return json({ ok: false, error: "Telegram bot token sozlanmagan." }, 503);
  }

  const update = await request.json();

  if (update.message?.text?.startsWith("/start")) {
    const chatId = update.message.chat.id;
    const sessionId = String(update.message.text).split(" ")[1] ?? "";
    const session = await getSession(sessionId);

    if (!session) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Tasdiqlash sessiyasi topilmadi yoki muddati tugagan.",
      });
      return json({ ok: true });
    }

    await admin
      .from("telegram_verifications")
      .update({
        chat_id: String(chatId),
        confirmed: false,
        name_confirmed: session.purpose === "password_reset",
      })
      .eq("id", sessionId);

    if (session.purpose === "password_reset") {
      await sendContactPrompt(
        chatId,
        "Parolni yangilash uchun, pastdagi <b>📞 Raqamni yuborish</b> tugmasini bosing:",
      );
    } else {
      await telegram("sendMessage", {
        chat_id: chatId,
        text:
          "Salom va xush kelibsiz! 👋\n\n" +
          "Iltimos, ilovada yozgan ism va familiyangizni xuddi o‘zidek qilib yuboring:",
        reply_markup: { remove_keyboard: true },
      });
    }
    return json({ ok: true });
  }

  if (update.message?.text) {
    const chatId = update.message.chat.id;
    const session = await getActiveSessionByChat(chatId);

    if (session && !session.name_confirmed) {
      if (!namesMatch(session.full_name, update.message.text)) {
        await telegram("sendMessage", {
          chat_id: chatId,
          text: "Ism familiya ilovadagi bilan mos kelmadi. Iltimos, ilovada qanday yozgan bo‘lsangiz xuddi shunday qayta yozing:",
          reply_markup: { remove_keyboard: true },
        });
        return json({ ok: true });
      }

      await admin
        .from("telegram_verifications")
        .update({ name_confirmed: true })
        .eq("id", session.id);

      await sendContactPrompt(
        chatId,
        "Ism va familiya qabul qilindi ✅\n\nEndi telefon raqamingizni tasdiqlash uchun pastdagi <b>📞 Raqamni yuborish</b> tugmasini bosing.",
      );
      return json({ ok: true });
    }

    if (!session) {
      const linkedProfile = await getProfileByChatId(chatId);
      await saveAdminInboxMessage({
        source: "telegram",
        senderUserId: linkedProfile?.id,
        senderName:
          linkedProfile?.full_name || telegramSenderName(update.message.from),
        senderPhone: linkedProfile?.phone ?? "",
        telegramChatId: String(chatId),
        subject: "Telegram orqali yangi xabar",
        body: String(update.message.text).trim(),
        messageKind: "text",
        createdAt: update.message.date
          ? new Date(update.message.date * 1000).toISOString()
          : undefined,
      });

      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Xabaringiz administratorga yuborildi. Tez orada siz bilan bog‘lanishadi.",
        reply_markup: { remove_keyboard: true },
      });
      return json({ ok: true });
    }
  }

  if (update.message?.contact) {
    const chatId = update.message.chat.id;
    const session = await getActiveSessionByChat(chatId);

    if (!session) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Tasdiqlash sessiyasi topilmadi. Ilovadan qayta urinib ko‘ring.",
        reply_markup: { remove_keyboard: true },
      });
      return json({ ok: true });
    }

    if (!session.name_confirmed) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Avval ilovada yozgan ism familiyangizni xuddi shunday qilib kiriting.",
        reply_markup: { remove_keyboard: true },
      });
      return json({ ok: true });
    }

    const contactOwnerId = update.message.contact.user_id;
    const telegramUserId = update.message.from?.id;
    if (contactOwnerId && telegramUserId && contactOwnerId !== telegramUserId) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Faqat o‘zingizning Telegram hisobingizga ulangan raqamni yuboring.",
      });
      return json({ ok: true });
    }

    const contactPhone = normalizePhone(update.message.contact.phone_number);
    if (contactPhone !== session.phone) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Yuborilgan telefon raqam ilovadagi raqam bilan mos kelmadi. Ilovadagi o‘z raqamingizni Telegram tugmasi orqali yuboring.",
      });
      return json({ ok: true });
    }

    await admin
      .from("telegram_verifications")
      .update({ chat_id: String(chatId), confirmed: true })
      .eq("id", session.id);

    await linkTelegramIdentityToProfile({
      chatId: String(chatId),
      telegramUserId: update.message.from?.id
        ? String(update.message.from.id)
        : undefined,
      telegramUsername: update.message.from?.username,
      phone: session.phone,
      fallbackFullName: session.full_name,
    });

    await telegram("sendMessage", {
      chat_id: chatId,
      text:
        `Raqamingiz qabul qilindi ✅\n\n` +
        `Tasdiqlash kodingiz:\n\n` +
        `<b><code>${session.code}</code></b>\n\n` +
        `Iltimos, ushbu kodni ilovaga qaytib kiriting.\n\n` +
        `⚠️ Kod 2 daqiqa davomida amal qiladi.`,
      parse_mode: "HTML",
      reply_markup: { remove_keyboard: true },
    });
    return json({ ok: true });
  }

  if (update.message) {
    const chatId = update.message.chat.id;
    const session = await getActiveSessionByChat(chatId);

    if (session) {
      if (!session.name_confirmed) {
        await telegram("sendMessage", {
          chat_id: chatId,
          text: "Avval ilovada yozgan ism familiyangizni xuddi shunday qilib kiriting.",
          reply_markup: { remove_keyboard: true },
        });
        return json({ ok: true });
      }

      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Telefon raqamni qo‘lda yozish mumkin emas. Pastdagi <b>📞 Raqamni yuborish</b> tugmasini bosing.",
        parse_mode: "HTML",
        reply_markup: {
          keyboard: [[{ text: "📞 Raqamni yuborish", request_contact: true }]],
          resize_keyboard: true,
          one_time_keyboard: true,
        },
      });
      return json({ ok: true });
    }

    const parsed = await parseTelegramIncomingMessage(update.message);
    if (parsed) {
      const linkedProfile = await getProfileByChatId(chatId);
      await saveAdminInboxMessage({
        source: "telegram",
        senderUserId: linkedProfile?.id,
        senderName:
          linkedProfile?.full_name || telegramSenderName(update.message.from),
        senderPhone: linkedProfile?.phone ?? "",
        telegramChatId: String(chatId),
        subject: parsed.subject,
        body: parsed.body,
        messageKind: parsed.messageKind,
        attachmentUrl: parsed.attachmentUrl,
        attachmentName: parsed.attachmentName,
        attachmentMime: parsed.attachmentMime,
        attachmentSize: parsed.attachmentSize,
        createdAt: update.message.date
          ? new Date(update.message.date * 1000).toISOString()
          : undefined,
      });

      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Xabaringiz administratorga yuborildi. Javob bo‘lsa shu chatga qaytadi.",
        reply_markup: { remove_keyboard: true },
      });
    }
    return json({ ok: true });
  }

  if (update.callback_query) {
    const callbackId = update.callback_query.id;
    const chatId = update.callback_query.message.chat.id;
    const [action, sessionId] = String(update.callback_query.data).split(":");
    if (action === "ack_reply") {
      await admin
        .from("admin_inbox_messages")
        .update({ recipient_read_at: new Date().toISOString() })
        .eq("id", sessionId);
      await telegram("answerCallbackQuery", {
        callback_query_id: callbackId,
        text: "Javob o‘qildi deb belgilandi.",
      });
      return json({ ok: true });
    }
    const session = await getSession(sessionId);

    if (!session) {
      await telegram("answerCallbackQuery", {
        callback_query_id: callbackId,
        text: "Sessiya topilmadi.",
      });
      return json({ ok: true });
    }

    if (action === "cancel") {
      await admin.from("telegram_verifications").delete().eq("id", sessionId);
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Ro‘yxatdan o‘tish bekor qilindi.",
      });
      return json({ ok: true });
    }

    await telegram("answerCallbackQuery", { callback_query_id: callbackId });
    await telegram("sendMessage", {
      chat_id: chatId,
      text: "Yangilangan tartib bo‘yicha avval ism familiya mosligi tekshiriladi, keyin telefon raqam Telegram tugmasi orqali yuboriladi. Iltimos, ilovadan qayta urinib ko‘ring.",
    });
  }

  return json({ ok: true });
}

async function getSession(sessionId: string) {
  if (!sessionId) return null;

  const { data } = await admin
    .from("telegram_verifications")
    .select(
      "id, full_name, phone, code, confirmed, name_confirmed, expires_at, purpose, chat_id",
    )
    .eq("id", sessionId)
    .maybeSingle();

  if (!data || new Date(data.expires_at).getTime() < Date.now()) {
    return null;
  }

  return data;
}

async function getActiveSessionByChat(chatId: number | string) {
  const { data } = await admin
    .from("telegram_verifications")
    .select(
      "id, full_name, phone, code, confirmed, name_confirmed, expires_at, purpose, chat_id",
    )
    .eq("chat_id", String(chatId))
    .eq("confirmed", false)
    .gt("expires_at", new Date().toISOString())
    .order("created_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  return data;
}

async function sendContactPrompt(chatId: number | string, text: string) {
  await telegram("sendMessage", {
    chat_id: chatId,
    text: text,
    parse_mode: "HTML",
    reply_markup: {
      keyboard: [[{ text: "📞 Raqamni yuborish", request_contact: true }]],
      resize_keyboard: true,
      one_time_keyboard: true,
    },
  });
}

async function getProfileByChatId(chatId: number | string) {
  const { data } = await admin
    .from("profiles")
    .select(
      "id, full_name, phone, role, telegram_chat_id, telegram_user_id, telegram_username",
    )
    .eq("telegram_chat_id", String(chatId))
    .maybeSingle();

  return data;
}

async function getProfileByPhone(phone: string) {
  const normalizedPhone = normalizePhone(phone);
  const { data } = await admin
    .from("profiles")
    .select(
      "id, full_name, phone, role, telegram_chat_id, telegram_user_id, telegram_username",
    )
    .eq("phone", normalizedPhone)
    .maybeSingle();

  return data;
}

async function getRecentTelegramChatId({
  senderUserId,
  senderPhone,
  senderName,
}: {
  senderUserId?: string | null;
  senderPhone?: string | null;
  senderName?: string | null;
}) {
  if (senderUserId) {
    const { data } = await admin
      .from("admin_inbox_messages")
      .select("telegram_chat_id")
      .eq("sender_user_id", senderUserId)
      .not("telegram_chat_id", "is", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (data?.telegram_chat_id) return String(data.telegram_chat_id);
  }

  const normalizedPhone = senderPhone ? normalizePhone(senderPhone) : "";
  if (normalizedPhone) {
    const linkedProfile = await getProfileByPhone(normalizedPhone);
    if (linkedProfile?.telegram_chat_id) {
      return String(linkedProfile.telegram_chat_id);
    }

    const { data } = await admin
      .from("admin_inbox_messages")
      .select("telegram_chat_id")
      .eq("sender_phone", normalizedPhone)
      .not("telegram_chat_id", "is", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (data?.telegram_chat_id) return String(data.telegram_chat_id);

    const { data: verificationByPhone } = await admin
      .from("telegram_verifications")
      .select("chat_id")
      .eq("phone", normalizedPhone)
      .not("chat_id", "is", null)
      .order("expires_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (verificationByPhone?.chat_id)
      return String(verificationByPhone.chat_id);
  }

  if (senderName?.trim()) {
    const normalizedName = senderName.trim();
    const { data } = await admin
      .from("admin_inbox_messages")
      .select("telegram_chat_id")
      .eq("sender_name", normalizedName)
      .not("telegram_chat_id", "is", null)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (data?.telegram_chat_id) return String(data.telegram_chat_id);

    const { data: verificationByName } = await admin
      .from("telegram_verifications")
      .select("chat_id")
      .eq("full_name", normalizedName)
      .not("chat_id", "is", null)
      .order("expires_at", { ascending: false })
      .limit(1)
      .maybeSingle();
    if (verificationByName?.chat_id) return String(verificationByName.chat_id);
  }

  return null;
}

async function linkTelegramIdentityToProfile({
  chatId,
  telegramUserId,
  telegramUsername,
  phone,
  fallbackFullName,
}: {
  chatId: string;
  telegramUserId?: string;
  telegramUsername?: string;
  phone: string;
  fallbackFullName: string;
}) {
  const profile = await getProfileByPhone(phone);
  if (!profile?.id) return;

  await admin.from("profiles").upsert({
    id: profile.id,
    full_name: profile.full_name || fallbackFullName,
    phone,
    role: profile.role ?? "student",
    telegram_chat_id: chatId,
    telegram_user_id: telegramUserId ?? profile.telegram_user_id ?? null,
    telegram_username: telegramUsername ?? profile.telegram_username ?? null,
    telegram_last_seen_at: new Date().toISOString(),
  });
}

function extensionFromPath(path: string, fallback = "bin") {
  const cleanPath = path.split("?")[0];
  const segments = cleanPath.split(".");
  return segments.length > 1 ? segments.pop()!.toLowerCase() : fallback;
}

function contentTypeForExtension(extension: string) {
  switch (extension.toLowerCase()) {
    case "png":
      return "image/png";
    case "jpg":
    case "jpeg":
      return "image/jpeg";
    case "webp":
      return "image/webp";
    case "gif":
      return "image/gif";
    case "mp4":
      return "video/mp4";
    case "mov":
      return "video/quicktime";
    case "ogg":
    case "oga":
      return "audio/ogg";
    case "mp3":
      return "audio/mpeg";
    case "wav":
      return "audio/wav";
    case "m4a":
      return "audio/x-m4a";
    case "pdf":
      return "application/pdf";
    case "doc":
      return "application/msword";
    case "docx":
      return "application/vnd.openxmlformats-officedocument.wordprocessingml.document";
    case "txt":
      return "text/plain";
    default:
      return "application/octet-stream";
  }
}

async function uploadTelegramFileToStorage({
  fileId,
  preferredName,
  fallbackExtension,
  contentType,
}: {
  fileId: string;
  preferredName?: string;
  fallbackExtension: string;
  contentType?: string;
}) {
  const filePayload = await telegram("getFile", { file_id: fileId });
  const filePath = filePayload?.result?.file_path;
  if (!filePath) return null;

  const extension = extensionFromPath(filePath, fallbackExtension);
  const downloadResponse = await fetch(
    `https://api.telegram.org/file/bot${telegramToken}/${filePath}`,
  );
  if (!downloadResponse.ok) return null;

  const bytes = new Uint8Array(await downloadResponse.arrayBuffer());
  const safeName = (preferredName ?? `telegram_${Date.now()}`)
    .replace(/[^a-zA-Z0-9._-]/g, "_")
    .replace(new RegExp(`\\.${extension}$`, "i"), "");
  const path = `telegram/${Date.now()}_${crypto.randomUUID()}_${safeName}.${extension}`;

  const { error } = await admin.storage
    .from("chat-attachments")
    .upload(path, bytes, {
      contentType: contentType ?? contentTypeForExtension(extension),
      upsert: false,
    });

  if (error) {
    console.error(error);
    return null;
  }

  return {
    publicUrl: admin.storage.from("chat-attachments").getPublicUrl(path).data
      .publicUrl,
    extension,
    size: bytes.byteLength,
    mime: contentType ?? contentTypeForExtension(extension),
  };
}

async function parseTelegramIncomingMessage(message: any) {
  const text = String(message.text ?? "").trim();
  if (text) {
    return {
      subject: "Telegram orqali yangi xabar",
      body: text,
      messageKind: "text",
    };
  }

  if (Array.isArray(message.photo) && message.photo.length > 0) {
    const photo = message.photo[message.photo.length - 1];
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(photo.file_id),
      preferredName: `telegram_photo_${message.message_id ?? Date.now()}`,
      fallbackExtension: "jpg",
      contentType: "image/jpeg",
    });
    return {
      subject: "Telegram orqali yangi rasm",
      body: String(message.caption ?? "Rasm yuborildi.").trim(),
      messageKind: "image",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: uploaded ? "telegram-photo.jpg" : null,
      attachmentMime: uploaded?.mime,
      attachmentSize: uploaded?.size,
    };
  }

  if (message.voice?.file_id) {
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.voice.file_id),
      preferredName: `telegram_voice_${message.message_id ?? Date.now()}`,
      fallbackExtension: "ogg",
      contentType: "audio/ogg",
    });
    return {
      subject: "Telegram orqali ovozli xabar",
      body: String(message.caption ?? "Ovozli xabar yuborildi.").trim(),
      messageKind: "voice",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: uploaded ? "telegram-voice.ogg" : null,
      attachmentMime: uploaded?.mime,
      attachmentSize: uploaded?.size,
    };
  }

  if (message.video_note?.file_id) {
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.video_note.file_id),
      preferredName: `telegram_video_note_${message.message_id ?? Date.now()}`,
      fallbackExtension: "mp4",
      contentType: "video/mp4",
    });
    return {
      subject: "Telegram orqali dumaloq video",
      body: String(message.caption ?? "Dumaloq video yuborildi.").trim(),
      messageKind: "video_note",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: uploaded ? "telegram-video-note.mp4" : null,
      attachmentMime: uploaded?.mime,
      attachmentSize: uploaded?.size,
    };
  }

  if (message.video?.file_id) {
    const fileName = String(message.video.file_name ?? "telegram-video.mp4");
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.video.file_id),
      preferredName: fileName,
      fallbackExtension: extensionFromPath(fileName, "mp4"),
      contentType: String(message.video.mime_type ?? "video/mp4"),
    });
    return {
      subject: "Telegram orqali video",
      body: String(message.caption ?? "Video yuborildi.").trim(),
      messageKind: "video",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: fileName,
      attachmentMime: uploaded?.mime ?? String(message.video.mime_type ?? ""),
      attachmentSize: uploaded?.size ?? Number(message.video.file_size ?? 0),
    };
  }

  if (message.audio?.file_id) {
    const fileName = String(message.audio.file_name ?? "telegram-audio.mp3");
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.audio.file_id),
      preferredName: fileName,
      fallbackExtension: extensionFromPath(fileName, "mp3"),
      contentType: String(message.audio.mime_type ?? "audio/mpeg"),
    });
    return {
      subject: "Telegram orqali audio",
      body: String(message.caption ?? "Audio yuborildi.").trim(),
      messageKind: "audio",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: fileName,
      attachmentMime: uploaded?.mime ?? String(message.audio.mime_type ?? ""),
      attachmentSize: uploaded?.size ?? Number(message.audio.file_size ?? 0),
    };
  }

  if (message.document?.file_id) {
    const fileName = String(message.document.file_name ?? "telegram-document");
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.document.file_id),
      preferredName: fileName,
      fallbackExtension: extensionFromPath(fileName, "bin"),
      contentType: String(
        message.document.mime_type ??
          contentTypeForExtension(extensionFromPath(fileName, "bin")),
      ),
    });
    return {
      subject: "Telegram orqali fayl",
      body: String(message.caption ?? "Fayl yuborildi.").trim(),
      messageKind: "document",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: fileName,
      attachmentMime:
        uploaded?.mime ?? String(message.document.mime_type ?? ""),
      attachmentSize: uploaded?.size ?? Number(message.document.file_size ?? 0),
    };
  }

  if (message.sticker?.file_id) {
    const stickerExt = message.sticker.is_video ? "webm" : "webp";
    const uploaded = await uploadTelegramFileToStorage({
      fileId: String(message.sticker.file_id),
      preferredName: `telegram_sticker_${message.message_id ?? Date.now()}`,
      fallbackExtension: stickerExt,
      contentType: stickerExt == "webm" ? "video/webm" : "image/webp",
    });
    return {
      subject: "Telegram orqali sticker",
      body: "Sticker yuborildi.",
      messageKind: "sticker",
      attachmentUrl: uploaded?.publicUrl,
      attachmentName: uploaded ? `telegram-sticker.${stickerExt}` : null,
      attachmentMime: uploaded?.mime,
      attachmentSize: uploaded?.size,
    };
  }

  return null;
}

async function saveAdminInboxMessage({
  source,
  senderUserId,
  senderName,
  senderPhone,
  telegramChatId,
  subject,
  body,
  messageKind,
  attachmentUrl,
  attachmentName,
  attachmentMime,
  attachmentSize,
  createdAt,
}: {
  source: "telegram" | "student_app" | "system";
  senderUserId?: string;
  senderName: string;
  senderPhone: string;
  telegramChatId?: string;
  subject: string;
  body: string;
  messageKind?: string;
  attachmentUrl?: string | null;
  attachmentName?: string | null;
  attachmentMime?: string | null;
  attachmentSize?: number | null;
  createdAt?: string | null;
}) {
  await admin.from("admin_inbox_messages").insert({
    source,
    sender_user_id: senderUserId,
    sender_name: senderName,
    sender_phone: senderPhone,
    telegram_chat_id: telegramChatId,
    subject,
    body,
    message_kind: messageKind ?? "text",
    attachment_url: attachmentUrl ?? null,
    attachment_name: attachmentName ?? null,
    attachment_mime: attachmentMime ?? null,
    attachment_size: attachmentSize ?? null,
    created_at: createdAt ?? undefined,
  });
}

async function sendAdminReply(request: Request) {
  const accessToken = request.headers
    .get("Authorization")
    ?.replace("Bearer ", "")
    .trim();
  if (!accessToken) {
    return json({ error: "Sessiya topilmadi. Qayta kiring." }, 401);
  }

  const { data: authData, error: authError } =
    await admin.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return json({ error: "Sessiya tasdiqlanmadi. Qayta kiring." }, 401);
  }

  const actorProfile = await getProfile(authData.user.id);
  if (
    !actorProfile ||
    !["admin", "teacher"].includes(String(actorProfile.role ?? ""))
  ) {
    return json({ error: "Bu amal uchun ruxsat yo‘q." }, 403);
  }

  const body = await request.json();
  const messageId = String(body.messageId ?? "").trim();
  const replyText = String(body.replyText ?? "").trim();
  const messageKind = String(body.messageKind ?? "text").trim() || "text";
  const attachmentUrl = String(body.attachmentUrl ?? "").trim();
  const attachmentName = String(body.attachmentName ?? "").trim();
  const attachmentMime = String(body.attachmentMime ?? "").trim();
  const attachmentSize = Number(body.attachmentSize ?? 0) || null;

  if (!messageId || (!replyText && !attachmentUrl)) {
    return json({ error: "Javob matni yoki biriktirma majburiy." }, 400);
  }

  const { data: inboxMessage, error: inboxError } = await admin
    .from("admin_inbox_messages")
    .select(
      "id, source, sender_user_id, sender_name, sender_phone, telegram_chat_id, subject, body, is_read",
    )
    .eq("id", messageId)
    .maybeSingle();

  if (inboxError || !inboxMessage) {
    return json({ error: "Xabar topilmadi." }, 404);
  }

  if (inboxMessage.source === "telegram") {
    const resolvedChatId =
      inboxMessage.telegram_chat_id ||
      (inboxMessage.sender_user_id
        ? (await getProfile(inboxMessage.sender_user_id))?.telegram_chat_id
        : null) ||
      (inboxMessage.sender_phone
        ? (await getProfileByPhone(inboxMessage.sender_phone))?.telegram_chat_id
        : null) ||
      (await getRecentTelegramChatId({
        senderUserId: inboxMessage.sender_user_id,
        senderPhone: inboxMessage.sender_phone,
        senderName: inboxMessage.sender_name,
      }));

    if (!resolvedChatId) {
      return json({ error: "Telegram chat topilmadi." }, 400);
    }

    if (!inboxMessage.telegram_chat_id) {
      await admin
        .from("admin_inbox_messages")
        .update({ telegram_chat_id: resolvedChatId })
        .eq("id", messageId);
    }

    await sendTelegramAdminReply({
      chatId: resolvedChatId,
      messageId,
      text: replyText,
      messageKind,
      attachmentUrl,
      attachmentName,
    });
  } else {
    if (!inboxMessage.sender_user_id) {
      return json({ error: "Student foydalanuvchisi aniqlanmadi." }, 400);
    }

    await admin.from("notifications").insert({
      title: inboxMessage.subject
        ? `Admin javobi: ${inboxMessage.subject}`
        : "Admin javobi",
      body: replyText,
      target_role: "student",
      target_user_id: inboxMessage.sender_user_id,
      message_kind: messageKind,
      attachment_url: attachmentUrl || null,
      attachment_name: attachmentName || null,
      attachment_mime: attachmentMime || null,
      attachment_size: attachmentSize,
      reply_to_inbox_message_id: messageId,
      deep_link: "/profile",
      created_by: authData.user.id,
    });
  }

  await admin
    .from("admin_inbox_messages")
    .update({
      is_read: true,
      admin_reply: replyText,
      replied_at: new Date().toISOString(),
      recipient_read_at: null,
    })
    .eq("id", messageId);

  return json({ ok: true });
}

async function sendTelegramAdminReply({
  chatId,
  messageId,
  text,
  messageKind,
  attachmentUrl,
  attachmentName,
}: {
  chatId: string;
  messageId: string;
  text: string;
  messageKind: string;
  attachmentUrl?: string;
  attachmentName?: string;
}) {
  const replyMarkup = {
    inline_keyboard: [
      [{ text: "O‘qidim", callback_data: `ack_reply:${messageId}` }],
    ],
  };

  const caption = text.trim() || "Admin sizga media yubordi.";

  if (attachmentUrl) {
    if (messageKind === "image" || messageKind === "sticker") {
      await telegram("sendPhoto", {
        chat_id: chatId,
        photo: attachmentUrl,
        caption,
        reply_markup: replyMarkup,
      });
      return;
    }

    if (messageKind === "video_note") {
      await telegram("sendVideoNote", {
        chat_id: chatId,
        video_note: attachmentUrl,
        reply_markup: replyMarkup,
      });
      if (text.trim()) {
        await telegram("sendMessage", {
          chat_id: chatId,
          text: caption,
        });
      }
      return;
    }

    if (messageKind === "video") {
      await telegram("sendVideo", {
        chat_id: chatId,
        video: attachmentUrl,
        caption,
        reply_markup: replyMarkup,
      });
      return;
    }

    if (messageKind === "voice") {
      await telegram("sendVoice", {
        chat_id: chatId,
        voice: attachmentUrl,
        caption,
        reply_markup: replyMarkup,
      });
      return;
    }

    if (messageKind === "audio") {
      await telegram("sendAudio", {
        chat_id: chatId,
        audio: attachmentUrl,
        caption,
        title: attachmentName || "Audio",
        reply_markup: replyMarkup,
      });
      return;
    }

    await telegram("sendDocument", {
      chat_id: chatId,
      document: attachmentUrl,
      caption,
      reply_markup: replyMarkup,
    });
    return;
  }

  await telegram("sendMessage", {
    chat_id: chatId,
    text: `Admin javobi:\n\n${caption}`,
    reply_markup: replyMarkup,
  });
}

async function markAdminInboxRead(request: Request) {
  const accessToken = request.headers
    .get("Authorization")
    ?.replace("Bearer ", "")
    .trim();
  if (!accessToken) {
    return json({ error: "Sessiya topilmadi. Qayta kiring." }, 401);
  }

  const { data: authData, error: authError } =
    await admin.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return json({ error: "Sessiya tasdiqlanmadi. Qayta kiring." }, 401);
  }

  const actorProfile = await getProfile(authData.user.id);
  if (
    !actorProfile ||
    !["admin", "teacher"].includes(String(actorProfile.role ?? ""))
  ) {
    return json({ error: "Bu amal uchun ruxsat yo‘q." }, 403);
  }

  const body = await request.json();
  const messageId = String(body.messageId ?? "").trim();
  if (!messageId) {
    return json({ error: "Xabar ID topilmadi." }, 400);
  }

  const { data: inboxMessage, error: inboxError } = await admin
    .from("admin_inbox_messages")
    .select(
      "id, source, sender_user_id, sender_name, sender_phone, telegram_chat_id, subject, body, is_read, admin_seen_notified_at",
    )
    .eq("id", messageId)
    .maybeSingle();

  if (inboxError || !inboxMessage) {
    return json({ error: "Xabar topilmadi." }, 404);
  }

  await admin
    .from("admin_inbox_messages")
    .update({
      is_read: true,
      admin_read_at: new Date().toISOString(),
    })
    .eq("id", messageId);

  if (
    !inboxMessage.is_read &&
    inboxMessage.source === "telegram" &&
    !inboxMessage.admin_seen_notified_at
  ) {
    const chatId =
      inboxMessage.telegram_chat_id ||
      (inboxMessage.sender_user_id
        ? (await getProfile(inboxMessage.sender_user_id))?.telegram_chat_id
        : null) ||
      (inboxMessage.sender_phone
        ? (await getProfileByPhone(inboxMessage.sender_phone))?.telegram_chat_id
        : null) ||
      (await getRecentTelegramChatId({
        senderUserId: inboxMessage.sender_user_id,
        senderPhone: inboxMessage.sender_phone,
        senderName: inboxMessage.sender_name,
      }));

    if (chatId) {
      await telegram("sendMessage", {
        chat_id: chatId,
        text: "Administrator xabaringizni ko‘rdi.",
      });
      await admin
        .from("admin_inbox_messages")
        .update({ admin_seen_notified_at: new Date().toISOString() })
        .eq("id", messageId);
    }
  } else if (
    !inboxMessage.is_read &&
    inboxMessage.source === "student_app" &&
    inboxMessage.sender_user_id
  ) {
    await admin.from("notifications").insert({
      title: "Admin xabaringizni ko‘rdi",
      body: inboxMessage.subject
        ? `“${inboxMessage.subject}” bo‘yicha yuborgan xabaringiz ko‘rildi.`
        : "Yuborgan xabaringiz administrator tomonidan ko‘rildi.",
      target_role: "student",
      target_user_id: inboxMessage.sender_user_id,
      deep_link: "/profile",
      created_by: authData.user.id,
    });
  }

  return json({ ok: true });
}

async function markNotificationRead(request: Request) {
  const accessToken = request.headers
    .get("Authorization")
    ?.replace("Bearer ", "")
    .trim();
  if (!accessToken) {
    return json({ error: "Sessiya topilmadi. Qayta kiring." }, 401);
  }

  const { data: authData, error: authError } =
    await admin.auth.getUser(accessToken);
  if (authError || !authData.user) {
    return json({ error: "Sessiya tasdiqlanmadi. Qayta kiring." }, 401);
  }

  const body = await request.json();
  const notificationId = String(body.notificationId ?? "").trim();
  if (!notificationId) {
    return json({ error: "Xabarnoma ID topilmadi." }, 400);
  }

  const { data: notification, error: notificationError } = await admin
    .from("notifications")
    .select("id, target_user_id, reply_to_inbox_message_id")
    .eq("id", notificationId)
    .maybeSingle();

  if (notificationError || !notification) {
    return json({ error: "Xabarnoma topilmadi." }, 404);
  }

  if (
    notification.target_user_id &&
    notification.target_user_id !== authData.user.id
  ) {
    return json({ error: "Bu xabarnomani belgilashga ruxsat yo‘q." }, 403);
  }

  await admin.from("notification_reads").upsert({
    notification_id: notificationId,
    user_id: authData.user.id,
    read_at: new Date().toISOString(),
  });

  if (notification.reply_to_inbox_message_id) {
    await admin
      .from("admin_inbox_messages")
      .update({ recipient_read_at: new Date().toISOString() })
      .eq("id", notification.reply_to_inbox_message_id)
      .is("recipient_read_at", null);
  }

  return json({ ok: true });
}

function telegramSenderName(from?: {
  first_name?: string;
  last_name?: string;
  username?: string;
}) {
  const fullName = `${from?.first_name ?? ""} ${from?.last_name ?? ""}`.trim();
  if (fullName) return fullName;
  if (from?.username) return `@${from.username}`;
  return "Telegram foydalanuvchisi";
}

async function getProfile(userId: string) {
  if (!userId) return null;

  const { data } = await admin
    .from("profiles")
    .select(
      "full_name, phone, role, avatar_url, gender, age, region, district, mahalla, street, telegram_chat_id, telegram_user_id, telegram_username, telegram_last_seen_at",
    )
    .eq("id", userId)
    .maybeSingle();

  return data;
}

async function telegram(method: string, payload: Record<string, unknown>) {
  const response = await fetch(
    `https://api.telegram.org/bot${telegramToken}/${method}`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    },
  );

  return await response.json();
}

function normalizePhone(value: string) {
  const digits = value.replace(/\D/g, "");
  if (digits.startsWith("998")) return `+${digits}`;
  return `+998${digits}`;
}

function phoneAuthEmail(phone: string) {
  return `${phone.replace(/\D/g, "")}@phone.labproof.local`;
}

function namesMatch(appName: string, telegramName: string) {
  return normalizeName(appName) === normalizeName(telegramName);
}

function normalizeName(value: string) {
  return value
    .toLowerCase()
    .replace(/[’‘`']/g, "'")
    .replace(/[^a-zа-яёғқўҳ0-9'\s-]/giu, "")
    .replace(/\s+/g, " ")
    .trim();
}

function json(payload: unknown, status = 200) {
  return new Response(JSON.stringify(payload), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}
