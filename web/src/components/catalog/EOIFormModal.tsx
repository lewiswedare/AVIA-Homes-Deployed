import { useMutation, useQueryClient } from "@tanstack/react-query";
import type { ReactNode } from "react";
import { useState } from "react";
import { toast } from "sonner";

import { FieldLabel, Modal, PrimaryButton, SecondaryButton, inputClass } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { notifyUsers, saveAssignment, staffAndAdminIds, withClientResponse } from "@/lib/catalog";
import { fullNameOf, nowISO, uuid } from "@/lib/format";
import { useProfiles } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type { HouseLandPackageRow, PackageAssignmentRow } from "@/lib/types";
import { RESPONSE_ACCEPTED, specTierLabel, asSpecTier } from "@/lib/types";
import { cn } from "@/lib/utils";

const STEPS = ["Property", "Buyers", "Solicitor", "Review"] as const;

const OCCUPANCY_OPTIONS: { key: string; label: string }[] = [
  { key: "investor", label: "Investor" },
  { key: "owner_occupier", label: "Owner Occupier" },
  { key: "corporate", label: "Corporate" },
];

interface EOIDraft {
  streetSuburb: string;
  occupancy: string;
  b1Name: string;
  b1Email: string;
  b1Address: string;
  b1Phone: string;
  hasBuyer2: boolean;
  b2Name: string;
  b2Email: string;
  b2Address: string;
  b2Phone: string;
  solCompany: string;
  solName: string;
  solEmail: string;
  solAddress: string;
  solPhone: string;
}

/**
 * EOI submission wizard — mirrors the iOS EOIFormView 4-step flow:
 * Property → Buyers → Solicitor → Review (with deposit payment details).
 */
