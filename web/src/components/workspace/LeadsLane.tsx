import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  Flame,
  Globe,
  MessageSquareText,
  Phone,
  Plus,
  Snowflake,
  Sun,
  UserRoundPlus,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  InitialsAvatar,
  MetricCard,
  Modal,
  PrimaryButton,
  Spinner,
  StatusPill,
  inputClass,
} from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { initialsOf, nowISO, relativeTime, uuid } from "@/lib/format";
import { useLeads, useProfiles } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import {
  LEAD_STATUSES,
  leadSourceLabel,
  leadStatusLabel,
  type LeadRow,
  type LeadSourceKey,
  type LeadStatusKey,
} from "@/lib/types";
import { cn } from "@/lib/utils";

const temperatureIcon: Record<string, LucideIcon> = {
  hot: Flame,
  warm: Sun,
  cold: Snowflake,
};

type OwnerFilter = "all" | "mine" | "unassigned";

export default function LeadsLane({ search }: { search: string }) {
  const { userId } = useAuth();
  const { data: leads, isLoading } = useLeads();
  const { data: profiles } = useProfiles();
  const [filter, setFilter] = useState<OwnerFilter>("all");
  const [editing, setEditing] = useState<LeadRow | null>(null);
  const [creating, setCreating] = useState<boolean>(false);

  const allLeads = leads ?? [];
  const staff = (profiles ?? []).filter((p) =>
    ["Admin", "SalesAdmin", "SuperAdmin", "Staff", "PreConstruction", "BuildingSupport"].includes(p.role),
  );

  const active = allLeads.filter((l) => l.status !== "won" && l.status !== "lost" && l.kind !== "client");
  const unassigned = allLeads.filter((l) => !l.owner_id);
  const mine = allLeads.filter((l) => l.owner_id === userId);

  const visible = useMemo(() => {
    let list = allLeads;
    if (filter === "mine") list = list.filter((l) => l.owner_id === userId);
    if (filter === "unassigned") list = list.filter((l) => !l.owner_id);
    const q = search.trim().toLowerCase();
    if (q) {
      list = list.filter(
        (l) =>
          l.name.toLowerCase().includes(q) ||
          (l.email ?? "").toLowerCase().includes(q) ||
          (l.phone ?? "").includes(q),
      );
    }
    return list;
  }, [allLeads, filter, search, userId]);

  return (
    <div className="space-y-4">
      <div className="flex gap-2.5">
        <MetricCard value={`${active.length}`} label="Active" icon={Users} tone="brown" />
        <MetricCard value={`${unassigned.length}`} label="Unassigned" icon={UserRoundPlus} tone="warning" />
        <MetricCard value={`${mine.length}`} label="Mine" icon={Sun} tone="blue" />
      </div>

      <div className="flex items-center gap-2">
        {(["all", "mine", "unassigned"] as OwnerFilter[]).map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={cn(
              "rounded-full px-3.5 py-2 text-[12px] font-medium capitalize transition-colors",
              filter === f
                ? "bg-avia-brown text-avia-white"
                : "border border-avia-line bg-avia-card text-avia-black/55",
            )}
          >
            {f}
          </button>
        ))}
        <div className="flex-1" />
        <button
          type="button"
          onClick={() => setCreating(true)}
          className="flex items-center gap-1.5 rounded-full bg-avia-brown px-3.5 py-2 text-[12px] font-medium text-avia-white"
        >
          <Plus className="h-3.5 w-3.5" /> New Lead
        </button>
      </div>

      {isLoading ? (
        <Spinner />
      ) : visible.length === 0 ? (
        <EmptyState
          icon={UserRoundPlus}
          title="No leads found"
          subtitle="Inbound enquiries from your website and socials will land here."
        />
      ) : (
        <div className="space-y-2">
          {visible.map((lead) => {
            const TempIcon = temperatureIcon[lead.temperature] ?? Sun;
            const owner = staff.find((s) => s.id === lead.owner_id);
            return (
              <button key={lead.id} type="button" onClick={() => setEditing(lead)} className="block w-full text-left">
                <BentoCard className="flex items-center gap-3 p-3.5">
                  <InitialsAvatar initials={initialsOf(lead.name)} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="truncate text-[14px] font-medium text-avia-black">{lead.name}</span>
                      {lead.kind === "opportunity" && <StatusPill label="Opportunity" tone="blue" />}
                    </div>
                    <div className="mt-0.5 flex items-center gap-2 text-[11px] text-avia-black/55">
                      <Globe className="h-3 w-3" />
                      {leadSourceLabel[lead.source as LeadSourceKey] ?? lead.source}
                      <span>·</span>
                      {owner ? `${owner.first_name} ${owner.last_name}`.trim() : "Unassigned"}
                      <span>·</span>
                      {relativeTime(lead.created_at)}
                    </div>
                  </div>
                  <TempIcon className="h-4 w-4 text-avia-brown/70" />
                  <StatusPill
                    label={leadStatusLabel[lead.status as LeadStatusKey] ?? lead.status}
                    tone={lead.status === "won" ? "blue" : lead.status === "lost" ? "muted" : "brown"}
                  />
                </BentoCard>
              </button>
            );
          })}
        </div>
      )}

      {(editing || creating) && (
        <LeadModal
          lead={editing}
          staff={staff}
          onClose={() => {
            setEditing(null);
            setCreating(false);
          }}
        />
      )}
    </div>
  );
}

