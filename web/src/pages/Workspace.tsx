import {
  Building2,
  Calendar,
  ListChecks,
  Search,
  Send,
  Sun,
  UserRoundPlus,
  Users,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useState } from "react";
import { useSearchParams } from "react-router-dom";

import ClientsLane from "@/components/workspace/ClientsLane";
import JobsLane from "@/components/workspace/JobsLane";
import LeadsLane from "@/components/workspace/LeadsLane";
import ScheduleLane from "@/components/workspace/ScheduleLane";
import SendingLane from "@/components/workspace/SendingLane";
import TasksLane from "@/components/workspace/TasksLane";
import TodayLane from "@/components/workspace/TodayLane";
import { taskIsOverdue } from "@/components/workspace/shared";
import { useAuth } from "@/hooks/useAuth";
import { isToday, parseDate, startOfDay } from "@/lib/format";
import { useAllSchedule, useCRMProfiles, useOpenTasks } from "@/lib/queries";
import { isAdminRole, isPartnerRole } from "@/lib/types";
import { cn } from "@/lib/utils";

type Lane = "today" | "tasks" | "leads" | "clients" | "jobs" | "schedule" | "sending";

const laneConfig: { id: Lane; label: string; icon: LucideIcon }[] = [
  { id: "today", label: "Today", icon: Sun },
  { id: "tasks", label: "Tasks", icon: ListChecks },
  { id: "leads", label: "Leads", icon: UserRoundPlus },
  { id: "clients", label: "Clients", icon: Users },
  { id: "jobs", label: "Jobs", icon: Building2 },
  { id: "schedule", label: "Schedule", icon: Calendar },
  { id: "sending", label: "Sending", icon: Send },
];

export default function Workspace() {
  const { role, profile } = useAuth();
  const [params, setParams] = useSearchParams();
  const [search, setSearch] = useState<string>("");

  const admin = isAdminRole(role);
  const partner = isPartnerRole(role);

  const lanes: Lane[] = admin
    ? ["today", "tasks", "leads", "clients", "jobs", "schedule", "sending"]
    : partner
      ? ["clients", "jobs", "schedule"]
      : ["today", "tasks", "jobs", "schedule"];

  const requested = params.get("lane") as Lane | null;
  const lane: Lane = requested && lanes.includes(requested) ? requested : lanes[0];

  // Badge data (shared query keys with the lanes, so no extra fetches)
  const hasTaskLanes = lanes.includes("today") || lanes.includes("tasks");
  const { data: tasks } = useOpenTasks(hasTaskLanes);
  const { data: schedule } = useAllSchedule();
  const { data: crm } = useCRMProfiles(admin);

  const taskList = tasks ?? [];
  const scheduleList = schedule ?? [];
  const overdueCount = taskList.filter(taskIsOverdue).length;
  const dueTodayCount = taskList.filter((t) => {
    if (taskIsOverdue(t)) return false;
    const due = parseDate(t.due_at);
    return due !== null && isToday(due);
  }).length;
  const todaysAppointments = scheduleList.filter((s) => {
    const d = parseDate(s.date);
    return d !== null && isToday(d);
  }).length;
  const followUpsDue = (crm ?? []).filter((c) => {
    const next = parseDate(c.next_follow_up_at);
    return next !== null && next.getTime() <= Date.now() + 2 * 86400000;
  }).length;
  const upcomingCount = scheduleList.filter((s) => {
    const d = parseDate(s.date);
    return d !== null && d.getTime() >= startOfDay(new Date()).getTime();
  }).length;

  const laneBadge = (l: Lane): number => {
    switch (l) {
      case "today":
        return overdueCount + dueTodayCount + todaysAppointments + followUpsDue;
      case "tasks":
        return overdueCount;
      case "schedule":
        return upcomingCount;
      default:
        return 0;
    }
  };

  const hour = new Date().getHours();
  const greetingPart = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
  const greeting = profile?.first_name ? `${greetingPart}, ${profile.first_name}` : greetingPart;

  const visibleLanes = laneConfig.filter((l) => lanes.includes(l.id));
  const searchableLanes: Lane[] = ["leads", "clients", "jobs", "sending"];

  return (
    <div className="space-y-5">
      {/* Header */}
      <div className="rounded-2xl bg-avia-brown/10 p-5">
        <div className="text-[11px] font-medium uppercase tracking-[0.08em] text-avia-black/35">
          {new Date().toLocaleDateString("en-AU", { weekday: "long", day: "numeric", month: "long" })}
        </div>
        <h1 className="mt-1 text-[26px] font-medium text-avia-brown">{greeting}</h1>
      </div>

      {/* Lane selector */}
      <div className="flex gap-2 overflow-x-auto pb-1 scrollbar-none">
        {visibleLanes.map((l) => {
          const badge = laneBadge(l.id);
          const active = lane === l.id;
          return (
            <button
              key={l.id}
              type="button"
              onClick={() => setParams({ lane: l.id }, { replace: true })}
              className={cn(
                "flex shrink-0 items-center gap-1.5 rounded-full px-3.5 py-2 text-[12px] font-medium transition-all",
                active
                  ? "bg-avia-brown text-avia-white"
                  : "border border-avia-line bg-avia-card text-avia-black/55 hover:text-avia-black",
              )}
            >
              <l.icon className="h-3.5 w-3.5" />
              {l.label}
              {badge > 0 && (
                <span
                  className={cn(
                    "flex h-4 min-w-4 items-center justify-center rounded-full px-1 text-[9px] font-semibold",
                    active ? "bg-avia-white text-avia-brown" : "bg-avia-brown/85 text-avia-white",
                  )}
                >
                  {badge}
                </span>
              )}
            </button>
          );
        })}
      </div>

      {/* Search */}
      {searchableLanes.includes(lane) && (
        <div className="relative">
          <Search className="absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-avia-black/35" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search clients & jobs"
            className="w-full rounded-[11px] border border-avia-line bg-avia-card py-3 pl-10 pr-4 text-[14px] text-avia-black outline-none placeholder:text-avia-black/35 focus:border-avia-brown"
          />
        </div>
      )}

      <div key={lane} className="animate-fade-in">
        {lane === "today" && <TodayLane />}
        {lane === "tasks" && <TasksLane />}
        {lane === "leads" && <LeadsLane search={search} />}
        {lane === "clients" && <ClientsLane search={search} />}
        {lane === "jobs" && <JobsLane search={search} />}
        {lane === "schedule" && <ScheduleLane />}
        {lane === "sending" && <SendingLane search={search} />}
      </div>
    </div>
  );
}
