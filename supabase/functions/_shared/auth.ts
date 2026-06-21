// Lean auth helpers for edge functions. No generated DB types — kept dependency-light.
// Import style matches functions/deno.json (`@supabase/supabase-js` -> jsr).
import { createClient } from "@supabase/supabase-js";

export interface ErrorResponse {
  error: string;
  status: number;
}

/**
 * Reads the request's Authorization header, builds a user-scoped Supabase client,
 * and resolves the authenticated user. Throws `{ status: 401, error }` when the
 * header is missing or the token is invalid.
 */
export async function getAuthenticatedUser(req: Request) {
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) {
    throw {
      error: "Missing Authorization header. You must be logged in.",
      status: 401,
    } as ErrorResponse;
  }

  const userClient = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: { Authorization: authHeader },
      },
    },
  );

  const {
    data: { user },
    error,
  } = await userClient.auth.getUser();

  if (error || !user) {
    throw {
      error: "Invalid authentication token.",
      status: 401,
    } as ErrorResponse;
  }

  return { user, userClient };
}

/** Service-role client for privileged operations (bypasses RLS). */
export function serviceClient() {
  return createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
  );
}
