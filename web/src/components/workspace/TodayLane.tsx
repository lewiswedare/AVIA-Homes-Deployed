import {
  AlertTriangle,
  BellRing,
  Calendar,
  CheckCheck,
  ListChecks,
  MessageCircle,
  UserRoundPlus,
} from "lucide-react";
import { Link } from "react-router-dom";

import { EmptyState, MetricCard, SectionLabel, Spinner } from "@/components/avia/ui";
import { AppointmentRow, TaskRow, nameForClient, taskIsOverdue } from "@/components/workspace/shared";
import { humanize, isToday, parseDate, relativeTime } from "@/lib/format";
import { useAllSchedule, useCRMProfiles, useOpenRequests, useOpenTasks, useProfiles } from "@/lib/queries";

export default function TodayLane() {
  const { data: tasks, isLoading: tasksLoading } = useOpenTasks();
  const { data: schedule, isLoading: scheduleLoading } = useAllSchedule();
  const { data: crm } = useCRMProfiles();
  const { data: profiles } = useProfiles();
  const { data: openRequests } = useOpenRequests();

  const allProfiles = profiles ?? [];
  const taskList = tasks ?? [];
  const scheduleList = schedule ?? [];

  const overdue = taskList.filter(taskIsOverdue);
  const dueToday = taskList.filter((t) => {
    if (taskIsOverdue(t)) return false;
    const due = parseDate(t.due_at);
    return due !== null && isToday(due);
  });
  const todaysAppointments = scheduleList.filter((s) => {
    const d = parseDate(s.date);
    return d !== null && isToday(d);
  });
  const weekAppointments = scheduleList.filter((s) => {
    const d = parseDate(s.date);
    if (!d || isToday(d)) return false;
    const weekEnd = Date.now() + 7 * 86400000;
    return d.getTime() > Date.now() && d.getTime() <= weekEnd;
  });
  const followUps = (crm ?? [])
    .filter((c) => {
      const next = parseDate(c.next_follow_up_at);
      return next !== null && next.getTime() <= Date.now() + 2 * 86400000;
    })
    .sort((a, b) => (a.next_follow_up_at ?? "").localeCompare(b.next_follow_up_at ?? ""));

  const pendingUsers = allProfiles.filter((p) => p.role === "Pending").length;
  const openRequestCount = (openRequests ?? []).length;
  const actionTotal = pendingUsers + openRequestCount;

  const totalItems = overdue.length + dueToday.length + todaysAppointments.length + followUps.length;
  const loading = tasksLoading || scheduleLoading;

  return (
    <div className="space-y-5">
      <div className="flex gap-2.5">
        <MetricCard value={`${dueToday.length}`} label="Due Today" icon={ListChecks} tone="brown" />
        <MetricCard value={`${overdue.length}`} label="Overdue" icon={AlertTriangle} tone="warning" />
        <MetricCard value={`${todaysAppointments.length}`} label="Scheduled" icon={Calendar} tone="blue" />
      </div>

      {actionTotal > 0 && (
        <div className="rounded-[13px] bg-avia-card p-4">
          <div className="flex items-center gap-2.5">
            <BellRing className="h-4 w-4 text-avia-brown/80" />
            <span className="flex-1 text-[14px] font-medium text-avia-black">Action Required</span>
            <span className="flex h-6 w-6 items-center justify-center rounded-full bg-avia-brown/80 text-[11px] font-medium text-avia-white">
              {actionTotal}
            </span>
          </div>
          <div className="mt-3 space-y-1.5">
            {pendingUsers > 0 && (
              <div className="flex items-center gap-2.5 rounded-lg bg-avia-cardAlt px-3 py-2.5 text-[12px] text-avia-black">
                <UserRoundPlus className="h-3.5 w-3.5 text-avia-brown" />
                {pendingUsers} user{pendingUsers === 1 ? "" : "s"} awaiting a role
              </div>
            )}
            {openRequestCount > 0 && (
              <div className="flex items-center gap-2.5 rounded-lg bg-avia-cardAlt px-3 py-2.5 text-[12px] text-avia-black">
                <MessageCircle className="h-3.5 w-3.5 text-avia-brown" />
                {openRequestCount} open client request{openRequestCount === 1 ? "" : "s"}
              </div>
            )}
          </div>
        </div>
      )}

      {loading && totalItems === 0 ? (
        <Spinner />
      ) : totalItems === 0 ? (
        <EmptyState icon={CheckCheck} title="You're all clear" subtitle="Nothing due today. Enjoy the calm." />
      ) : (
        <>
          {overdue.length > 0 && (
            <div className="space-y-2">
              <SectionLabel title="Overdue" count={overdue.length} tone="warning" />
              {overdue.map((t) => (
                <TaskRow key={t.id} task={t} profiles={allProfiles} />
              ))}
            </div>
          )}
          {dueToday.length > 0 && (
            <div className="space-y-2">
              <SectionLabel title="Tasks due today" count={dueToday.length} tone="brown" />
              {dueToday.map((t) => (
                <TaskRow key={t.id} task={t} profiles={allProfiles} />
              ))}
            </div>
          )}
          {todaysAppointments.length > 0 && (
            <div className="space-y-2">
              <SectionLabel title="Today's schedule" count={todaysAppointments.length} tone="brown" />
              {todaysAppointments.map((s) => (
                <AppointmentRow key={s.id} item={s} profiles={allProfiles} />
              ))}
            </div>
          )}
          {followUps.length > 0 && (
            <div className="space-y-2">
              <SectionLabel title="Follow-ups due" count={followUps.length} tone="blue" />
              {followUps.map((c) => {
                const overdueFollowUp =
                  c.next_follow_up_at !== null && new Date(c.next_follow_up_at).getTime() < Date.now();
                return (
                  <Link key={c.client_id} to={`/clients/${c.client_id}`} className="block">
                    <div className="flex items-center gap-3 rounded-[11px] bg-avia-card p-3.5">
                      <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-blue/15 text-avia-blue">
                        <Calendar className="h-4 w-4" />
                      </div>
                      <div className="min-w-0 flex-1">
                        <div className="truncate text-[13px] font-medium text-avia-black">
                          {nameForClient(allProfiles, c.client_id)}
                        </div>
                        <div className="text-[11px] text-avia-black/55">{humanize(c.lead_status)}</div>
                      </div>
                      <span
                        className={`text-[11px] font-medium ${overdueFollowUp ? "text-avia-brown/90" : "text-avia-black/55"}`}
                      >
                        {relativeTime(c.next_follow_up_at)}
                      </span>
                    </div>
                  </Link>
                );
              })}
            </div>
          )}
          {weekAppointments.length > 0 && (
            <div className="space-y-2">
              <SectionLabel title="Later this week" count={weekAppointments.length} tone="muted" />
              {weekAppointments.map((s) => (
                <AppointmentRow key={s.id} item={s} profiles={allProfiles} />
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
