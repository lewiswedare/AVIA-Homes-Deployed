import { AlertTriangle, Inbox, ListChecks, Plus, User } from "lucide-react";
import { useMemo, useState } from "react";

import { EmptyState, MetricCard, Spinner } from "@/components/avia/ui";
import { AddTaskModal, TaskRow, taskIsOverdue } from "@/components/workspace/shared";
import { useAuth } from "@/hooks/useAuth";
import { isToday, parseDate } from "@/lib/format";
import { useOpenTasks, useProfiles } from "@/lib/queries";
import { cn } from "@/lib/utils";

type InboxFilter = "all" | "mine" | "overdue" | "today" | "week";

const filterLabel: Record<InboxFilter, string> = {
  all: "All Open",
  mine: "Mine",
  overdue: "Overdue",
  today: "Today",
  week: "This Week",
};

const FILTERS: InboxFilter[] = ["all", "mine", "overdue", "today", "week"];

export default function TasksLane() {
  const { userId } = useAuth();
  const { data: tasks, isLoading } = useOpenTasks();
  const { data: profiles } = useProfiles();
  const [showAdd, setShowAdd] = useState<boolean>(false);
  const [filter, setFilter] = useState<InboxFilter>("all");

  const taskList = tasks ?? [];
  const allProfiles = profiles ?? [];
  const clients = allProfiles.filter((p) => p.role === "Client");
  const mine = taskList.filter((t) => t.assignee_id === userId);
  const overdue = taskList.filter(taskIsOverdue);

  const filtered = useMemo(() => {
    const now = Date.now();
    const weekEnd = now + 7 * 86400000;
    return taskList.filter((t) => {
      switch (filter) {
        case "all":
          return true;
        case "mine":
          return t.assignee_id === userId;
        case "overdue":
          return taskIsOverdue(t);
        case "today": {
          const due = parseDate(t.due_at);
          return due !== null && isToday(due);
        }
        case "week": {
          const due = parseDate(t.due_at);
          return due !== null && due.getTime() >= now && due.getTime() <= weekEnd;
        }
      }
    });
  }, [taskList, filter, userId]);

  return (
    <div className="space-y-4">
      <div className="flex gap-2.5">
        <MetricCard value={`${taskList.length}`} label="Open" icon={Inbox} tone="brown" />
        <MetricCard value={`${mine.length}`} label="Mine" icon={User} tone="blue" />
        <MetricCard value={`${overdue.length}`} label="Overdue" icon={AlertTriangle} tone="warning" />
      </div>

      <button
        type="button"
        onClick={() => setShowAdd(true)}
        className="flex w-full items-center gap-3 rounded-[13px] bg-avia-card p-4 text-[14px] font-medium text-avia-black transition-colors hover:bg-avia-elevated/60"
      >
        <span className="flex h-8 w-8 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
          <Plus className="h-4 w-4" />
        </span>
        Add Task
      </button>

      {/* Inbox filters — mirrors the iOS Tasks Inbox */}
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
        {FILTERS.map((f) => (
          <button
            key={f}
            type="button"
            onClick={() => setFilter(f)}
            className={cn(
              "shrink-0 rounded-full px-3 py-1.5 text-[12px] font-medium transition-colors",
              filter === f
                ? "bg-avia-brown text-avia-white"
                : "border border-avia-line bg-avia-card text-avia-black/55 hover:text-avia-black",
            )}
          >
            {filterLabel[f]}
          </button>
        ))}
      </div>

      {isLoading ? (
        <Spinner />
      ) : filtered.length === 0 ? (
        <EmptyState
          icon={ListChecks}
          title="All caught up"
          subtitle={filter === "all" ? "No open tasks right now." : "No tasks match this filter."}
        />
      ) : (
        <div className="space-y-2">
          {filtered.map((t) => (
            <TaskRow key={t.id} task={t} profiles={allProfiles} />
          ))}
        </div>
      )}

      <AddTaskModal open={showAdd} onClose={() => setShowAdd(false)} clients={clients} currentUserId={userId} />
    </div>
  );
}
