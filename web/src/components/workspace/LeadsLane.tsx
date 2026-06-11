import { useMutation, useQueryClient, type UseMutationResult } from "@tanstack/react-query";
import {
  ArrowRight,
  BadgeCheck,
  Check,
  CheckCircle2,
  Circle,
  Clock,
  Flame,
  Globe,
  Mail,
  MessageSquareText,
  Pencil,
  Phone,
  Plus,
  Snowflake,
  Sun,
  Trash2,
  TrendingUp,
  Undo2,
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
import { fmtDate, formatCost, initialsOf, nowISO, relativeTime, uuid } from "@/lib/format";
import { useLeads, useProfiles } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import {
  LEAD_STATUSES,
  leadSourceLabel,
  leadStatusLabel,
  leadTemperatureLabel,
  type LeadRow,
  type LeadSourceKey,
  type LeadStatusKey,
  type ProfileRow,
} from "@/lib/types";
import { cn } from "@/lib/utils";
import {
  CONTRACT_STEP_ID,
  WORKFLOW_STAGES,
  canAdvanceStage,
  canConvertToClient,
  nextStage,
  normalizedStage,
  previousStage,
  stepsForStage,
  workflowStageLabel,
  workflowStageSubtitle,
} from "@/lib/workflow";

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
  const [openLeadId, setOpenLeadId] = useState<string | null>(null);
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
          (l.name ?? "").toLowerCase().includes(q) ||
          (l.email ?? "").toLowerCase().includes(q) ||
          (l.phone ?? "").includes(q),
      );
    }
    return list;
  }, [allLeads, filter, search, userId]);

  const openLead = openLeadId ? allLeads.find((l) => l.id === openLeadId) ?? null : null;

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
            const isOpp = lead.kind === "opportunity";
            const completions = lead.workflow_completions ?? [];
            const steps = stepsForStage(lead.status);
            const done = steps.filter((s) => completions.includes(s.id)).length;
            return (
              <button
                key={lead.id}
                type="button"
                onClick={() => setOpenLeadId(lead.id)}
                className="block w-full text-left"
              >
                <BentoCard className="flex items-center gap-3 p-3.5">
                  <InitialsAvatar initials={initialsOf(lead.name)} />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center gap-2">
                      <span className="truncate text-[14px] font-medium text-avia-black">{lead.name}</span>
                      {isOpp && <StatusPill label="Opportunity" tone="blue" />}
                      {lead.kind === "client" && <StatusPill label="Client" tone="brown" />}
                    </div>
                    <div className="mt-0.5 flex items-center gap-2 text-[11px] text-avia-black/55">
                      <Globe className="h-3 w-3" />
                      {leadSourceLabel[lead.source as LeadSourceKey] ?? lead.source}
                      <span>·</span>
                      {owner ? `${owner.first_name} ${owner.last_name}`.trim() : "Unassigned"}
                      <span>·</span>
                      {relativeTime(lead.created_at)}
                    </div>
                    {isOpp && (
                      <div className="mt-1 flex items-center gap-2 text-[11px] font-medium text-avia-brown">
                        <TrendingUp className="h-3 w-3" />
                        {workflowStageLabel[normalizedStage(lead.status)]} · {done}/{steps.length} steps
                        {lead.estimated_value !== null && lead.estimated_value > 0 && (
                          <span className="text-avia-black/55">· {formatCost(lead.estimated_value)}</span>
                        )}
                      </div>
                    )}
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

      {openLead && (
        <LeadRecordModal
          key={openLead.id}
          lead={openLead}
          staff={staff}
          onClose={() => setOpenLeadId(null)}
        />
      )}
      {creating && <NewLeadModal staff={staff} onClose={() => setCreating(false)} />}
    </div>
  );
}

function useSaveLead(): UseMutationResult<void, Error, LeadRow> {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (row: LeadRow): Promise<void> => {
      const { error } = await supabase.from("leads").upsert(row);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["leads"] });
    },
    onError: () => toast.error("Could not save the lead."),
  });
}

/**
 * Full lead/opportunity record — mirrors the iOS AdminLeadDetailView: header,
 * conversion banner, assignment, pipeline chips, opportunity sales workflow
 * (stepper + checklist + contract gate), inbound message, notes and actions.
 */
