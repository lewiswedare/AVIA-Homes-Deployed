import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";

import { FieldLabel, PrimaryButton, SecondaryButton, inputClass } from "@/components/avia/ui";
import { supabase } from "@/lib/supabase";

function parseAuthError(message: string): string {
  const m = message.toLowerCase();
  if (m.includes("invalid") || m.includes("credentials")) return "Invalid email or password.";
  if (m.includes("network") || m.includes("connection")) return "Network error. Please check your connection.";
  if (m.includes("email") && m.includes("confirm")) return "Please check your email to confirm your account.";
  return "Something went wrong. Please try again.";
}

export default function Login() {
  const navigate = useNavigate();
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }
    setLoading(true);
    try {
      const { error: authError } = await supabase.auth.signInWithPassword({ email, password });
      if (authError) {
        setError(parseAuthError(authError.message));
        return;
      }
      navigate("/", { replace: true });
    } catch (e) {
      console.error(`[Login] sign in threw: ${e instanceof Error ? e.message : String(e)}`);
      setError("Network error. Please check your connection.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen bg-avia-white">
      {/* Hero panel */}
      <div className="relative hidden w-1/2 lg:block">
        <img
          src="/brand/signin-background.jpg"
          alt=""
          className="absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-gradient-to-t from-avia-black/60 via-transparent to-transparent" />
        <img
          src="/brand/avia-logo.png"
          alt="AVIA Homes"
          className="absolute bottom-10 left-10 h-9 w-auto brightness-0 invert"
        />
      </div>

      {/* Form */}
      <div className="flex w-full flex-col lg:w-1/2">
        {/* Mobile hero */}
        <div className="relative h-56 overflow-hidden rounded-b-[32px] sm:h-72 lg:hidden">
          <img src="/brand/signin-background.jpg" alt="" className="h-full w-full object-cover" />
          <div className="absolute inset-0 bg-gradient-to-b from-transparent via-avia-white/30 to-avia-white" />
          <img
            src="/brand/avia-logo.png"
            alt="AVIA Homes"
            className="absolute bottom-7 left-7 h-8 w-auto"
          />
        </div>

        <div className="mx-auto flex w-full max-w-md flex-1 flex-col justify-center px-7 py-10">
          <img src="/brand/avia-logo.png" alt="" className="mb-10 hidden h-8 w-auto self-start lg:block" />
          <h1 className="mb-1 text-[26px] font-medium text-avia-black">Welcome back</h1>
          <p className="mb-8 text-[14px] text-avia-black/55">Sign in to your AVIA Homes account.</p>

          <form onSubmit={(e) => void submit(e)} className="space-y-4">
            <div className="space-y-1.5">
              <FieldLabel>Email</FieldLabel>
              <input
                type="email"
                autoComplete="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder="Email"
                className={inputClass}
              />
            </div>
            <div className="space-y-1.5">
              <FieldLabel>Password</FieldLabel>
              <input
                type="password"
                autoComplete="current-password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="Enter your password"
                className={inputClass}
              />
            </div>

            {error && (
              <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">
                {error}
              </div>
            )}

            <PrimaryButton type="submit" disabled={!email || !password} loading={loading}>
              Sign In
            </PrimaryButton>
          </form>

          <Link
            to="/forgot-password"
            className="mt-5 self-center text-[14px] font-medium text-avia-brown hover:underline"
          >
            Forgot Password?
          </Link>

          <div className="my-6 flex items-center gap-4">
            <div className="h-px flex-1 bg-avia-line" />
            <span className="text-[12px] text-avia-black/35">or</span>
            <div className="h-px flex-1 bg-avia-line" />
          </div>

          <SecondaryButton onClick={() => navigate("/signup")}>Create Account</SecondaryButton>
        </div>
      </div>
    </div>
  );
}
