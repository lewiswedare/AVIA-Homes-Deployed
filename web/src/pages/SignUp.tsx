import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";

import { FieldLabel, PrimaryButton, inputClass } from "@/components/avia/ui";
import { supabase } from "@/lib/supabase";

export default function SignUp() {
  const navigate = useNavigate();
  const [firstName, setFirstName] = useState<string>("");
  const [lastName, setLastName] = useState<string>("");
  const [phone, setPhone] = useState<string>("");
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [confirm, setConfirm] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState<boolean>(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    if (!email.includes("@") || !email.includes(".")) {
      setError("Please enter a valid email address.");
      return;
    }
    if (password.length < 6) {
      setError("Password must be at least 6 characters.");
      return;
    }
    if (password !== confirm) {
      setError("Passwords do not match.");
      return;
    }
    setLoading(true);
    const { error: authError } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          first_name: firstName,
          last_name: lastName,
          phone,
        },
      },
    });
    setLoading(false);
    if (authError) {
      const m = authError.message.toLowerCase();
      setError(
        m.includes("already")
          ? "An account with this email already exists."
          : "Something went wrong. Please try again.",
      );
      return;
    }
    navigate("/", { replace: true });
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-avia-white px-6 py-10">
      <div className="w-full max-w-md">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="mb-10 h-8 w-auto" />
        <h1 className="mb-1 text-[26px] font-medium text-avia-black">Create your account</h1>
        <p className="mb-8 text-[14px] text-avia-black/55">
          Start your journey with AVIA Homes.
        </p>

        <form onSubmit={(e) => void submit(e)} className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div className="space-y-1.5">
              <FieldLabel>First name</FieldLabel>
              <input value={firstName} onChange={(e) => setFirstName(e.target.value)} className={inputClass} placeholder="First name" />
            </div>
            <div className="space-y-1.5">
              <FieldLabel>Last name</FieldLabel>
              <input value={lastName} onChange={(e) => setLastName(e.target.value)} className={inputClass} placeholder="Last name" />
            </div>
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Phone</FieldLabel>
            <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} placeholder="Phone (optional)" />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Email</FieldLabel>
            <input type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} className={inputClass} placeholder="Email" />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Password</FieldLabel>
            <input type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} className={inputClass} placeholder="At least 6 characters" />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Confirm password</FieldLabel>
            <input type="password" autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} className={inputClass} placeholder="Re-enter your password" />
          </div>

          {error && (
            <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">{error}</div>
          )}

          <PrimaryButton type="submit" disabled={!email || !password || !confirm} loading={loading}>
            Create Account
          </PrimaryButton>
        </form>

        <p className="mt-6 text-center text-[14px] text-avia-black/55">
          Already have an account?{" "}
          <Link to="/login" className="font-medium text-avia-brown hover:underline">
            Sign In
          </Link>
        </p>
      </div>
    </div>
  );
}
