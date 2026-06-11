import { useMutation, useQueryClient, type UseMutationResult } from "@tanstack/react-query";
import {
  Calendar,
  CheckCircle2,
  ChevronRight,
  Circle,
  ClipboardCheck,
  Footprints,
  Key,
  Palette,
  User,
  Users,
  Wrench,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";

import { BentoCard, FieldLabel, Modal, PrimaryButton, inputClass } from "@/components/avia/ui";
import { fmtDateTime, fmtTime, nowISO, parseDate, relativeTime, uuid } from "@/lib/format";
import { supabase } from "@/lib/supabase";
import type { ClientTaskRow, ProfileRow, ScheduleItemRow } from "@/lib/types";
import { cn } from "@/lib/utils";

export const scheduleIcon: Record<string, LucideIcon> = {
  "Site Visit": Wrench,
  Walkthrough: Footprints,
  "Colour Due": Palette,
  Inspection: ClipboardCheck,
  Meeting: Users,
  Handover: Key,
};

export function taskIsOverdue(task: ClientTaskRow): boolean {
  if (task.completed_at) return false;
  const due = parseDate(task.due_at);
  return due !== null && due.getTime() < Date.now();
}

export function nameForClient(profiles: ProfileRow[], clientId: string | null): string {
  if (!clientId) return "General task";
  const p = profiles.find((x) => x.id === clientId);
  if (!p) return "Client";
  const name = `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim();
  return name || p.email || "Client";
}

export function useToggleTask(): UseMutationResult<void, Error, ClientTaskRow> {
  const qc = useQueryClient();
  return useMutation({
    mutationFn: async (task: ClientTaskRow): Promise<void> => {
      const completedAt = task.completed_at ? null : nowISO();
      const { error } = await supabase
        .from("client_tasks")
        .update({ completed_at: completedAt })
        .eq("id", task.id);
      if (error) throw error;
    },
    onSuccess: () => {
      void qc.invalidateQueries({ queryKey: ["client_tasks"] });
    },
    onError: () => toast.error("Could not update the task. Please try again."),
  });
}

export function TaskRow({
  task,
  profiles,
}: {
  task: ClientTaskRow;
  profiles: ProfileRow[];
}) {
  const toggle = useToggleTask();
  const overdue = taskIsOverdue(task);
  const content = (
    <BentoCard className="flex items-start gap-3 p-3.5">
      <button
        type="button"
        aria-label={task.completed_at ? "Mark incomplete" : "Mark complete"}
        onClick={(e) => {
          e.preventDefault();
          e.stopPropagation();
          toggle.mutate(task);
        }}
        className="mt-0.5 text-avia-black/30 transition-colors hover:text-avia-blue"
      >
        {task.completed_at ? (
          <CheckCircle2 className="h-5 w-5 text-avia-blue" />
        ) : (
          <Circle className="h-5 w-5" />
        )}
      </button>
      <div className="min-w-0 flex-1">
        <div className="text-[13px] font-medium text-avia-black">{task.title}</div>
        <div className="mt-1 flex items-center gap-1.5 text-[11px] text-avia-black/55">
          <User className="h-3 w-3" />
          {nameForClient(profiles, task.client_id)}
        </div>
        {task.due_at && (
          <div
            className={cn(
              "mt-0.5 flex items-center gap-1.5 text-[11px]",
              overdue ? "font-medium text-avia-brown/90" : "text-avia-black/35",
            )}
          >
            <Calendar className="h-3 w-3" />
            {fmtDateTime(task.due_at)}
            {overdue && <span className="font-semibold">OVERDUE</span>}
          </div>
        )}
      </div>
      {task.client_id && <ChevronRight className="h-3.5 w-3.5 self-center text-avia-black/30" />}
    </BentoCard>
  );

  if (task.client_id) {
    return (
      <Link to={`/clients/${task.client_id}`} className="block">
        {content}
      </Link>
    );
  }
  return content;
}

export function AppointmentRow({
  item,
  profiles,
}: {
  item: ScheduleItemRow;
  profiles: ProfileRow[];
}) {
  const Icon = scheduleIcon[item.type] ?? Calendar;
  const date = parseDate(item.date);
  const today = date !== null && new Date(date).toDateString() === new Date().toDateString();
  const owner = nameForClient(profiles, item.client_id);

  return (
    <Link to={`/clients/${item.client_id}`} className="block">
      <BentoCard className="flex items-center gap-3 p-3.5">
        <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
          <Icon className="h-4 w-4" />
        </div>
        <div className="min-w-0 flex-1">
          <div className="truncate text-[13px] font-medium text-avia-black">{item.title}</div>
          <div className="mt-0.5 flex items-center gap-2 text-[11px] text-avia-black/55">
            <span className="truncate">{owner}</span>
            <span className="rounded-full bg-avia-brown/10 px-1.5 py-px text-[9px] font-medium text-avia-brown">
              {item.type}
            </span>
          </div>
        </div>
        <div className="text-right">
          <div className="text-[13px] font-medium text-avia-black">{fmtTime(item.date)}</div>
          {!today && <div className="text-[11px] text-avia-black/35">{relativeTime(item.date)}</div>}
        </div>
      </BentoCard>
    </Link>
  );
}

export function AddTaskModal({
  open,
  onClose,
  clients,
  currentUserId,
}: {
  open: boolean;
  onClose: () => void;
  clients: ProfileRow[];
  currentUserId: string | null;
}) {
  const qc = useQueryClient();
  const [title, setTitle] = useState<string>("");
  const [detail, setDetail] = useState<string>("");
  const [clientId, setClientId] = useState<string>("");
  const [due, setDue] = useState<string>("");
  const [priority, setPriority] = useState<string>("normal");
  const [saving, setSaving] = useState<boolean>(false);

  const save = async () => {
    if (!title.trim()) return;
    setSaving(true);
    const row: ClientTaskRow = {
      id: uuid(),
      client_id: clientId || null,
      title: title.trim(),
      detail: detail.trim() || null,
      due_at: due ? new Date(due).toISOString() : null,
      completed_at: null,
      assignee_id: currentUserId,
      created_by: currentUserId,
      priority,
      created_at: nowISO(),
    };
    const { error } = await supabase.from("client_tasks").upsert(row);
    setSaving(false);
    if (error) {
      toast.error("Could not save the task.");
      return;
    }
    void qc.invalidateQueries({ queryKey: ["client_tasks"] });
    toast.success("Task added");
    setTitle("");
    setDetail("");
    setClientId("");
    setDue("");
    setPriority("normal");
    onClose();
  };

  return (
    <Modal open={open} onClose={onClose} title="New Task">
      <div className="space-y-1.5">
        <FieldLabel>Title</FieldLabel>
        <input value={title} onChange={(e) => setTitle(e.target.value)} className={inputClass} placeholder="What needs doing?" />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Details (optional)</FieldLabel>
        <textarea value={detail} onChange={(e) => setDetail(e.target.value)} className={cn(inputClass, "min-h-20 resize-y")} placeholder="Extra context" />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Link to client</FieldLabel>
        <select value={clientId} onChange={(e) => setClientId(e.target.value)} className={inputClass}>
          <option value="">General (no client)</option>
          {clients.map((c) => (
            <option key={c.id} value={c.id}>
              {`${c.first_name} ${c.last_name}`.trim() || c.email}
            </option>
          ))}
        </select>
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="space-y-1.5">
          <FieldLabel>Due</FieldLabel>
          <input type="datetime-local" value={due} onChange={(e) => setDue(e.target.value)} className={inputClass} />
        </div>
        <div className="space-y-1.5">
          <FieldLabel>Priority</FieldLabel>
          <select value={priority} onChange={(e) => setPriority(e.target.value)} className={inputClass}>
            <option value="low">Low</option>
            <option value="normal">Normal</option>
            <option value="high">High</option>
          </select>
        </div>
      </div>
      <PrimaryButton onClick={() => void save()} disabled={!title.trim()} loading={saving}>
        Save Task
      </PrimaryButton>
    </Modal>
  );
}
