// Shared CORS headers for browser-invoked edge functions.
// Import from any function: `import { corsHeaders } from "../_shared/cors.ts";`
export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
} as const;
