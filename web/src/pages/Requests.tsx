import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  GitBranch,
  MessageCircle,
  MessagesSquare,
  Plus,
  Wrench,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  Modal,
  PrimaryButton,
  Spinner,
  StatusPill,
  inputClass,
} from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { notifyUsers, staffAndAdminIds } from "@/lib/catalog";
import { fmtDate, fullNameOf, nowISO, uuid } from "@/lib/format";
import { useMyBuild, useProfiles, useServiceRequests } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type { ServiceRequestRow } from "@/lib/types";
import { REQUEST_CATEGORIES, REQUEST_STATUSES, isClientRole } from "@/lib/types";
import { cn } from "@/lib/utils";

const categoryIcon: Record<string, LucideIcon> = {
  General: MessageCircle,
  Defect: AlertTriangle,
  Variation: GitBranch,
  Maintenance: Wrench,
};

function statusTone(status: string): "warning" | "brown" | "muted" {
  if (status === "Open") return "warning";
  if (status === "In Progress") return "brown";
  return "muted";
}

type Filter = "All" | "Open" | "In Progress" | "Resolved";

/** Requests & Support — mirrors iOS RequestsView (client + staff handling). */
export default function Requests() {
  const { role, userId } = useAuth();
  const client = isClientRole(role);
  const requestsQ = useServiceRequests(client ? userId : null, !client);
  const profilesQ = useProfiles();
  const [filter, setFilter] = useState<Filter>("All");
  const [newOpen, setNewOpen] = useState<boolean>(false);
  const [detailId, setDetailId] = useState<string | null>(null);

  const requests = useMemo(() => {
    const list = requestsQ.data ?? [];
    if (filter === "All") return list;
    return list.filter((r) => r.status === filter);
  }, [requestsQ.data, filter]);

  const detail = (requestsQ.data ?? []).find((r) => r.id === detailId) ?? null;
  const nameOf = (id: string) =>
    fullNameOf((profilesQ.data ?? []).find((p) => p.id.toLowerCase() === id.toLowerCase()) ?? { email: "Client" });

  if (requestsQ.isLoading) return <Spinner />;

  return (
    <div className="animate-fade-in space-y-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[26px] font-medium text-avia-black">Requests & Support</h1>
          <p className="text-[13px] text-avia-black/50">
            {client ? "Questions, defects, variations and maintenance" : "All client support requests"}
          </p>
        </div>
        {client && (
          <button
            type="button"
            onClick={() => setNewOpen(true)}
            className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
          >
            <Plus className="h-4 w-4" /> New Request
          </button>
        )}
      </div>

      <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
        {(["All", "Open", "In Progress", "Resolved"] as Filter[]).map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={cn(
              "whitespace-nowrap rounded-full border px-3.5 py-1.5 text-[12px] font-medium transition-colors",
              filter === f ? "border-avia-brown bg-avia-brown text-avia-white" : "border-avia-line bg-avia-card text-avia-black/60",
            )}
          >
            {f}
          </button>
        ))}
      </div>

      {requests.length === 0 ? (
        <EmptyState
          icon={MessagesSquare}
          title="No requests here"
          subtitle={client ? "Need anything? Submit a request and our team will respond." : "Client requests will appear here."}
        />
      ) : (
        <div className="space-y-2.5">
          {requests.map((r) => {
            const Icon = categoryIcon[r.category ?? "General"] ?? MessageCircle;
            const responses = r.responses ?? [];
            return (
              <button key={r.id} type="button" onClick={() => setDetailId(r.id)} className="block w-full text-left">
                <BentoCard className="flex items-center gap-3.5 p-4 transition-colors hover:bg-avia-cardAlt">
                  <div className={cn("flex h-10 w-10 shrink-0 items-center justify-center rounded-full", r.status === "Resolved" ? "bg-avia-black/5 text-avia-black/45" : "bg-avia-brown/10 text-avia-brown")}>
                    <Icon className="h-5 w-5" />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-avia-black">{r.title}</div>
                    <div className="flex items-center gap-2 text-[12px] text-avia-black/45">
                      {!client && <span>{nameOf(r.client_id)} ·</span>}
                      <span>Updated {fmtDate(r.last_updated ?? r.date_created)}</span>
                      {responses.length > 0 && (
                        <span className="flex items-center gap-1">
                          <MessageCircle className="h-3 w-3" /> {responses.length}
                        </span>
                      )}
                    </div>
                  </div>
                  <StatusPill label={r.status} tone={statusTone(r.status)} />
                </BentoCard>
              </button>
            );
          })}
        </div>
      )}

      {newOpen && <NewRequestModal onClose={() => setNewOpen(false)} />}
      {detail && (
        <RequestDetailModal
          request={detail}
          isStaff={!client}
          clientName={nameOf(detail.client_id)}
          onClose={() => setDetailId(null)}
        />
      )}
    </div>
  );
}

