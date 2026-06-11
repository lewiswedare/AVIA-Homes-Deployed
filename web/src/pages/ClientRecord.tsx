import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  Calendar,
  ExternalLink,
  FileText,
  Mail,
  MailOpen,
  Phone,
  Plus,
  Send,
  StickyNote,
} from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { Link, useParams, useSearchParams } from "react-router-dom";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  InitialsAvatar,
  PrimaryButton,
  Spinner,
  StatusPill,
  inputClass,
} from "@/components/avia/ui";
import { AddTaskModal, AppointmentRow, TaskRow } from "@/components/workspace/shared";
import { useAuth } from "@/hooks/useAuth";
import { fmtDate, fmtDateTime, humanize, initialsOf, nowISO, uuid } from "@/lib/format";
import {
  useCRMProfiles,
  useClientDocuments,
  useClientNotes,
  useEmailSends,
  useProfile,
  useProfiles,
  useScheduleForClient,
  useTasksForClient,
} from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import { LEAD_STATUSES, leadStatusLabel, type ClientNoteRow } from "@/lib/types";
import { cn } from "@/lib/utils";

type Tab = "overview" | "tasks" | "schedule" | "documents" | "sending";

const tabs: { id: Tab; label: string }[] = [
  { id: "overview", label: "Overview" },
  { id: "tasks", label: "Tasks" },
  { id: "schedule", label: "Schedule" },
  { id: "documents", label: "Documents" },
  { id: "sending", label: "Sending" },
];

export default function ClientRecord() {
  const { clientId } = useParams<{ clientId: string }>();
  const [params, setParams] = useSearchParams();
  const id = clientId ?? "";

  const { data: client, isLoading } = useProfile(id);
  const tab: Tab = (params.get("tab") as Tab | null) ?? "overview";

  if (isLoading) return <Spinner />;
  if (!client) {
    return <EmptyState icon={FileText} title="Client not found" subtitle="This record may have been removed." />;
  }

  const name = `${client.first_name} ${client.last_name}`.trim() || client.email;

  return (
    <div className="space-y-5">
      <Link
        to="/workspace?lane=clients"
        className="inline-flex items-center gap-1.5 text-[13px] font-medium text-avia-brown hover:underline"
      >
        <ArrowLeft className="h-4 w-4" /> Workspace
      </Link>

      {/* Header */}
      <BentoCard className="flex flex-wrap items-center gap-4 p-5">
        <InitialsAvatar initials={initialsOf(client.first_name, client.last_name)} className="h-14 w-14 text-[16px]" />
        <div className="min-w-0 flex-1">
          <div className="text-[22px] font-medium text-avia-black">{name}</div>
          <div className="mt-0.5 flex flex-wrap items-center gap-x-4 gap-y-1 text-[13px] text-avia-black/55">
            <span className="flex items-center gap-1.5">
              <Mail className="h-3.5 w-3.5" /> {client.email}
            </span>
            {client.phone && (
              <span className="flex items-center gap-1.5">
                <Phone className="h-3.5 w-3.5" /> {client.phone}
              </span>
            )}
          </div>
        </div>
        <StatusPill label={client.role} tone="brown" />
      </BentoCard>

      {/* Tabs */}
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
        {tabs.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setParams({ tab: t.id }, { replace: true })}
            className={cn(
              "shrink-0 rounded-full px-3.5 py-2 text-[12px] font-medium transition-colors",
              tab === t.id
                ? "bg-avia-brown text-avia-white"
                : "border border-avia-line bg-avia-card text-avia-black/55 hover:text-avia-black",
            )}
          >
            {t.label}
          </button>
        ))}
      </div>

      <div key={tab} className="animate-fade-in">
        {tab === "overview" && <OverviewTab clientId={id} />}
        {tab === "tasks" && <TasksTab clientId={id} />}
        {tab === "schedule" && <ScheduleTab clientId={id} />}
        {tab === "documents" && <DocumentsTab clientId={id} />}
        {tab === "sending" && <SendingTab clientId={id} />}
      </div>
    </div>
  );
}

