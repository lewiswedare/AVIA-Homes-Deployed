import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";

import { FieldLabel, PrimaryButton, inputClass } from "@/components/avia/ui";
import { supabase } from "@/lib/supabase";

export default function ForgotPassword() {
  const [email, setEmail] = useState<string>("");
  const [sent, setSent] = useState<boolean>(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!email.includes("@")) {
      setError("Please enter a valid email address.");
      return;
    }
    setLoading(true);
    try {
      const { error: authError } = await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/reset-password`,
      });
      if (authError) {
        setError("Something went wrong. Please try again.");
        return;
      }
      setSent(true);
    } catch (e) {
      console.error(`[ForgotPassword] reset threw: ${e instanceof Error ? e.message : String(e)}`);
      setError("Network error. Please check your connection.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-avia-white px-6">
      <div className="w-full max-w-md">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="mb-10 h-8 w-auto" />
        <h1 className="mb-1 text-[26px] font-medium text-avia-black">Reset password</h1>
        <p className="mb-8 text-[14px] text-avia-black/55">
          Enter the email for your account and we&apos;ll send you a reset link.
        </p>

        {sent ? (
          <div className="rounded-[13px] bg-avia-card p-5 text-[14px] text-avia-black">
            Check your inbox — a password reset link is on its way to <strong>{email}</strong>.
          </div>
        ) : (
          <form onSubmit={(e) => void submit(e)} className="space-y-4">
            <div className="space-y-1.5">
              <FieldLabel>Email</FieldLabel>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className={inputClass}
                placeholder="Email"
              />
            </div>
            {error && (
              <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">{error}</div>
            )}
            <PrimaryButton type="submit" disabled={!email} loading={loading}>
              Send Reset Link
            </PrimaryButton>
          </form>
        )}

        <p className="mt-6 text-center text-[14px]">
          <Link to="/login" className="font-medium text-avia-brown hover:underline">
            Back to Sign In
          </Link>
        </p>
      </div>
    </div>
  );
}
