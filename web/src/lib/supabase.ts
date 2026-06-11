import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const supabaseUrl: string =
  import.meta.env.EXPO_PUBLIC_SUPABASE_URL ?? import.meta.env.VITE_SUPABASE_URL ?? "";
const supabaseAnonKey: string =
  import.meta.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? import.meta.env.VITE_SUPABASE_ANON_KEY ?? "";

export const isSupabaseConfigured: boolean = supabaseUrl.length > 0 && supabaseAnonKey.length > 0;

/** Shared Supabase client connecting the web app to the same backend as the iOS app. */
export const supabase: SupabaseClient = createClient(supabaseUrl, supabaseAnonKey, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
  },
});
