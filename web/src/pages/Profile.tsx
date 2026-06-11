import { Globe, LogOut, Phone } from "lucide-react";
import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { toast } from "sonner";

import { BentoCard, FieldLabel, InitialsAvatar, PrimaryButton, StatusPill, inputClass } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { initialsOf } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import { roleDescription } from "@/lib/types";

export default function Profile() {
  const { profile, role, userId, refreshProfile, signOut } = useAuth();
  const navigate = useNavigate();
  const [firstName, setFirstName] = useState<string>(profile?.first_name ?? "");
  const [lastName, setLastName] = useState<string>(profile?.last_name ?? "");
  const [phone, setPhone] = useState<string>(profile?.phone ?? "");
  const [saving, setSaving] = useState<boolean>(false);

  const save = async () => {
    if (!userId) return;
    setSaving(true);
    const { error } = await supabase
      .from("profiles")
      .update({ first_name: firstName.trim(), last_name: lastName.trim(), phone: phone.trim() })
      .eq("id", userId);
    setSaving(false);
    if (error) {
      toast.error("Could not save your profile.");
      return;
    }
    await refreshProfile();
    toast.success("Profile saved");
  };

  return (
    <div className="space-y-5">
      <h1 className="text-[28px] font-medium text-avia-black">Profile &amp; Settings</h1>

      <BentoCard className="flex items-center gap-4 p-5">
        <InitialsAvatar initials={initialsOf(profile?.first_name, profile?.last_name)} className="h-14 w-14 text-[16px]" />
        <div className="min-w-0 flex-1">
          <div className="text-[18px] font-medium text-avia-black">
            {`${profile?.first_name ?? ""} ${profile?.last_name ?? ""}`.trim() || profile?.email}
          </div>
          <div className="text-[13px] text-avia-black/55">{profile?.email}</div>
          <div className="mt-1 text-[12px] text-avia-black/45">{roleDescription[role]}</div>
        </div>
        <StatusPill label={role} tone="brown" />
      </BentoCard>

      <BentoCard className="space-y-4 p-5">
        <div className="text-[14px] font-medium text-avia-black">Your details</div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <FieldLabel>First name</FieldLabel>
            <input value={firstName} onChange={(e) => setFirstName(e.target.value)} className={inputClass} />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Last name</FieldLabel>
            <input value={lastName} onChange={(e) => setLastName(e.target.value)} className={inputClass} />
          </div>
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Phone</FieldLabel>
          <input type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} />
        </div>
        <PrimaryButton onClick={() => void save()} loading={saving} disabled={!firstName.trim()}>
          Save Changes
        </PrimaryButton>
      </BentoCard>

      <BentoCard className="divide-y divide-avia-line">
        <a href="tel:0756545123" className="flex items-center gap-3.5 px-4 py-3.5 text-[14px] font-medium text-avia-black hover:bg-avia-black/5">
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-blue/15 text-avia-blue">
            <Phone className="h-4 w-4" />
          </span>
          Call Us
        </a>
        <a
          href="https://www.aviahomes.com.au"
          target="_blank"
          rel="noreferrer"
          className="flex items-center gap-3.5 px-4 py-3.5 text-[14px] font-medium text-avia-black hover:bg-avia-black/5"
        >
          <span className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
            <Globe className="h-4 w-4" />
          </span>
          Website
        </a>
      </BentoCard>

      <button
        type="button"
        onClick={() => {
          void signOut().then(() => navigate("/login"));
        }}
        className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[11px] border border-avia-black/20 bg-avia-black/5 text-[15px] font-medium text-avia-black/80 transition-colors hover:bg-avia-black/10"
      >
        <LogOut className="h-4 w-4" /> Sign Out
      </button>

      <div className="flex justify-center pb-4 pt-2">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-6 w-auto opacity-40" />
      </div>
    </div>
  );
}
