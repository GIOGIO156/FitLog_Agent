-- The clarification progress signature uses pgcrypto.digest, which Supabase
-- installs in the extensions schema. Keep the SECURITY DEFINER function's
-- search path explicit so fresh and already-migrated projects resolve it.
alter function public.record_ai_chat_turn_v2(
  uuid, uuid, text, text, text, text, text, text, text, text,
  text, integer, integer, text, jsonb, integer, uuid, text, jsonb, boolean
) set search_path = public, extensions;
