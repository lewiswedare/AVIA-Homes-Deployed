import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  AlertTriangle,
  BellRing,
  Calendar,
  CheckCheck,
  ChevronRight,
  ClipboardCheck,
  DollarSign,
  FileSearch,
  ListChecks,
  MessageCircle,
  UserRoundPlus,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useState } from "react";
import { Link } from "react-router-dom";
import { toast } from "sonner";

import { EmptyState, InitialsAvatar, MetricCard, Modal, SectionLabel, Spinner } from "@/components/avia/ui";
import { AppointmentRow, TaskRow, nameForClient, taskIsOverdue } from "@/components/workspace/shared";
import { useAuth } from "@/hooks/useAuth";
import { fullNameOf, humanize, initialsOf, isToday, parseDate, relativeTime } from "@/lib/format";
import {
  useAllSchedule,
  useCRMProfiles,
  useEOIAssignments,
  useOpenRequests,
  useOpenTasks,
  usePendingSpecReviews,
  useProfiles,
} from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import { ASSIGNABLE_ROLES, isAdminRole, roleDescription, type ProfileRow, type ServiceRequestRow, type UserRole } from "@/lib/types";

export default function TodayLane() {
  const { role } = useAuth();
  const admin = isAdminRole(role);

  const { data: tasks, isLoading: tasksLoading } = useOpenTasks();
  const { data: schedule, isLoading: scheduleLoading } = useAllSchedule();
  const { data: crm } = useCRMProfiles(admin);
  const { data: profiles } = useProfiles();
  const { data: openRequests } = useOpenRequests();
  const { data: pendingReviews } = usePendingSpecReviews(admin);
  const { data: eoiAssignments } = useEOIAssignments(admin);

  const [showPendingUsers, setShowPendingUsers] = useState<boolean>(false);
  const [showRequests, setShowRequests] = useState<boolean>(false);

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

  // Action Required — mirrors the iOS Workspace panel
  const pendingUsers = allProfiles.filter((p) => p.role === "Pending");
  const openRequestList = openRequests ?? [];
  const reviews = pendingReviews ?? [];
  const pendingEOIs = (eoiAssignments ?? []).filter(
    (a) => a.eoi_status === "submitted" || a.eoi_status === "resubmitted",
  ).length;
  const specReviewBuilds = new Set(
    reviews
      .filter((r) => !["upgrade_requested", "upgrade_accepted", "upgrade_costed"].includes(r.selection_type))
      .map((r) => r.build_id),
  ).size;
  const upgradesToPrice = reviews.filter((r) => r.selection_type === "upgrade_requested").length;
  const actionTotal =
    pendingUsers.length + openRequestList.length + (admin ? pendingEOIs + specReviewBuilds + upgradesToPrice : 0);

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
            {pendingUsers.length > 0 && (
              <ActionRow
                icon={UserRoundPlus}
                text={`${pendingUsers.length} user${pendingUsers.length === 1 ? "" : "s"} awaiting a role`}
                onClick={() => setShowPendingUsers(true)}
              />
            )}
            {openRequestList.length > 0 && (
              <ActionRow
                icon={MessageCircle}
                text={`${openRequestList.length} open client request${openRequestList.length === 1 ? "" : "s"}`}
                onClick={() => setShowRequests(true)}
              />
            )}
            {admin && pendingEOIs > 0 && (
              <ActionRow
                icon={FileSearch}
                text={`${pendingEOIs} EOI${pendingEOIs === 1 ? "" : "s"} awaiting review`}
              />
            )}
            {admin && specReviewBuilds > 0 && (
              <ActionRow
                icon={ClipboardCheck}
                text={`${specReviewBuilds} build${specReviewBuilds === 1 ? "" : "s"} awaiting spec review`}
                to="/workspace?lane=jobs"
              />
            )}
            {admin && upgradesToPrice > 0 && (
              <ActionRow
                icon={DollarSign}
                text={`${upgradesToPrice} upgrade${upgradesToPrice === 1 ? "" : "s"} to price`}
                to="/workspace?lane=jobs"
              />
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

      {showPendingUsers && (
        <PendingUsersModal users={pendingUsers} onClose={() => setShowPendingUsers(false)} />
      )}
      {showRequests && (
        <RequestsModal requests={openRequestList} profiles={allProfiles} onClose={() => setShowRequests(false)} />
      )}
    </div>
  );
}

function ActionRow({
  icon: Icon,
  text,
  to,
  onClick,
}: {
  icon: LucideIcon;
  text: string;
  to?: string;
  onClick?: () => void;
}) {
  const inner = (
    <>
      <span className="flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
        <Icon className="h-3.5 w-3.5" />
      </span>
      <span className="flex-1 text-left text-[12px] text-avia-black">{text}</span>
      {(to || onClick) && <ChevronRight className="h-3.5 w-3.5 text-avia-black/30" />}
    </>
  );
  const className =
    "flex w-full items-center gap-2.5 rounded-lg bg-avia-cardAlt px-3 py-2.5 transition-colors hover:bg-avia-elevated/60";

  if (to) {
    return (
      <Link to={to} className={className}>
        {inner}
      </Link>
    );
  }
  if (onClick) {
    return (
      <button type="button" onClick={onClick} className={className}>
        {inner}
      </button>
    );
  }
  return <div className={className}>{inner}</div>;
}

/** Assign roles to users awaiting approval — mirrors the iOS user management quick action. */
function PendingUsersModal({ users, onClose }: { users: ProfileRow[]; onClose: () => void }) {
  const qc = useQueryClient();
  const [savingId, setSavingId] = useState<string | null>(null);

  const assign = useMutation({
    mutationFn: async ({ userId, newRole }: { userId: string; newRole: UserRole }): Promise<void> => {
      const { error } = await supabase.from("profiles").update({ role: newRole }).eq("id", userId);
      if (error) throw error;
    },
    onSuccess: (_, vars) => {
      void qc.invalidateQueries({ queryKey: ["profiles"] });
      toast.success(`Role set to ${vars.newRole}`);
      setSavingId(null);
    },
    onError: () => {
      toast.error("Could not update the role.");
      setSavingId(null);
    },
  });

  return (
    <Modal open onClose={onClose} title="Users awaiting a role">
      {users.length === 0 ? (
        <div className="py-6 text-center text-[13px] text-avia-black/55">All users have a role assigned.</div>
      ) : (
        users.map((u) => (
          <div key={u.id} className="flex items-center gap-3 rounded-[11px] bg-avia-card p-3.5">
            <InitialsAvatar initials={initialsOf(u.first_name, u.last_name)} />
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-medium text-avia-black">{fullNameOf(u)}</div>
              <div className="truncate text-[11px] text-avia-black/55">{u.email}</div>
            </div>
            <select
              defaultValue=""
              disabled={savingId === u.id}
              onChange={(e) => {
                const newRole = e.target.value as UserRole;
                if (!newRole) return;
                setSavingId(u.id);
                assign.mutate({ userId: u.id, newRole });
              }}
              className="rounded-[9px] border border-avia-line bg-avia-cardAlt px-2.5 py-2 text-[12px] font-medium text-avia-black outline-none focus:border-avia-brown"
              aria-label={`Assign role to ${fullNameOf(u)}`}
            >
              <option value="" disabled>
                Assign role…
              </option>
              {ASSIGNABLE_ROLES.map((r) => (
                <option key={r} value={r} title={roleDescription[r]}>
                  {r}
                </option>
              ))}
            </select>
          </div>
        ))
      )}
    </Modal>
  );
}

/** Open client requests with deep links into the client record. */
function RequestsModal({
  requests,
  profiles,
  onClose,
}: {
  requests: ServiceRequestRow[];
  profiles: ProfileRow[];
  onClose: () => void;
}) {
  return (
    <Modal open onClose={onClose} title="Open client requests">
      {requests.length === 0 ? (
        <div className="py-6 text-center text-[13px] text-avia-black/55">No open requests.</div>
      ) : (
        requests.map((r) => (
          <Link
            key={r.id}
            to={`/clients/${r.client_id}`}
            onClick={onClose}
            className="flex items-center gap-3 rounded-[11px] bg-avia-card p-3.5 transition-colors hover:bg-avia-elevated/60"
          >
            <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
              <MessageCircle className="h-4 w-4" />
            </span>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-medium text-avia-black">{r.title}</div>
              <div className="truncate text-[11px] text-avia-black/55">
                {nameForClient(profiles, r.client_id)}
              </div>
            </div>
            <ChevronRight className="h-3.5 w-3.5 text-avia-black/30" />
          </Link>
        ))
      )}
    </Modal>
  );
}