function LeadRecordModal({
  lead,
  staff,
  onClose,
}: {
  lead: LeadRow;
  staff: ProfileRow[];
  onClose: () => void;
}) {
  const qc = useQueryClient();
  const { userId } = useAuth();
  const save = useSaveLead();

  const [draft, setDraft] = useState<LeadRow>(lead);
  const [notesDraft, setNotesDraft] = useState<string>(lead.notes ?? "");
  const [showEdit, setShowEdit] = useState<boolean>(false);
  const [confirmDelete, setConfirmDelete] = useState<boolean>(false);

  const persist = (updates: Partial<LeadRow>): void => {
    const next: LeadRow = { ...draft, ...updates, updated_at: nowISO() };
    setDraft(next);
    save.mutate(next);
  };

  const remove = useMutation({
    mutationFn: async (): Promise<void> => {
      const { error } = await supabase.from("leads").delete().eq("id", draft.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["leads"] });
      toast.success("Lead deleted");
      onClose();
    },
    onError: () => toast.error("Could not delete the lead."),
  });

  const owner = staff.find((s) => s.id === draft.owner_id) ?? null;
  const completions = draft.workflow_completions ?? [];
  const kind = draft.kind ?? "lead";
  const title = kind === "opportunity" ? "Opportunity" : kind === "client" ? "Client" : "Lead";

  const toggleStep = (stepId: string): void => {
    const next = completions.includes(stepId)
      ? completions.filter((c) => c !== stepId)
      : [...completions, stepId];
    persist({ workflow_completions: next });
  };

  const convertToOpportunity = (): void => {
    const status = ["new", "contacted", "lost"].includes(draft.status) ? "qualified" : draft.status;
    persist({ kind: "opportunity", status });
  };

  const convertToClient = (): void => {
    if (!canConvertToClient(draft.status, completions)) return;
    persist({
      kind: "client",
      status: "won",
      converted_at: nowISO(),
      converted_client_id: draft.converted_client_id ?? uuid(),
    });
    toast.success(`${draft.name} is now a client`);
  };

  return (
    <Modal open onClose={onClose} title={title}>
      {/* Header card */}
      <BentoCard className="space-y-3 p-4">
        <div className="flex items-center gap-3.5">
          <InitialsAvatar initials={initialsOf(draft.name)} className="h-14 w-14 text-[16px]" />
          <div className="min-w-0 flex-1">
            <div className="truncate text-[18px] font-medium text-avia-brown">
              {draft.name || "Unnamed lead"}
            </div>
            <div className="mt-0.5 flex items-center gap-1.5 text-[11px] font-medium text-avia-black/55">
              <Globe className="h-3 w-3" />
              {leadSourceLabel[draft.source as LeadSourceKey] ?? draft.source}
            </div>
          </div>
          <button
            type="button"
            onClick={() => setShowEdit((v) => !v)}
            className="flex items-center gap-1 rounded-full border border-avia-line px-2.5 py-1.5 text-[11px] font-medium text-avia-black/60 hover:text-avia-black"
          >
            <Pencil className="h-3 w-3" /> Edit
          </button>
        </div>
        {!showEdit && (draft.email || draft.phone) && (
          <div className="space-y-1.5 border-t border-avia-line pt-3">
            {draft.email && (
              <div className="flex items-center gap-2.5 text-[12px] text-avia-black">
                <Mail className="h-3.5 w-3.5 text-avia-brown" />
                {draft.email}
              </div>
            )}
            {draft.phone && (
              <div className="flex items-center gap-2.5 text-[12px] text-avia-black">
                <Phone className="h-3.5 w-3.5 text-avia-brown" />
                {draft.phone}
              </div>
            )}
          </div>
        )}
        {showEdit && (
          <EditDetailsForm
            lead={draft}
            onSave={(updates) => {
              persist(updates);
              setShowEdit(false);
            }}
          />
        )}
        <div className="flex items-center gap-1.5 text-[11px] text-avia-black/35">
          <Clock className="h-3 w-3" />
          Added {relativeTime(draft.created_at)}
          <span className="flex-1" />
          {kind === "client" && (
            <span className="flex items-center gap-1 font-medium text-avia-blue">
              <BadgeCheck className="h-3.5 w-3.5" /> Converted
            </span>
          )}
        </div>
      </BentoCard>

      {/* Conversion banner */}
      {kind === "lead" && (
        <button
          type="button"
          onClick={convertToOpportunity}
          className="flex w-full items-center gap-3 rounded-[13px] bg-gradient-to-br from-avia-black to-avia-brown p-3.5 text-left text-avia-white transition-transform active:scale-[0.99]"
        >
          <TrendingUp className="h-5 w-5 shrink-0" />
          <span className="flex-1">
            <span className="block text-[13px] font-medium">Convert to Opportunity</span>
            <span className="block text-[11px] text-avia-white/80">
              Open the full sales workflow to win this deal.
            </span>
          </span>
          <ArrowRight className="h-4 w-4" />
        </button>
      )}
      {kind === "client" && (
        <BentoCard className="flex items-center gap-3 p-3.5">
          <BadgeCheck className="h-6 w-6 shrink-0 text-avia-blue" />
          <div>
            <div className="text-[13px] font-medium text-avia-black">Converted to client</div>
            <div className="text-[11px] text-avia-black/55">
              {draft.converted_at
                ? `Build contract allocated ${relativeTime(draft.converted_at)}`
                : "Build contract allocated."}
            </div>
          </div>
        </BentoCard>
      )}

      {/* Assignment */}
      <div className="space-y-1.5">
        <FieldLabel>Assigned to</FieldLabel>
        <div className="flex items-center gap-2">
          <select
            value={draft.owner_id ?? ""}
            onChange={(e) => persist({ owner_id: e.target.value || null })}
            className={cn(inputClass, "flex-1")}
            aria-label="Assigned owner"
          >
            <option value="">Unassigned</option>
            {staff.map((s) => (
              <option key={s.id} value={s.id}>
                {`${s.first_name} ${s.last_name}`.trim() || s.email}
              </option>
            ))}
          </select>
          {draft.owner_id !== userId && (
            <button
              type="button"
              onClick={() => persist({ owner_id: userId })}
              className="shrink-0 rounded-[10px] border border-avia-line px-3 py-3 text-[12px] font-medium text-avia-black/60 hover:text-avia-black"
            >
              Assign to me
            </button>
          )}
        </div>
        {owner && <div className="text-[11px] text-avia-black/45">{owner.role}</div>}
      </div>

      {/* Pipeline (leads) or sales workflow (opportunities) */}
      {kind === "lead" && (
        <BentoCard className="space-y-3 p-4">
          <FieldLabel>Status &amp; temperature</FieldLabel>
          <div className="flex flex-wrap gap-1.5">
            {LEAD_STATUSES.map((s) => (
              <Chip
                key={s}
                label={leadStatusLabel[s]}
                selected={draft.status === s}
                onClick={() => persist({ status: s })}
              />
            ))}
          </div>
          <div className="flex gap-1.5">
            {(["hot", "warm", "cold"] as const).map((t) => (
              <Chip
                key={t}
                label={leadTemperatureLabel[t]}
                selected={draft.temperature === t}
                onClick={() => persist({ temperature: t })}
              />
            ))}
          </div>
        </BentoCard>
      )}

      {kind === "opportunity" && (
        <WorkflowCard
          draft={draft}
          completions={completions}
          onToggleStep={toggleStep}
          onMoveStage={(stage) => persist({ status: stage })}
          onConvert={convertToClient}
          onDealChange={(updates) => persist(updates)}
        />
      )}

      {/* Inbound message */}
      {draft.message && (
        <div className="flex items-start gap-2.5 rounded-[10px] bg-avia-card p-3 text-[13px] text-avia-black/80">
          <MessageSquareText className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
          {draft.message}
        </div>
      )}

      {/* Notes */}
      <div className="space-y-1.5">
        <div className="flex items-center justify-between">
          <FieldLabel>Notes</FieldLabel>
          {(draft.notes ?? "") !== notesDraft && (
            <button
              type="button"
              onClick={() => persist({ notes: notesDraft.trim() || null })}
              className="text-[12px] font-medium text-avia-brown"
            >
              Save
            </button>
          )}
        </div>
        <textarea
          value={notesDraft}
          onChange={(e) => setNotesDraft(e.target.value)}
          className={cn(inputClass, "min-h-20 resize-y")}
          placeholder="Add notes about this lead…"
        />
      </div>

      {/* Actions */}
      <div className="flex items-center gap-2">
        {draft.phone && (
          <a
            href={`tel:${draft.phone.replace(/\s/g, "")}`}
            className="flex flex-1 items-center justify-center gap-1.5 rounded-[11px] bg-avia-brown py-3 text-[13px] font-medium text-avia-white"
          >
            <Phone className="h-3.5 w-3.5" /> Call
          </a>
        )}
        {draft.email && (
          <a
            href={`mailto:${draft.email}`}
            className="flex flex-1 items-center justify-center gap-1.5 rounded-[11px] bg-avia-brown py-3 text-[13px] font-medium text-avia-white"
          >
            <Mail className="h-3.5 w-3.5" /> Email
          </a>
        )}
        <button
          type="button"
          onClick={() => setConfirmDelete(true)}
          className="flex items-center justify-center gap-1.5 rounded-[11px] border border-avia-line px-4 py-3 text-[13px] font-medium text-avia-black/55 hover:text-avia-black"
          aria-label="Delete lead"
        >
          <Trash2 className="h-3.5 w-3.5" />
        </button>
      </div>

      {confirmDelete && (
        <div className="space-y-2 rounded-[11px] border border-avia-brown/25 bg-avia-brown/5 p-3.5">
          <div className="text-[13px] text-avia-black">
            Permanently remove {draft.name || "this lead"} from your CRM?
          </div>
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => remove.mutate()}
              disabled={remove.isPending}
              className="rounded-full bg-avia-brown px-3.5 py-2 text-[12px] font-medium text-avia-white disabled:opacity-50"
            >
              Delete
            </button>
            <button
              type="button"
              onClick={() => setConfirmDelete(false)}
              className="rounded-full border border-avia-line px-3.5 py-2 text-[12px] font-medium text-avia-black/60"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </Modal>
  );
}

