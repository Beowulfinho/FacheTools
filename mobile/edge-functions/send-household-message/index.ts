// Supabase Edge Function: send-household-message
//
// Called directly from the Financas client (Configuracoes > Notificacoes) — not by a database
// trigger like notify-household. The caller's own Supabase session authenticates the request
// (verify_jwt is on), so this only has to figure out who *else* shares that caller's household
// and push a free-text message to their device(s) via Firebase Cloud Messaging.
//
// Required secret (already set for notify-household, reused here):
//   FCM_SERVICE_ACCOUNT — full JSON of a Firebase service account key.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const FCM_PROJECT_ID = "financas-fachetools";

Deno.serve(async (req: Request) => {
  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "missing Authorization header" }), { status: 401 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

    // Client scoped to the caller's own token, purely to resolve who is calling.
    const callerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const { data: userData, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userData?.user) {
      return new Response(JSON.stringify({ error: "invalid session" }), { status: 401 });
    }
    const actorUserId = userData.user.id;

    const { title, body, includeSelf } = await req.json();
    if (!body || typeof body !== "string") {
      return new Response(JSON.stringify({ error: "body (message text) is required" }), { status: 400 });
    }

    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: myMembership } = await admin
      .from("household_members")
      .select("household_id")
      .eq("user_id", actorUserId)
      .maybeSingle();
    if (!myMembership) {
      return new Response(JSON.stringify({ sent: [], skipped: "actor has no household" }), { status: 200 });
    }
    const { data: otherMembers } = await admin
      .from("household_members")
      .select("user_id")
      .eq("household_id", myMembership.household_id)
      .neq("user_id", actorUserId);
    const targetUserIds = (otherMembers || []).map((m) => m.user_id as string);
    if (includeSelf) targetUserIds.push(actorUserId);
    if (targetUserIds.length === 0) {
      return new Response(JSON.stringify({ sent: [], skipped: "no other household members" }), { status: 200 });
    }

    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .in("user_id", targetUserIds);
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ sent: [], skipped: "no device tokens for other members" }), { status: 200 });
    }

    const serviceAccountJson = Deno.env.get("FCM_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      return new Response(JSON.stringify({ error: "FCM_SERVICE_ACCOUNT secret not set" }), { status: 500 });
    }
    const serviceAccount = JSON.parse(serviceAccountJson);
    const auth = new GoogleAuth({
      credentials: serviceAccount,
      scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
    });
    const client = await auth.getClient();
    const accessToken = (await client.getAccessToken()).token;

    const finalTitle = (title && String(title).trim()) || "Mensagem";
    const results = await Promise.all(
      tokens.map(async (row) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
            body: JSON.stringify({ message: { token: row.token, notification: { title: finalTitle, body } } }),
          },
        );
        return { token: row.token, ok: res.ok, status: res.status };
      }),
    );

    return new Response(JSON.stringify({ sent: results }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
