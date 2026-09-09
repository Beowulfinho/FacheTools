// Supabase Edge Function: notify-household-planes
//
// Planes' counterpart to notify-household (Financas). Triggered by a pg_net webhook on INSERT
// into `planes_comentarios` (see the notify_household_on_comentario trigger /
// trigger_notify_household_planes() from the device_tokens_add_app_and_planes_notify_trigger
// migration). Looks up who else shares a household with the comment's author, fetches their
// Planes-app device tokens (device_tokens.app = 'planes' — a phone with both Financas and Planes
// installed must only get pinged by the app the change actually happened in), and pushes via
// FCM's HTTP v1 API on Planes' own notification channel ("planes_alerts", see
// ensureNotificationChannel in Planes/index.html) so it shows with Planes' icon/color, not
// Financas'.
//
// Required secrets (same Firebase project as notify-household, already set):
//   FCM_SERVICE_ACCOUNT   — full JSON of a Firebase service account key.
//   WEBHOOK_SHARED_SECRET — matched against x-webhook-secret; verify_jwt is off since a pg_net
//                           trigger calls this directly, not the Dashboard's Database Webhooks UI.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const FCM_PROJECT_ID = "financas-fachetools";

function messageForRow(table: string, record: Record<string, unknown>): { title: string; body: string } {
  const texto = (record.texto as string) || "";
  if (table === "planes_comentarios") {
    return { title: "Novo comentário no plano", body: texto };
  }
  return { title: "Novidade no plano", body: texto };
}

Deno.serve(async (req: Request) => {
  try {
    const expectedSecret = Deno.env.get("WEBHOOK_SHARED_SECRET");
    if (!expectedSecret || req.headers.get("x-webhook-secret") !== expectedSecret) {
      return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401 });
    }

    const payload = await req.json();
    const table = payload.table as string;
    const record = payload.record as Record<string, unknown>;
    const actorUserId = record?.user_id as string | undefined;
    if (!actorUserId) {
      return new Response(JSON.stringify({ skipped: "no user_id on record" }), { status: 200 });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    // Who else shares a household with the person who just added this row.
    const { data: myMembership } = await admin
      .from("household_members")
      .select("household_id")
      .eq("user_id", actorUserId)
      .maybeSingle();
    if (!myMembership) {
      return new Response(JSON.stringify({ skipped: "actor has no household" }), { status: 200 });
    }
    const { data: otherMembers } = await admin
      .from("household_members")
      .select("user_id")
      .eq("household_id", myMembership.household_id)
      .neq("user_id", actorUserId);
    const otherUserIds = (otherMembers || []).map((m) => m.user_id as string);
    if (otherUserIds.length === 0) {
      return new Response(JSON.stringify({ skipped: "no other household members" }), { status: 200 });
    }

    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .eq("app", "planes")
      .in("user_id", otherUserIds);
    if (!tokens || tokens.length === 0) {
      return new Response(JSON.stringify({ skipped: "no device tokens for other members" }), { status: 200 });
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
    const accessTokenResponse = await client.getAccessToken();
    const accessToken = accessTokenResponse.token;

    const { title, body } = messageForRow(table, record);
    const results = await Promise.all(
      tokens.map(async (row) => {
        const res = await fetch(
          `https://fcm.googleapis.com/v1/projects/${FCM_PROJECT_ID}/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: row.token,
                notification: { title, body },
                android: { notification: { channel_id: "planes_alerts" } },
              },
            }),
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
