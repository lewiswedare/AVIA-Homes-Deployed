import { MailCheck } from "lucide-react";
import { useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";

import { FieldError, FieldLabel, PrimaryButton, inputClass } from "@/components/avia/ui";
import { supabase } from "@/lib/supabase";
import { signUpSchema, validate, type FieldErrors } from "@/lib/validation";

export default function SignUp() {
  const navigate = useNavigate();
  const [firstName, setFirstName] = useState<string>("");
  const [lastName, setLastName] = useState<string>("");
  const [phone, setPhone] = useState<string>("");
  const [email, setEmail] = useState<string>("");
  const [password, setPassword] = useState<string>("");
  const [confirm, setConfirm] = useState<string>("");
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [loading, setLoading] = useState<boolean>(false);
  const [awaitingConfirmation, setAwaitingConfirmation] = useState<boolean>(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    const checked = validate(signUpSchema, { firstName, lastName, phone, email, password, confirm });
    setFieldErrors(checked.errors ?? {});
    if (!checked.data) return;
    setLoading(true);
    try {
      const { data, error: authError } = await supabase.auth.signUp({
        email: checked.data.email,
        password: checked.data.password,
        options: {
          data: {
            first_name: checked.data.firstName,
            last_name: checked.data.lastName,
            phone: checked.data.phone,
          },
        },
      });
      if (authError) {
        const m = authError.message.toLowerCase();
        setError(
          m.includes("already")
            ? "An account with this email already exists."
            : "Something went wrong. Please try again.",
        );
        return;
      }
      if (!data.session) {
        // Email confirmation is enabled — no session yet. Navigating into the
        // app now would bounce straight back to /login with no explanation.
        setAwaitingConfirmation(true);
        return;
      }
      navigate("/", { replace: true });
    } catch (e) {
      console.error(`[SignUp] sign up threw: ${e instanceof Error ? e.message : String(e)}`);
      setError("Network error. Please check your connection.");
    } finally {
      setLoading(false);
    }
  };

  if (awaitingConfirmation) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-avia-white px-6 py-10">
        <div className="w-full max-w-md text-center">
          <img src="/brand/avia-logo.png" alt="AVIA Homes" className="mx-auto mb-10 h-8 w-auto" />
          <div className="mx-auto mb-6 flex h-14 w-14 items-center justify-center rounded-full bg-avia-brown/10">
            <MailCheck className="h-7 w-7 text-avia-brown" />
          </div>
          <h1 className="mb-2 text-[24px] font-medium text-avia-black">Confirm your email</h1>
          <p className="mb-8 text-[14px] leading-relaxed text-avia-black/55">
            We&apos;ve sent a confirmation link to <span className="font-medium text-avia-black">{email}</span>.
            Open it to activate your account, then sign in.
          </p>
          <Link
            to="/login"
            className="inline-block rounded-full bg-avia-black px-8 py-3 text-[14px] font-medium text-white"
          >
            Go to Sign In
          </Link>
        </div>
      </div>
    );
  }

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
              <FieldError message={fieldErrors.firstName} />
            </div>
            <div className="space-y-1.5">
              <FieldLabel>Last name</FieldLabel>
              <input value={lastName} onChange={(e) => setLastName(e.target.value)} className={inputClass} placeholder="Last name" />
              <FieldError message={fieldErrors.lastName} />
            </div>
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Phone</FieldLabel>
            <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} placeholder="Phone (optional)" />
            <FieldError message={fieldErrors.phone} />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Email</FieldLabel>
            <input type="email" autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} className={inputClass} placeholder="Email" />
            <FieldError message={fieldErrors.email} />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Password</FieldLabel>
            <input type="password" autoComplete="new-password" value={password} onChange={(e) => setPassword(e.target.value)} className={inputClass} placeholder="At least 8 characters" />
            <FieldError message={fieldErrors.password} />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Confirm password</FieldLabel>
            <input type="password" autoComplete="new-password" value={confirm} onChange={(e) => setConfirm(e.target.value)} className={inputClass} placeholder="Re-enter your password" />
            <FieldError message={fieldErrors.confirm} />
          </div>

          {error && (
            <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">{error}</div>
          )}

          <p className="text-[12px] leading-relaxed text-avia-black/45">
            By creating an account you agree to the{" "}
            <Link to="/terms" className="font-medium text-avia-brown hover:underline">Terms of Service</Link>{" "}
            and{" "}
            <Link to="/privacy" className="font-medium text-avia-brown hover:underline">Privacy Policy</Link>.
          </p>

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
