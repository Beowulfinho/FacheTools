// Supabase Edge Function: notify-household
//
// Triggered by a Database Webhook on INSERT into `compras` or `debito`. Looks up who else
// shares a household with the row's owner (see the `households`/`household_members` tables and
// `is_household_member()` from the household_sharing_setup migration), fetches their registered
// device tokens, and pushes a real-time notification to each one via Firebase Cloud Messaging's
// HTTP v1 API.
//
// Required secrets (set via the Supabase dashboard, Edge Functions > Manage secrets):
//   FCM_SERVICE_ACCOUNT   — the full JSON content of a Firebase service account key
//                           (Firebase console > Project settings > Service accounts > Generate new private key)
//   WEBHOOK_SHARED_SECRET — an arbitrary random string, matched against the `x-webhook-secret`
//                           header. This function is called directly by a pg_net trigger (not
//                           the Dashboard's Database Webhooks UI, which needed a schema this
//                           project doesn't have set up), so verify_jwt is off and this header
//                           is the only gate — anyone without it gets a 401.
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are injected automatically by Supabase.

import { createClient } from "npm:@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const FCM_PROJECT_ID = "financas-fachetools";

function formatBRL(v: number): string {
  return new Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" }).format(v || 0);
}

function messageForRow(table: string, record: Record<string, unknown>): { title: string; body: string } {
  if (table === "compras") {
    const desc = (record.descricao as string) || (record.comerciante as string) || "Nova compra";
    const valor = formatBRL(Number(record.valor_total) || 0);
    return { title: "Novo gasto no crédito", body: `${desc} — ${valor}` };
  }
  const desc = (record.descricao as string) || "Novo lançamento";
  const valor = formatBRL(Number(record.valor) || 0);
  const sinal = record.out ? "Saída" : "Entrada";
  return { title: `${sinal} registrada`, body: `${desc} — ${valor}` };
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
