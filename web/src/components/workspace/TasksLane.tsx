import { AlertTriangle, Inbox, ListChecks, Plus, User } from "lucide-react";
import { useState } from "react";

import { EmptyState, MetricCard, Spinner } from "@/components/avia/ui";
import { AddTaskModal, TaskRow, taskIsOverdue } from "@/components/workspace/shared";
import { useAuth } from "@/hooks/useAuth";
import { useOpenTasks, useProfiles } from "@/lib/queries";

export default function TasksLane() {
  const { userId } = useAuth();
  const { data: tasks, isLoading } = useOpenTasks();
  const { data: profiles } = useProfiles();
  const [showAdd, setShowAdd] = useState<boolean>(false);

  const taskList = tasks ?? [];
  const allProfiles = profiles ?? [];
  const clients = allProfiles.filter((p) => p.role === "Client");
  const mine = taskList.filter((t) => t.assignee_id === userId);
  const overdue = taskList.filter(taskIsOverdue);

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

      {isLoading ? (
        <Spinner />
      ) : taskList.length === 0 ? (
        <EmptyState icon={ListChecks} title="All caught up" subtitle="No open tasks right now." />
      ) : (
        <div className="space-y-2">
          {taskList.map((t) => (
            <TaskRow key={t.id} task={t} profiles={allProfiles} />
          ))}
        </div>
      )}

      <AddTaskModal open={showAdd} onClose={() => setShowAdd(false)} clients={clients} currentUserId={userId} />
    </div>
  );
}