/** Sales workflow card — stage stepper, per-stage checklist with the contract gate, and advance/convert controls. */
function WorkflowCard({
  draft,
  completions,
  onToggleStep,
  onMoveStage,
  onConvert,
  onDealChange,
}: {
  draft: LeadRow;
  completions: string[];
  onToggleStep: (stepId: string) => void;
  onMoveStage: (stage: string) => void;
  onConvert: () => void;
  onDealChange: (updates: Partial<LeadRow>) => void;
}) {
  const stage = normalizedStage(draft.status);
  const steps = stepsForStage(draft.status);
  const done = steps.filter((s) => completions.includes(s.id)).length;
  const next = nextStage(draft.status);
  const prev = previousStage(draft.status);
  const advanceOk = canAdvanceStage(draft.status, completions);
  const convertOk = canConvertToClient(draft.status, completions);
  const currentIdx = WORKFLOW_STAGES.indexOf(stage);

  const [valueDraft, setValueDraft] = useState<string>(
    draft.estimated_value !== null && draft.estimated_value > 0 ? String(draft.estimated_value) : "",
  );

  return (
    <BentoCard className="space-y-4 p-4">
      <div className="flex items-start gap-3">
        <div className="flex-1">
          <div className="text-[10px] font-medium uppercase tracking-[0.12em] text-avia-black/35">
            Sales workflow
          </div>
          <div className="mt-1 text-[18px] font-medium text-avia-black">{workflowStageLabel[stage]}</div>
          <div className="mt-0.5 text-[12px] text-avia-black/55">{workflowStageSubtitle[stage]}</div>
        </div>
        <div className="rounded-[10px] bg-avia-brown/10 px-2.5 py-1.5 text-center">
          <div className="text-[14px] font-medium text-avia-black">
            {done}/{steps.length}
          </div>
          <div className="text-[9px] font-medium uppercase tracking-wide text-avia-black/45">Done</div>
        </div>
      </div>

      {/* Stage stepper */}
      <div className="flex items-center">
        {WORKFLOW_STAGES.map((s, i) => {
          const isCurrent = i === currentIdx;
          const isPast = i < currentIdx;
          return (
            <div key={s} className="flex flex-1 items-center last:flex-none">
              <div className="flex flex-col items-center gap-1.5">
                <div
                  className={cn(
                    "flex items-center justify-center rounded-full transition-all",
                    isCurrent ? "h-6 w-6 bg-avia-brown" : "h-4.5 w-4.5",
                    isPast ? "h-[18px] w-[18px] bg-avia-blue" : !isCurrent && "h-[18px] w-[18px] bg-avia-black/15",
                  )}
                >
                  {isPast && <Check className="h-2.5 w-2.5 text-avia-white" />}
                  {isCurrent && <span className="h-2 w-2 rounded-full bg-avia-white" />}
                </div>
                <span
                  className={cn(
                    "text-[10px] font-medium",
                    isCurrent ? "text-avia-black" : "text-avia-black/40",
                  )}
                >
                  {workflowStageLabel[s]}
                </span>
              </div>
              {i < WORKFLOW_STAGES.length - 1 && (
                <div className={cn("mx-1 mb-5 h-0.5 flex-1", isPast ? "bg-avia-blue" : "bg-avia-black/10")} />
              )}
            </div>
          );
        })}
      </div>

      {/* Deal fields */}
      <div className="grid grid-cols-2 gap-3 border-t border-avia-line pt-3">
        <div className="space-y-1.5">
          <FieldLabel>Estimated value</FieldLabel>
          <input
            type="number"
            inputMode="numeric"
            value={valueDraft}
            onChange={(e) => setValueDraft(e.target.value)}
            onBlur={() => {
              const parsed = Number(valueDraft);
              const value = Number.isFinite(parsed) && parsed > 0 ? parsed : null;
              if (value !== draft.estimated_value) onDealChange({ estimated_value: value });
            }}
            className={inputClass}
            placeholder="$"
          />
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Expected close</FieldLabel>
          <input
            type="date"
            value={draft.expected_close_date ? draft.expected_close_date.slice(0, 10) : ""}
            onChange={(e) =>
              onDealChange({
                expected_close_date: e.target.value ? new Date(e.target.value).toISOString() : null,
              })
            }
            className={inputClass}
          />
        </div>
      </div>
      {draft.expected_close_date && (
        <div className="text-[11px] text-avia-black/45">Closes {fmtDate(draft.expected_close_date)}</div>
      )}

      {/* Checklist */}
      <div className="space-y-2 border-t border-avia-line pt-3">
        <div className="text-[10px] font-medium uppercase tracking-[0.12em] text-avia-black/45">
          Steps for this stage
        </div>
        {steps.map((step) => {
          const isDone = completions.includes(step.id);
          const isGate = step.id === CONTRACT_STEP_ID;
          return (
            <button
              key={step.id}
              type="button"
              onClick={() => onToggleStep(step.id)}
              className={cn(
                "flex w-full items-start gap-2.5 rounded-[10px] border p-2.5 text-left transition-colors",
                isDone ? "border-avia-blue/30 bg-avia-blue/5" : "border-avia-line bg-avia-cardAlt",
              )}
            >
              {isDone ? (
                <CheckCircle2 className="mt-0.5 h-[18px] w-[18px] shrink-0 text-avia-blue" />
              ) : (
                <Circle className="mt-0.5 h-[18px] w-[18px] shrink-0 text-avia-black/25" />
              )}
              <span className="min-w-0 flex-1">
                <span className="flex items-center gap-1.5">
                  <step.icon className={cn("h-3 w-3", isDone ? "text-avia-blue" : "text-avia-brown")} />
                  <span
                    className={cn(
                      "text-[12px] font-medium text-avia-black",
                      isDone && "line-through opacity-60",
                    )}
                  >
                    {step.title}
                  </span>
                  {isGate && (
                    <span className="rounded-full bg-avia-brown/85 px-1.5 py-px text-[8px] font-semibold uppercase tracking-wide text-avia-white">
                      Gate
                    </span>
                  )}
                </span>
                <span className="mt-0.5 block text-[11px] text-avia-black/55">{step.detail}</span>
              </span>
            </button>
          );
        })}
        <div className="text-[11px] text-avia-black/40">
          Tap a step to mark it done as you progress the deal.
        </div>
      </div>

      {/* Advance / convert */}
      <div className="flex items-center gap-2">
        {prev && (
          <button
            type="button"
            onClick={() => onMoveStage(prev)}
            className="flex h-11 w-11 shrink-0 items-center justify-center rounded-[11px] border border-avia-line text-avia-black/55 hover:text-avia-black"
            aria-label={`Back to ${workflowStageLabel[prev]}`}
          >
            <Undo2 className="h-4 w-4" />
          </button>
        )}
        {stage === "negotiation" ? (
          <button
            type="button"
            onClick={onConvert}
            disabled={!convertOk}
            className={cn(
              "flex h-11 flex-1 items-center justify-center gap-2 rounded-[11px] text-[13px] font-medium text-avia-white transition-all",
              convertOk
                ? "bg-gradient-to-br from-avia-black to-avia-brown active:scale-[0.99]"
                : "bg-avia-black/30",
            )}
          >
            <BadgeCheck className="h-4 w-4" /> Convert to Client
          </button>
        ) : (
          next && (
            <button
              type="button"
              onClick={() => onMoveStage(next)}
              disabled={!advanceOk}
              className={cn(
                "flex h-11 flex-1 items-center justify-center gap-2 rounded-[11px] text-[13px] font-medium text-avia-white transition-all",
                advanceOk
                  ? "bg-gradient-to-br from-avia-black to-avia-brown active:scale-[0.99]"
                  : "bg-avia-black/30",
              )}
            >
              Advance to {workflowStageLabel[next]} <ArrowRight className="h-3.5 w-3.5" />
            </button>
          )
        )}
      </div>
      {stage === "negotiation" && !convertOk && (
        <div className="text-[11px] text-avia-black/45">
          The build contract must be allocated (the gated step above) before they become a client.
        </div>
      )}
    </BentoCard>
  );
}

