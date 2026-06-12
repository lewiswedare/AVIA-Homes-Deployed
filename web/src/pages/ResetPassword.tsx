import { useEffect, useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";

import { FieldError, FieldLabel, PrimaryButton, inputClass } from "@/components/avia/ui";
import { supabase } from "@/lib/supabase";
import { resetPasswordSchema, validate, type FieldErrors } from "@/lib/validation";

/**
 * Landing page for the password-recovery email link. Supabase puts a recovery
 * session in the URL hash; once detected the user can set a new password.
 */
export default function ResetPassword() {
  const navigate = useNavigate();
  const [hasRecoverySession, setHasRecoverySession] = useState<boolean | null>(null);
  const [password, setPassword] = useState<string>("");
  const [confirm, setConfirm] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [loading, setLoading] = useState<boolean>(false);
  const [done, setDone] = useState<boolean>(false);

  useEffect(() => {
    let mounted = true;

    // The recovery link signs the user in via the URL hash; give the client a
    // moment to process it, then check for a session.
    const check = async () => {
      const { data } = await supabase.auth.getSession();
      if (mounted) setHasRecoverySession(!!data.session);
    };

    const { data: listener } = supabase.auth.onAuthStateChange((event, session) => {
      if (!mounted) return;
      if (event === "PASSWORD_RECOVERY" || session) setHasRecoverySession(true);
    });

    void check();
    return () => {
      mounted = false;
      listener.subscription.unsubscribe();
    };
  }, []);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    const checked = validate(resetPasswordSchema, { password, confirm });
    setFieldErrors(checked.errors ?? {});
    if (!checked.data) return;
    setLoading(true);
    try {
      const { error: updateError } = await supabase.auth.updateUser({ password });
      if (updateError) {
        console.error(`[ResetPassword] update failed: ${updateError.message}`);
        setError("Couldn't update your password. The link may have expired — request a new one.");
        return;
      }
      setDone(true);
      setTimeout(() => navigate("/", { replace: true }), 1500);
    } catch (e) {
      console.error(`[ResetPassword] update threw: ${e instanceof Error ? e.message : String(e)}`);
      setError("Network error. Please check your connection.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-avia-white px-6">
      <div className="w-full max-w-md">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="mb-10 h-8 w-auto" />
        <h1 className="mb-1 text-[26px] font-medium text-avia-black">Set a new password</h1>

        {done ? (
          <div className="mt-8 rounded-[13px] bg-avia-card p-5 text-[14px] text-avia-black">
            Password updated — taking you to your dashboard…
          </div>
        ) : hasRecoverySession === false ? (
          <div className="mt-8 space-y-5">
            <div className="rounded-[13px] bg-avia-card p-5 text-[14px] text-avia-black">
              This reset link is invalid or has expired.
            </div>
            <p className="text-center text-[14px]">
              <Link to="/forgot-password" className="font-medium text-avia-brown hover:underline">
                Request a new reset link
              </Link>
            </p>
          </div>
        ) : (
          <>
            <p className="mb-8 text-[14px] text-avia-black/55">Choose a new password for your account.</p>
            <form onSubmit={(e) => void submit(e)} className="space-y-4">
              <div className="space-y-1.5">
                <FieldLabel>New password</FieldLabel>
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className={inputClass}
                  placeholder="At least 8 characters"
                  autoComplete="new-password"
                />
                <FieldError message={fieldErrors.password} />
              </div>
              <div className="space-y-1.5">
                <FieldLabel>Confirm password</FieldLabel>
                <input
                  type="password"
                  value={confirm}
                  onChange={(e) => setConfirm(e.target.value)}
                  className={inputClass}
                  placeholder="Repeat the new password"
                  autoComplete="new-password"
                />
                <FieldError message={fieldErrors.confirm} />
              </div>
              {error && (
                <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">{error}</div>
              )}
              <PrimaryButton type="submit" disabled={!password || !confirm} loading={loading}>
                Update Password
              </PrimaryButton>
            </form>
          </>
        )}
      </div>
    </div>
  );
}
