import type { Session } from "@supabase/supabase-js";
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

import { supabase } from "@/lib/supabase";
import type { ProfileRow, UserRole } from "@/lib/types";

interface AuthContextValue {
  session: Session | null;
  userId: string | null;
  profile: ProfileRow | null;
  role: UserRole;
  /** True while the persisted session is being restored on first load. */
  restoring: boolean;
  /** True while the profile row is being fetched after sign-in. */
  profileLoading: boolean;
  /** True when the last profile fetch FAILED (network/server error) — distinct
   * from a missing row. Gates must not treat this as "needs profile setup". */
  profileError: boolean;
  refreshProfile: () => Promise<void>;
  signOut: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [restoring, setRestoring] = useState<boolean>(true);
  const [profile, setProfile] = useState<ProfileRow | null>(null);
  const [profileLoading, setProfileLoading] = useState<boolean>(false);
  const [profileError, setProfileError] = useState<boolean>(false);

  useEffect(() => {
    let mounted = true;
    supabase.auth
      .getSession()
      .then(({ data }) => {
        if (!mounted) return;
        setSession(data.session);
        setRestoring(false);
      })
      .catch(() => {
        if (mounted) setRestoring(false);
      });

    const { data: listener } = supabase.auth.onAuthStateChange((_event, newSession) => {
      setSession(newSession);
    });
    return () => {
      mounted = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  const userId = session?.user?.id?.toLowerCase() ?? null;

  const refreshProfile = useCallback(async (): Promise<void> => {
    if (!userId) {
      setProfile(null);
      return;
    }
    setProfileLoading(true);
    try {
      const { data, error } = await supabase
        .from("profiles")
        .select("*")
        .eq("id", userId)
        .maybeSingle();
      if (error) {
        // Transient failure: KEEP any profile we already have — overwriting it
        // with null previously routed existing users into ProfileSetup, which
        // could then clobber their real profile row.
        console.error(`[Auth] fetch profile failed: ${error.message}`);
        setProfileError(true);
      } else {
        setProfile((data as ProfileRow | null) ?? null);
        setProfileError(false);
      }
    } catch (e) {
      console.error(`[Auth] fetch profile threw: ${e instanceof Error ? e.message : String(e)}`);
      setProfileError(true);
    } finally {
      setProfileLoading(false);
    }
  }, [userId]);

  useEffect(() => {
    if (userId) {
      setProfileLoading(true);
      void refreshProfile();
    } else {
      setProfile(null);
      setProfileError(false);
    }
  }, [userId, refreshProfile]);

  const signOut = useCallback(async (): Promise<void> => {
    setProfile(null);
    try {
      await supabase.auth.signOut();
    } catch (e) {
      console.error(`[Auth] sign out failed: ${e instanceof Error ? e.message : String(e)}`);
    }
  }, []);

  const role: UserRole = (profile?.role as UserRole | undefined) ?? "Client";

  const value = useMemo<AuthContextValue>(
    () => ({ session, userId, profile, role, restoring, profileLoading, profileError, refreshProfile, signOut }),
    [session, userId, profile, role, restoring, profileLoading, profileError, refreshProfile, signOut],
  );

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used within AuthProvider");
  return ctx;
}