function LeadModal({
  lead,
  staff,
  onClose,
}: {
  lead: LeadRow | null;
  staff: { id: string; first_name: string; last_name: string; email: string }[];
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const { userId } = useAuth();
  const [name, setName] = useState<string>(lead?.name ?? "");
  const [email, setEmail] = useState<string>(lead?.email ?? "");
  const [phone, setPhone] = useState<string>(lead?.phone ?? "");
  const [source, setSource] = useState<string>(lead?.source ?? "website");
  const [status, setStatus] = useState<string>(lead?.status ?? "new");
  const [temperature, setTemperature] = useState<string>(lead?.temperature ?? "warm");
  const [ownerId, setOwnerId] = useState<string>(lead?.owner_id ?? "");
  const [notes, setNotes] = useState<string>(lead?.notes ?? "");
  const [kind, setKind] = useState<string>(lead?.kind ?? "lead");

  const save = useMutation({
    mutationFn: async (): Promise<void> => {
      const row: Partial<LeadRow> = {
        id: lead?.id ?? uuid(),
        name: name.trim(),
        email: email.trim() || null,
        phone: phone.trim() || null,
        source,
        status,
        temperature,
        owner_id: ownerId || null,
        notes: notes.trim() || null,
        kind,
        message: lead?.message ?? null,
        converted_client_id: lead?.converted_client_id ?? null,
        workflow_completions: lead?.workflow_completions ?? [],
        created_at: lead?.created_at ?? nowISO(),
        updated_at: nowISO(),
      };
      const { error } = await supabase.from("leads").upsert(row);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["leads"] });
      toast.success(lead ? "Lead updated" : "Lead added");
      onClose();
    },
    onError: () => toast.error("Could not save the lead."),
  });

  return (
    <Modal open onClose={onClose} title={lead ? lead.name : "New Lead"}>
      {lead?.message && (
        <div className="flex items-start gap-2.5 rounded-[10px] bg-avia-card p-3 text-[13px] text-avia-black/80">
          <MessageSquareText className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
          {lead.message}
        </div>
      )}
      <div className="space-y-1.5">
        <FieldLabel>Name</FieldLabel>
        <input value={name} onChange={(e) => setName(e.target.value)} className={inputClass} placeholder="Full name" />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Email</FieldLabel>
          <input value={email} onChange={(e) => setEmail(e.target.value)} className={inputClass} placeholder="Email" />
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Phone</FieldLabel>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} placeholder="Phone" />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Source</FieldLabel>
          <select value={source} onChange={(e) => setSource(e.target.value)} className={inputClass}>
            {Object.entries(leadSourceLabel).map(([key, label]) => (
              <option key={key} value={key}>
                {label}
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Temperature</FieldLabel>
          <select value={temperature} onChange={(e) => setTemperature(e.target.value)} className={inputClass}>
            <option value="hot">Hot</option>
            <option value="warm">Warm</option>
            <option value="cold">Cold</option>
          </select>
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Pipeline stage</FieldLabel>
          <select value={status} onChange={(e) => setStatus(e.target.value)} className={inputClass}>
            {LEAD_STATUSES.map((s) => (
              <option key={s} value={s}>
                {leadStatusLabel[s]}
              </option>
            ))}
          </select>
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Owner</FieldLabel>
          <select value={ownerId} onChange={(e) => setOwnerId(e.target.value)} className={inputClass}>
            <option value="">Unassigned</option>
            {staff.map((s) => (
              <option key={s.id} value={s.id}>
                {`${s.first_name} ${s.last_name}`.trim() || s.email}
              </option>
            ))}
          </select>
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Notes</FieldLabel>
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={cn(inputClass, "min-h-20 resize-y")} placeholder="Internal notes" />
      </div>

      {kind === "lead" ? (
        <button
          type="button"
          onClick={() => setKind("opportunity")}
          className="w-full rounded-[11px] border border-avia-brown/25 bg-avia-brown/10 py-3 text-[14px] font-medium text-avia-brown"
        >
          Convert to Opportunity
        </button>
      ) : kind === "opportunity" ? (
        <div className="rounded-[10px] bg-avia-blue/10 p-3 text-[12px] text-avia-black/70">
          Opportunity in progress — they become a client once a build contract is allocated.
        </div>
      ) : null}

      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={() => setOwnerId(userId ?? "")}
          className="rounded-full border border-avia-line px-3 py-2 text-[12px] font-medium text-avia-black/60"
        >
          Assign to me
        </button>
        {phone && (
          <a href={`tel:${phone}`} className="flex items-center gap-1 rounded-full border border-avia-line px-3 py-2 text-[12px] font-medium text-avia-black/60">
            <Phone className="h-3 w-3" /> Call
          </a>
        )}
      </div>

      <PrimaryButton onClick={() => save.mutate()} disabled={!name.trim()} loading={save.isPending}>
        Save Lead
      </PrimaryButton>
    </Modal>
  );
}