function NewRequestModal({ onClose }: { onClose: () => void }) {
  const { userId, profile } = useAuth();
  const profilesQ = useProfiles();
  const { data: build } = useMyBuild(userId);
  const queryClient = useQueryClient();
  const [category, setCategory] = useState<string>("General");
  const [title, setTitle] = useState<string>("");
  const [description, setDescription] = useState<string>("");

  const submit = useMutation({
    mutationFn: async () => {
      if (!title.trim() || !description.trim()) throw new Error("Subject and description are required");
      const { error } = await supabase.from("service_requests").insert({
        id: uuid(),
        client_id: userId,
        build_id: build?.id ?? null,
        title: title.trim(),
        description: description.trim(),
        category,
        status: "Open",
        date_created: nowISO(),
        last_updated: nowISO(),
        responses: [],
      });
      if (error) throw error;
      await notifyUsers({
        recipientIds: staffAndAdminIds(profilesQ.data),
        senderId: userId,
        senderName: profile ? fullNameOf(profile) : "Client",
        type: "request_submitted",
        title: "New Support Request",
        message: `${profile ? fullNameOf(profile) : "A client"} submitted: ${title.trim()}`,
        referenceType: "service_request",
      });
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["service_requests"] });
      toast.success("Request submitted — our team will respond soon");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <Modal open onClose={onClose} title="New Request">
      <div className="space-y-1.5">
        <FieldLabel>Category</FieldLabel>
        <div className="grid grid-cols-2 gap-2">
          {REQUEST_CATEGORIES.map((c) => {
            const Icon = categoryIcon[c];
            return (
              <button
                key={c}
                type="button"
                onClick={() => setCategory(c)}
                className={cn(
                  "flex items-center gap-2 rounded-[10px] border px-3 py-2.5 text-[13px] font-medium transition-colors",
                  category === c ? "border-avia-brown bg-avia-brown text-avia-white" : "border-avia-line bg-avia-card text-avia-black/60",
                )}
              >
                <Icon className="h-4 w-4" /> {c}
              </button>
            );
          })}
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Subject</FieldLabel>
        <input className={inputClass} value={title} onChange={(e) => setTitle(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Description</FieldLabel>
        <textarea className={`${inputClass} min-h-28 resize-y`} value={description} onChange={(e) => setDescription(e.target.value)} />
      </div>
      <PrimaryButton onClick={() => submit.mutate()} loading={submit.isPending} disabled={!title.trim() || !description.trim()}>
        Submit Request
      </PrimaryButton>
    </Modal>
  );
}

function RequestDetailModal({
  request,
  isStaff,
  clientName,
  onClose,
}: {
  request: ServiceRequestRow;
  isStaff: boolean;
  clientName: string;
  onClose: () => void;
}) {
  const { userId, profile } = useAuth();
  const queryClient = useQueryClient();
  const [reply, setReply] = useState<string>("");
  const responses = request.responses ?? [];

  const respond = useMutation({
    mutationFn: async () => {
      if (!reply.trim()) throw new Error("Write a response first");
      const entry = {
        id: uuid(),
        author: profile ? fullNameOf(profile) : isStaff ? "AVIA Homes" : "Client",
        message: reply.trim(),
        date: nowISO(),
        is_from_client: !isStaff,
      };
      const nextStatus = isStaff && request.status === "Open" ? "In Progress" : request.status;
      const { error } = await supabase
        .from("service_requests")
        .update({ responses: [...responses, entry], status: nextStatus, last_updated: nowISO() })
        .eq("id", request.id);
      if (error) throw error;
      if (isStaff) {
        await notifyUsers({
          recipientIds: [request.client_id],
          senderId: userId,
          senderName: entry.author,
          type: "request_response",
          title: "Response to Your Request",
          message: `${entry.author} replied to "${request.title}"`,
          referenceId: request.id,
          referenceType: "service_request",
        });
      }
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["service_requests"] });
      setReply("");
      toast.success("Response sent");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const setStatus = useMutation({
    mutationFn: async (status: string) => {
      const { error } = await supabase
        .from("service_requests")
        .update({ status, last_updated: nowISO() })
        .eq("id", request.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["service_requests"] });
      toast.success("Status updated");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <Modal open onClose={onClose} title={request.title}>
      <div className="flex flex-wrap items-center gap-2">
        <StatusPill label={request.category ?? "General"} tone="muted" />
        <StatusPill label={request.status} tone={statusTone(request.status)} />
        <span className="text-[12px] text-avia-black/45">
          {isStaff ? `${clientName} · ` : ""}Submitted {fmtDate(request.date_created)}
        </span>
      </div>
      {request.description && (
        <div className="rounded-[12px] bg-avia-card p-3.5 text-[14px] leading-relaxed text-avia-black/75">{request.description}</div>
      )}

      {isStaff && (
        <div className="flex gap-2">
          {REQUEST_STATUSES.map((s) => (
            <button
              key={s}
              type="button"
              disabled={setStatus.isPending || request.status === s}
              onClick={() => setStatus.mutate(s)}
              className={cn(
                "flex-1 rounded-[10px] border px-2 py-2 text-[12px] font-medium transition-colors disabled:opacity-60",
                request.status === s ? "border-avia-brown bg-avia-brown text-white" : "border-avia-line bg-avia-card text-avia-black/60",
              )}
            >
              {s}
            </button>
          ))}
        </div>
      )}

      {responses.length > 0 && (
        <div className="space-y-2">
          <FieldLabel>Conversation</FieldLabel>
          <div className="max-h-60 space-y-2 overflow-y-auto">
            {responses.map((r) => (
              <div
                key={r.id}
                className={cn(
                  "rounded-[12px] p-3 text-[13px] leading-relaxed",
                  r.is_from_client ? "bg-avia-brown/10 text-avia-black/80" : "bg-avia-card text-avia-black/75",
                )}
              >
                <div className="mb-0.5 flex items-center justify-between text-[11px] text-avia-black/45">
                  <span className="font-medium">{r.author}</span>
                  <span>{fmtDate(r.date)}</span>
                </div>
                {r.message}
              </div>
            ))}
          </div>
        </div>
      )}

      <div className="space-y-2">
        <textarea
          className={`${inputClass} min-h-20 resize-y`}
          placeholder="Write a response…"
          value={reply}
          onChange={(e) => setReply(e.target.value)}
        />
        <PrimaryButton onClick={() => respond.mutate()} loading={respond.isPending} disabled={!reply.trim()}>
          Send Response
        </PrimaryButton>
      </div>
    </Modal>
  );
}