function EditDetailsForm({
  lead,
  onSave,
}: {
  lead: LeadRow;
  onSave: (updates: Partial<LeadRow>) => void;
}) {
  const [name, setName] = useState<string>(lead.name);
  const [email, setEmail] = useState<string>(lead.email ?? "");
  const [phone, setPhone] = useState<string>(lead.phone ?? "");
  const [source, setSource] = useState<string>(lead.source);

  return (
    <div className="space-y-3 border-t border-avia-line pt-3">
      <div className="space-y-1.5">
        <FieldLabel>Name</FieldLabel>
        <input value={name} onChange={(e) => setName(e.target.value)} className={inputClass} />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Email</FieldLabel>
          <input value={email} onChange={(e) => setEmail(e.target.value)} className={inputClass} />
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Phone</FieldLabel>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClass} />
        </div>
      </div>
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
      <button
        type="button"
        onClick={() =>
          onSave({ name: name.trim(), email: email.trim() || null, phone: phone.trim() || null, source })
        }
        disabled={!name.trim()}
        className="rounded-full bg-avia-brown px-4 py-2 text-[12px] font-medium text-avia-white disabled:opacity-50"
      >
        Save details
      </button>
    </div>
  );
}

function Chip({
  label,
  selected,
  onClick,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "rounded-full px-3 py-1.5 text-[12px] font-medium transition-colors",
        selected
          ? "bg-avia-brown text-avia-white"
          : "border border-avia-line bg-avia-cardAlt text-avia-black/60 hover:text-avia-black",
      )}
    >
      {label}
    </button>
  );
}

