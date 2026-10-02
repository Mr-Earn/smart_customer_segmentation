import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const publishableKey = Deno.env.get("SUPABASE_ANON_KEY") ?? Deno.env.get("SUPABASE_PUBLISHABLE_KEY");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    return json({ error: "Function is not configured." }, 500);
  }

  const authHeader = request.headers.get("Authorization");
  if (!authHeader) return json({ error: "Missing authorization." }, 401);

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) return json({ error: "Unauthorized." }, 401);

  const adminClient = createClient(supabaseUrl, serviceRoleKey);
  const { data: profile, error: profileError } = await adminClient
    .from("profiles")
    .select("role")
    .eq("id", authData.user.id)
    .single();
  if (profileError || profile?.role !== "admin") {
    return json({ error: "Admin role required." }, 403);
  }

  const payload = await request.json();
  if (payload.action === "invite") {
    const email = String(payload.email ?? "").trim().toLowerCase();
    const fullName = String(payload.full_name ?? "").trim();
    const role = String(payload.role ?? "analyst");
    if (!email || !fullName || !["admin", "analyst", "marketing", "customer"].includes(role)) {
      return json({ error: "Invalid invite payload." }, 400);
    }

    const { data, error } = await adminClient.auth.admin.inviteUserByEmail(email, {
      data: { full_name: fullName },
    });
    if (error || !data.user) return json({ error: error?.message ?? "Invite failed." }, 400);

    const { error: roleError } = await adminClient
      .from("profiles")
      .update({ email, full_name: fullName, role })
      .eq("id", data.user.id);
    if (roleError) return json({ error: roleError.message }, 400);
    return json({ id: data.user.id });
  }

  if (payload.action === "delete") {
    const userId = String(payload.user_id ?? "");
    if (!userId || userId === authData.user.id) return json({ error: "Invalid user ID." }, 400);
    const { error } = await adminClient.auth.admin.deleteUser(userId);
    if (error) return json({ error: error.message }, 400);
    return json({ ok: true });
  }

  return json({ error: "Unknown action." }, 400);
});