function OverviewTab({ clientId }: { clientId: string }) {
  const qc = useQueryClient();
  const { userId } = useAuth();
  const { data: crmProfiles } = useCRMProfiles();
  const { data: notes } = useClientNotes(clientId);

  const record = useMemo(
    () => (crmProfiles ?? []).find((c) => c.client_id === clientId) ?? null,
    [crmProfiles, clientId],
  );

  const [status, setStatus] = useState<string>("new");
  const [temperature, setTemperature] = useState<string>("warm");
  const [followUp, setFollowUp] = useState<string>("");
  const [noteBody, setNoteBody] = useState<string>("");

  useEffect(() => {
    if (!record) return;
    setStatus(record.lead_status);
    setTemperature(record.lead_temperature);
    setFollowUp(record.next_follow_up_at ? record.next_follow_up_at.slice(0, 16) : "");
  }, [record]);

  const saveCRM = useMutation({
    mutationFn: async (): Promise<void> => {
      const { error } = await supabase.from("client_crm_profile").upsert(
        {
          client_id: clientId,
          lead_status: status,
          lead_temperature: temperature,
          next_follow_up_at: followUp ? new Date(followUp).toISOString() : null,
          tags: record?.tags ?? [],
          owner_id: record?.owner_id ?? null,
          last_contacted_at: record?.last_contacted_at ?? null,
          lifetime_value: record?.lifetime_value ?? 0,
          updated_at: nowISO(),
        },
        { onConflict: "client_id" },
      );
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["client_crm_profile"] });
      toast.success("CRM record saved");
    },
    onError: () => toast.error("Could not save the CRM record."),
  });

  const addNote = useMutation({
    mutationFn: async (): Promise<void> => {
      const row: ClientNoteRow = {
        id: uuid(),
        client_id: clientId,
        author_id: userId,
        body: noteBody.trim(),
        pinned: false,
        created_at: nowISO(),
        updated_at: nowISO(),
      };
      const { error } = await supabase.from("client_notes").insert(row);
      if (error) throw error;
    },
    onSuccess: () => {
      setNoteBody("");
      void qc.invalidateQueries({ queryKey: ["client_notes", clientId] });
    },
    onError: () => toast.error("Could not add the note."),
  });

  return (
    <div className="grid gap-4 lg:grid-cols-2">
      <BentoCard className="space-y-4 p-5">
        <div className="text-[14px] font-medium text-avia-black">Sales workflow</div>
        <div className="grid grid-cols-2 gap-3">
          <div className="space-y-1.5">
            <FieldLabel>Stage</FieldLabel>
            <select value={status} onChange={(e) => setStatus(e.target.value)} className={inputClass}>
              {LEAD_STATUSES.map((s) => (
                <option key={s} value={s}>
                  {leadStatusLabel[s]}
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
          <FieldLabel>Next follow-up</FieldLabel>
          <input
            type="datetime-local"
            value={followUp}
            onChange={(e) => setFollowUp(e.target.value)}
            className={inputClass}
          />
        </div>
        {record?.last_contacted_at && (
          <div className="text-[12px] text-avia-black/45">
            Last contacted {fmtDateTime(record.last_contacted_at)}
          </div>
        )}
        <PrimaryButton onClick={() => saveCRM.mutate()} loading={saveCRM.isPending}>
          Save CRM Record
        </PrimaryButton>
      </BentoCard>

      <BentoCard className="space-y-4 p-5">
        <div className="text-[14px] font-medium text-avia-black">Notes</div>
        <div className="flex gap-2">
          <input
            value={noteBody}
            onChange={(e) => setNoteBody(e.target.value)}
            className={inputClass}
            placeholder="Add a note…"
          />
          <button
            type="button"
            onClick={() => noteBody.trim() && addNote.mutate()}
            className="flex h-12 w-12 shrink-0 items-center justify-center rounded-[10px] bg-avia-brown text-avia-white disabled:opacity-50"
            disabled={!noteBody.trim() || addNote.isPending}
            aria-label="Add note"
          >
            <Plus className="h-4 w-4" />
          </button>
        </div>
        <div className="space-y-2">
          {(notes ?? []).map((note) => (
            <div key={note.id} className="rounded-[10px] bg-avia-cardAlt p-3">
              <div className="flex items-start gap-2.5">
                <StickyNote className="mt-0.5 h-3.5 w-3.5 shrink-0 text-avia-brown" />
                <div>
                  <div className="text-[13px] text-avia-black">{note.body}</div>
                  <div className="mt-1 text-[11px] text-avia-black/40">{fmtDateTime(note.created_at)}</div>
                </div>
              </div>
            </div>
          ))}
          {(notes ?? []).length === 0 && (
            <div className="py-4 text-center text-[13px] text-avia-black/45">No notes yet.</div>
          )}
        </div>
      </BentoCard>
    </div>
  );
}

function TasksTab({ clientId }: { clientId: string }) {
  const { userId } = useAuth();
  const { data: tasks, isLoading } = useTasksForClient(clientId);
  const { data: profiles } = useProfiles();
  const [showAdd, setShowAdd] = useState<boolean>(false);

  if (isLoading) return <Spinner />;

  const open = (tasks ?? []).filter((t) => !t.completed_at);
  const done = (tasks ?? []).filter((t) => Boolean(t.completed_at));

  return (
    <div className="space-y-4">
      <button
        type="button"
        onClick={() => setShowAdd(true)}
        className="flex w-full items-center gap-3 rounded-[13px] bg-avia-card p-4 text-[14px] font-medium text-avia-black hover:bg-avia-elevated/60"
      >
        <span className="flex h-8 w-8 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
          <Plus className="h-4 w-4" />
        </span>
        Add Task
      </button>

      {open.length === 0 && done.length === 0 ? (
        <EmptyState icon={Calendar} title="No tasks" subtitle="Tasks for this client will appear here." />
      ) : (
        <>
          <div className="space-y-2">
            {open.map((t) => (
              <TaskRow key={t.id} task={t} profiles={profiles ?? []} />
            ))}
          </div>
          {done.length > 0 && (
            <div className="space-y-2">
              <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
                Completed
              </div>
              {done.map((t) => (
                <TaskRow key={t.id} task={t} profiles={profiles ?? []} />
              ))}
            </div>
          )}
        </>
      )}

      <AddTaskModal
        open={showAdd}
        onClose={() => setShowAdd(false)}
        clients={(profiles ?? []).filter((p) => p.role === "Client")}
        currentUserId={userId}
      />
    </div>
  );
}

function ScheduleTab({ clientId }: { clientId: string }) {
  const { data: schedule, isLoading } = useScheduleForClient(clientId);
  const { data: profiles } = useProfiles();

  if (isLoading) return <Spinner />;

  const items = schedule ?? [];
  return (
    <div className="space-y-2">
      {items.length === 0 ? (
        <EmptyState icon={Calendar} title="Nothing scheduled" subtitle="Appointments for this client will appear here." />
      ) : (
        items.map((item) => <AppointmentRow key={item.id} item={item} profiles={profiles ?? []} />)
      )}
    </div>
  );
}

function DocumentsTab({ clientId }: { clientId: string }) {
  const { data: documents, isLoading } = useClientDocuments(clientId);

  if (isLoading) return <Spinner />;

  const docs = documents ?? [];
  return (
    <div className="space-y-2">
      {docs.length === 0 ? (
        <EmptyState icon={FileText} title="No documents" subtitle="Documents shared with this client will appear here." />
      ) : (
        docs.map((doc) => (
          <BentoCard key={doc.id} className="flex items-center gap-3.5 p-4">
            <div className="flex h-10 w-10 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
              <FileText className="h-4 w-4" />
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[14px] font-medium text-avia-black">{doc.name}</div>
              <div className="text-[12px] text-avia-black/55">
                {doc.category} · {fmtDate(doc.date_added)}
              </div>
            </div>
            {doc.file_url && (
              <a
                href={doc.file_url}
                target="_blank"
                rel="noreferrer"
                className="rounded-full p-2 text-avia-brown hover:bg-avia-brown/10"
                aria-label={`Open ${doc.name}`}
              >
                <ExternalLink className="h-4 w-4" />
              </a>
            )}
          </BentoCard>
        ))
      )}
    </div>
  );
}

function SendingTab({ clientId }: { clientId: string }) {
  const { data: sends, isLoading } = useEmailSends(clientId);

  if (isLoading) return <Spinner />;

  const list = sends ?? [];
  return (
    <div className="space-y-3">
      <BentoCard className="flex items-center gap-3 p-4">
        <Send className="h-4 w-4 text-avia-brown" />
        <div className="text-[12px] text-avia-black/55">
          Sent emails and open tracking for this client. Compose &amp; send from the iOS app using your connected
          Microsoft account.
        </div>
      </BentoCard>

      {list.length === 0 ? (
        <EmptyState icon={Mail} title="Nothing sent yet" subtitle="Emails sent to this client will appear here with open tracking." />
      ) : (
        list.map((send) => (
          <BentoCard key={send.id} className="p-4">
            <div className="flex items-start justify-between gap-3">
              <div className="min-w-0">
                <div className="truncate text-[14px] font-medium text-avia-black">{send.subject}</div>
                <div className="mt-0.5 text-[12px] text-avia-black/55">
                  To {send.to_email} · {fmtDateTime(send.created_at)}
                  {send.sender_name ? ` · from ${send.sender_name}` : ""}
                </div>
                {send.document_name && (
                  <div className="mt-1.5 inline-flex items-center gap-1.5 rounded-full bg-avia-brown/10 px-2.5 py-1 text-[11px] font-medium text-avia-brown">
                    <FileText className="h-3 w-3" /> {send.document_name}
                  </div>
                )}
              </div>
              <div className="flex shrink-0 flex-col items-end gap-1.5">
                <StatusPill label={humanize(send.status ?? "sent")} tone={send.status === "failed" ? "black" : "brown"} />
                {(send.open_count ?? 0) > 0 ? (
                  <span className="flex items-center gap-1 text-[11px] font-medium text-avia-blue">
                    <MailOpen className="h-3 w-3" />
                    Opened {send.open_count}×
                  </span>
                ) : (
                  <span className="text-[11px] text-avia-black/35">Not opened yet</span>
                )}
              </div>
            </div>
          </BentoCard>
        ))
      )}
    </div>
  );
}