function NewLeadModal({ staff, onClose }: { staff: ProfileRow[]; onClose: () => void }) {
  const save = useSaveLead();
  const { userId } = useAuth();
  const [name, setName] = useState<string>("");
  const [email, setEmail] = useState<string>("");
  const [phone, setPhone] = useState<string>("");
  const [source, setSource] = useState<string>("website");
  const [temperature, setTemperature] = useState<string>("warm");
  const [ownerId, setOwnerId] = useState<string>("");
  const [notes, setNotes] = useState<string>("");

  const submit = (): void => {
    const row: LeadRow = {
      id: uuid(),
      name: name.trim(),
      email: email.trim() || null,
      phone: phone.trim() || null,
      source,
      message: null,
      status: "new",
      temperature,
      owner_id: ownerId || null,
      notes: notes.trim() || null,
      converted_client_id: null,
      kind: "lead",
      estimated_value: null,
      expected_close_date: null,
      workflow_completions: [],
      converted_at: null,
      created_at: nowISO(),
      updated_at: nowISO(),
    };
    save.mutate(row, {
      onSuccess: () => {
        toast.success("Lead added");
        onClose();
      },
    });
  };

  return (
    <Modal open onClose={onClose} title="New Lead">
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
      <div className="space-y-1.5">
        <FieldLabel>Owner</FieldLabel>
        <div className="flex items-center gap-2">
          <select value={ownerId} onChange={(e) => setOwnerId(e.target.value)} className={cn(inputClass, "flex-1")}>
            <option value="">Unassigned</option>
            {staff.map((s) => (
              <option key={s.id} value={s.id}>
                {`${s.first_name} ${s.last_name}`.trim() || s.email}
              </option>
            ))}
          </select>
          {ownerId !== userId && (
            <button
              type="button"
              onClick={() => setOwnerId(userId ?? "")}
              className="shrink-0 rounded-[10px] border border-avia-line px-3 py-3 text-[12px] font-medium text-avia-black/60"
            >
              Me
            </button>
          )}
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Notes</FieldLabel>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          className={cn(inputClass, "min-h-20 resize-y")}
          placeholder="Internal notes"
        />
      </div>
      <PrimaryButton onClick={submit} disabled={!name.trim()} loading={save.isPending}>
        Save Lead
      </PrimaryButton>
    </Modal>
  );
}
