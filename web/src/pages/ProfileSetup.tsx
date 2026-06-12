import { useState, type FormEvent } from "react";

import { FieldError, FieldLabel, PrimaryButton, inputClass } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { supabase } from "@/lib/supabase";
import { profileSchema, validate, type FieldErrors } from "@/lib/validation";

/** Shown after sign-up until the profile row is completed (mirrors iOS ProfileSetupView). */
export default function ProfileSetup() {
  const { userId, session, profile, refreshProfile } = useAuth();
  const [firstName, setFirstName] = useState<string>(profile?.first_name ?? "");
  const [lastName, setLastName] = useState<string>(profile?.last_name ?? "");
  const [phone, setPhone] = useState<string>(profile?.phone ?? "");
  const [address, setAddress] = useState<string>(profile?.address ?? "");
  const [error, setError] = useState<string | null>(null);
  const [fieldErrors, setFieldErrors] = useState<FieldErrors>({});
  const [loading, setLoading] = useState<boolean>(false);

  const submit = async (e: FormEvent) => {
    e.preventDefault();
    if (!userId) return;
    setError(null);
    const checked = validate(profileSchema, { firstName, lastName, phone, address });
    setFieldErrors(checked.errors ?? {});
    if (!checked.data) return;
    setLoading(true);
    const email = session?.user?.email ?? profile?.email ?? "";
    // Only the columns this screen actually owns — never role, assignments,
    // home design or contract date. On conflict the upsert touches just these,
    // so an existing profile row can no longer be clobbered with defaults.
    const payload = {
      id: userId,
      first_name: checked.data.firstName,
      last_name: checked.data.lastName,
      email,
      phone: checked.data.phone,
      address: checked.data.address,
      profile_completed: true,
    };
    try {
      const { error: upsertError } = await supabase.from("profiles").upsert(payload, { onConflict: "id" });
      if (upsertError) {
        console.error(`[ProfileSetup] upsert failed: ${upsertError.message}`);
        setError("Could not save your profile. Please try again.");
        return;
      }
      await refreshProfile();
    } catch (e) {
      console.error(`[ProfileSetup] save threw: ${e instanceof Error ? e.message : String(e)}`);
      setError("Network error. Please check your connection.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="flex min-h-screen items-center justify-center bg-avia-white px-6 py-10">
      <div className="w-full max-w-md">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="mb-10 h-8 w-auto" />
        <h1 className="mb-1 text-[26px] font-medium text-avia-black">Complete your profile</h1>
        <p className="mb-8 text-[14px] text-avia-black/55">
          Tell us a little about yourself so your team knows who you are.
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
            <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} placeholder="Phone" />
            <FieldError message={fieldErrors.phone} />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Address</FieldLabel>
            <input value={address} onChange={(e) => setAddress(e.target.value)} className={inputClass} placeholder="Address (optional)" />
          </div>

          {error && (
            <div className="rounded-[10px] bg-avia-black/5 px-4 py-3 text-[13px] text-avia-black/80">{error}</div>
          )}

          <PrimaryButton type="submit" disabled={!firstName.trim() || !lastName.trim()} loading={loading}>
            Continue
          </PrimaryButton>
        </form>
      </div>
    </div>
  );
}