export default function EOIFormModal({
  open,
  onClose,
  pkg,
  assignment,
  resubmit,
}: {
  open: boolean;
  onClose: () => void;
  pkg: HouseLandPackageRow;
  assignment: PackageAssignmentRow;
  resubmit: boolean;
}) {
  const { userId, profile } = useAuth();
  const profilesQ = useProfiles();
  const queryClient = useQueryClient();
  const [step, setStep] = useState<number>(0);
  const [draft, setDraft] = useState<EOIDraft>({
    streetSuburb: "",
    occupancy: "owner_occupier",
    b1Name: profile ? fullNameOf(profile) : "",
    b1Email: profile?.email ?? "",
    b1Address: profile?.address ?? "",
    b1Phone: profile?.phone ?? "",
    hasBuyer2: false,
    b2Name: "",
    b2Email: "",
    b2Address: "",
    b2Phone: "",
    solCompany: "",
    solName: "",
    solEmail: "",
    solAddress: "",
    solPhone: "",
  });

  const set = (patch: Partial<EOIDraft>) => setDraft((d) => ({ ...d, ...patch }));

  const stepValid = (s: number): string | null => {
    if (s === 1) {
      if (!draft.b1Name.trim() || !draft.b1Email.trim() || !draft.b1Address.trim() || !draft.b1Phone.trim())
        return "Please complete all Buyer 1 fields.";
      if (draft.hasBuyer2 && (!draft.b2Name.trim() || !draft.b2Email.trim() || !draft.b2Address.trim() || !draft.b2Phone.trim()))
        return "Please complete all Buyer 2 fields.";
    }
    if (s === 2) {
      if (!draft.solCompany.trim() || !draft.solName.trim() || !draft.solEmail.trim() || !draft.solAddress.trim() || !draft.solPhone.trim())
        return "Please complete all solicitor fields.";
    }
    return null;
  };

  const submit = useMutation({
    mutationFn: async () => {
      const uid = (userId ?? "").toLowerCase();
      const status = resubmit ? "resubmitted" : "submitted";
      const { error } = await supabase.from("eoi_submissions").insert({
        id: uuid(),
        package_assignment_id: assignment.id,
        package_id: pkg.id,
        client_id: uid,
        lot_number: pkg.lot_number,
        estate_name: pkg.location,
        street_suburb: draft.streetSuburb.trim() || null,
        occupancy_type: draft.occupancy,
        specification_tier: pkg.spec_tier,
        facade_selection: pkg.selected_facade_id,
        buyer1_name: draft.b1Name.trim(),
        buyer1_email: draft.b1Email.trim(),
        buyer1_address: draft.b1Address.trim(),
        buyer1_phone: draft.b1Phone.trim(),
        buyer2_name: draft.hasBuyer2 ? draft.b2Name.trim() : null,
        buyer2_email: draft.hasBuyer2 ? draft.b2Email.trim() : null,
        buyer2_address: draft.hasBuyer2 ? draft.b2Address.trim() : null,
        buyer2_phone: draft.hasBuyer2 ? draft.b2Phone.trim() : null,
        solicitor_company: draft.solCompany.trim(),
        solicitor_name: draft.solName.trim(),
        solicitor_email: draft.solEmail.trim(),
        solicitor_address: draft.solAddress.trim(),
        solicitor_phone: draft.solPhone.trim(),
        status,
        created_at: nowISO(),
        updated_at: nowISO(),
      });
      if (error) throw error;

      const updated = withClientResponse({ ...assignment, eoi_status: status }, uid, RESPONSE_ACCEPTED);
      await saveAssignment(updated);

      await notifyUsers({
        recipientIds: staffAndAdminIds(profilesQ.data),
        senderId: uid,
        senderName: profile ? fullNameOf(profile) : "Client",
        type: "eoi_submitted",
        title: resubmit ? "EOI Resubmitted" : "EOI Submitted",
        message: `${profile ? fullNameOf(profile) : "A client"} submitted an EOI for ${pkg.title}`,
        referenceId: pkg.id,
        referenceType: "package",
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["package_assignments"] });
      void queryClient.invalidateQueries({ queryKey: ["eoi_submissions"] });
      toast.success("EOI submitted — we'll be in touch soon");
      onClose();
    },
    onError: (err: Error) => {
      toast.error(`Couldn't submit your EOI: ${err.message}. Your details are kept — try again.`);
    },
  });

  const next = () => {
    const issue = stepValid(step);
    if (issue) {
      toast.error(issue);
      return;
    }
    if (step < STEPS.length - 1) setStep(step + 1);
  };

  return (
    <Modal open={open} onClose={onClose} title={resubmit ? "Resubmit EOI" : "Expression of Interest"}>
      <div className="flex items-center gap-1.5">
        {STEPS.map((s, i) => (
          <div key={s} className="flex flex-1 flex-col gap-1">
            <div className={cn("h-1 rounded-full", i <= step ? "bg-avia-brown" : "bg-avia-black/10")} />
            <span className={cn("text-[10px] font-medium", i === step ? "text-avia-brown" : "text-avia-black/35")}>{s}</span>
          </div>
        ))}
      </div>

      {step === 0 && (
        <div className="space-y-3">
          <ReadRow label="Lot Number" value={pkg.lot_number} />
          <ReadRow label="Estate" value={pkg.location} />
          <ReadRow label="Specification" value={specTierLabel[asSpecTier(pkg.spec_tier)]} />
          <div className="space-y-1.5">
            <FieldLabel>Street & Suburb (optional)</FieldLabel>
            <input className={inputClass} value={draft.streetSuburb} onChange={(e) => set({ streetSuburb: e.target.value })} placeholder="e.g. 12 Example St, Suburb" />
          </div>
          <div className="space-y-1.5">
            <FieldLabel>Occupancy Type</FieldLabel>
            <div className="flex gap-2">
              {OCCUPANCY_OPTIONS.map((o) => (
                <button
                  key={o.key}
                  type="button"
                  onClick={() => set({ occupancy: o.key })}
                  className={cn(
                    "flex-1 rounded-[10px] border px-2 py-2.5 text-[12px] font-medium transition-colors",
                    draft.occupancy === o.key
                      ? "border-avia-brown bg-avia-brown text-avia-white"
                      : "border-avia-line bg-avia-card text-avia-black/60",
                  )}
                >
                  {o.label}
                </button>
              ))}
            </div>
          </div>
        </div>
      )}

      {step === 1 && (
        <div className="space-y-3">
          <div className="text-[12px] font-medium uppercase tracking-wider text-avia-black/40">Buyer 1</div>
          <Field label="Full Name" value={draft.b1Name} onChange={(v) => set({ b1Name: v })} />
          <Field label="Email" value={draft.b1Email} onChange={(v) => set({ b1Email: v })} type="email" />
          <Field label="Address" value={draft.b1Address} onChange={(v) => set({ b1Address: v })} />
          <Field label="Phone" value={draft.b1Phone} onChange={(v) => set({ b1Phone: v })} type="tel" />
          <label className="flex items-center gap-2 pt-1 text-[13px] font-medium text-avia-black/70">
            <input
              type="checkbox"
              checked={draft.hasBuyer2}
              onChange={(e) => set({ hasBuyer2: e.target.checked })}
              className="h-4 w-4 accent-avia-brown"
            />
            Add Second Buyer
          </label>
          {draft.hasBuyer2 && (
            <div className="space-y-3 border-t border-avia-line pt-3">
              <div className="text-[12px] font-medium uppercase tracking-wider text-avia-black/40">Buyer 2</div>
              <Field label="Full Name" value={draft.b2Name} onChange={(v) => set({ b2Name: v })} />
              <Field label="Email" value={draft.b2Email} onChange={(v) => set({ b2Email: v })} type="email" />
              <Field label="Address" value={draft.b2Address} onChange={(v) => set({ b2Address: v })} />
              <Field label="Phone" value={draft.b2Phone} onChange={(v) => set({ b2Phone: v })} type="tel" />
            </div>
          )}
        </div>
      )}

      {step === 2 && (
        <div className="space-y-3">
          <Field label="Company" value={draft.solCompany} onChange={(v) => set({ solCompany: v })} />
          <Field label="Contact Name" value={draft.solName} onChange={(v) => set({ solName: v })} />
          <Field label="Email" value={draft.solEmail} onChange={(v) => set({ solEmail: v })} type="email" />
          <Field label="Address" value={draft.solAddress} onChange={(v) => set({ solAddress: v })} />
          <Field label="Phone" value={draft.solPhone} onChange={(v) => set({ solPhone: v })} type="tel" />
        </div>
      )}

      {step === 3 && (
        <div className="space-y-3">
          <ReviewCard title="Property">
            <ReadRow label="Lot" value={pkg.lot_number} />
            <ReadRow label="Estate" value={pkg.location} />
            {draft.streetSuburb && <ReadRow label="Street & Suburb" value={draft.streetSuburb} />}
            <ReadRow label="Occupancy" value={OCCUPANCY_OPTIONS.find((o) => o.key === draft.occupancy)?.label ?? draft.occupancy} />
          </ReviewCard>
          <ReviewCard title="Buyers">
            <ReadRow label="Buyer 1" value={`${draft.b1Name} · ${draft.b1Email}`} />
            {draft.hasBuyer2 && <ReadRow label="Buyer 2" value={`${draft.b2Name} · ${draft.b2Email}`} />}
          </ReviewCard>
          <ReviewCard title="Solicitor">
            <ReadRow label="Company" value={draft.solCompany} />
            <ReadRow label="Contact" value={`${draft.solName} · ${draft.solEmail}`} />
          </ReviewCard>
          <ReviewCard title="Deposit Payment Details">
            <ReadRow label="Account Name" value="AVIA HOMES PTY LTD" />
            <ReadRow label="BSB" value="064-474" />
            <ReadRow label="Account" value="1087 5601" />
            <ReadRow label="Reference" value={`${pkg.lot_number} ${draft.b1Name.trim().split(/\s+/).pop() ?? ""}`} />
          </ReviewCard>
        </div>
      )}

      <div className="flex gap-2 pt-1">
        {step > 0 && (
          <SecondaryButton onClick={() => setStep(step - 1)} className="flex-1">
            Back
          </SecondaryButton>
        )}
        {step < STEPS.length - 1 ? (
          <PrimaryButton onClick={next} className="flex-1">
            Continue
          </PrimaryButton>
        ) : (
          <PrimaryButton onClick={() => submit.mutate()} loading={submit.isPending} className="flex-1">
            {resubmit ? "Resubmit EOI" : "Submit EOI"}
          </PrimaryButton>
        )}
      </div>
    </Modal>
  );
}

function Field({
  label,
  value,
  onChange,
  type = "text",
}: {
  label: string;
  value: string;
  onChange: (v: string) => void;
  type?: string;
}) {
  return (
    <div className="space-y-1.5">
      <FieldLabel>{label}</FieldLabel>
      <input className={inputClass} type={type} value={value} onChange={(e) => onChange(e.target.value)} />
    </div>
  );
}

function ReadRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center justify-between gap-4 py-1">
      <span className="text-[12px] text-avia-black/50">{label}</span>
      <span className="text-right text-[13px] font-medium text-avia-black">{value}</span>
    </div>
  );
}

function ReviewCard({ title, children }: { title: string; children: ReactNode }) {
  return (
    <div className="rounded-[12px] bg-avia-card p-3.5">
      <div className="mb-1 text-[11px] font-medium uppercase tracking-wider text-avia-black/40">{title}</div>
      {children}
    </div>
  );
}
