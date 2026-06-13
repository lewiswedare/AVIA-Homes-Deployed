import { AlertTriangle, Building2, ChevronRight, HardHat, Handshake, Users, Wrench } from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { useMemo, useState } from "react";
import { Navigate } from "react-router-dom";

import { BentoCard, InitialsAvatar, MetricCard, Modal, Spinner, StatusPill } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fullNameOf, initialsOf } from "@/lib/format";
import { useAllStages, useBuilds, usePackageAssignments, useProfiles } from "@/lib/queries";
import type { BuildRow, PackageAssignmentRow, ProfileRow } from "@/lib/types";

interface StaffSection {
  title: string;
  icon: LucideIcon;
  roles: string[];
  buildKey: keyof BuildRow | null;
  countLabel: string;
}

const SECTIONS: StaffSection[] = [
  { title: "Pre-Construction", icon: Wrench, roles: ["PreConstruction"], buildKey: "preconstruction_staff_id", countLabel: "builds" },
  { title: "Building Support", icon: HardHat, roles: ["BuildingSupport"], buildKey: "building_support_staff_id", countLabel: "builds" },
  { title: "Staff", icon: Users, roles: ["Staff"], buildKey: "assigned_staff_id", countLabel: "builds" },
  { title: "Sales", icon: Handshake, roles: ["SalesPartner", "SalesAdmin"], buildKey: null, countLabel: "packages" },
];

function buildCountFor(builds: BuildRow[], key: keyof BuildRow, staffId: string): number {
  const sid = staffId.toLowerCase();
  return builds.filter((b) => ((b[key] as string | null) ?? "").toLowerCase() === sid).length;
}

function packageCountFor(assignments: PackageAssignmentRow[], userId: string): number {
  const uid = userId.toLowerCase();
  return assignments.filter(
    (a) =>
      (a.assigned_partner_ids ?? []).some((id) => id.toLowerCase() === uid) ||
      (a.shared_with_client_ids ?? []).some((id) => id.toLowerCase() === uid),
  ).length;
}

/** SuperAdmin overview — mirrors iOS SuperAdminDashboard (builds + staff oversight). */
export default function Overview() {
  const { role } = useAuth();
  const profilesQ = useProfiles();
  const buildsQ = useBuilds();
  const stagesQ = useAllStages();
  const assignmentsQ = usePackageAssignments(role === "SuperAdmin");
  const [detailStaff, setDetailStaff] = useState<{ staff: ProfileRow; section: StaffSection } | null>(null);

  const builds = buildsQ.data ?? [];
  const profiles = profilesQ.data ?? [];
  const assignments = assignmentsQ.data ?? [];

  const activeBuilds = builds.filter((b) => (b.status ?? "active") === "active").length;
  const awaitingHandover = useMemo(() => {
    const stageBuildIds = new Set((stagesQ.data ?? []).map((s) => s.build_id));
    return builds.filter((b) => !b.handover_triggered_at && stageBuildIds.has(b.id)).length;
  }, [builds, stagesQ.data]);

  if (role !== "SuperAdmin") return <Navigate to="/workspace" replace />;
  if (profilesQ.isLoading || buildsQ.isLoading || stagesQ.isLoading) return <Spinner />;

  return (
    <div className="animate-fade-in space-y-6">
      <div>
        <h1 className="text-[26px] font-medium text-avia-black">Super Admin</h1>
        <p className="text-[13px] text-avia-black/50">Company-wide build & staff oversight</p>
      </div>

      <section className="space-y-2.5">
        <h2 className="text-[11px] font-medium uppercase tracking-[0.12em] text-avia-black/40">All Builds</h2>
        <div className="grid grid-cols-2 gap-3">
          <MetricCard value={String(activeBuilds)} label="Active Builds" icon={Building2} />
          <MetricCard value={String(builds.length)} label="Total Builds" icon={Building2} tone="blue" />
        </div>
        {awaitingHandover > 0 && (
          <div className="flex items-center gap-3 rounded-[13px] border border-avia-brown/25 bg-avia-brown/10 p-4">
            <AlertTriangle className="h-5 w-5 text-avia-brown" />
            <span className="text-[13px] font-medium text-avia-brown">
              {awaitingHandover} build{awaitingHandover === 1 ? "" : "s"} awaiting handover
            </span>
          </div>
        )}
      </section>

      {SECTIONS.map((section) => {
        const members = profiles.filter((p) => section.roles.includes(p.role));
        if (members.length === 0) return null;
        return (
          <section key={section.title} className="space-y-2.5">
            <h2 className="text-[11px] font-medium uppercase tracking-[0.12em] text-avia-black/40">{section.title}</h2>
            <BentoCard className="divide-y divide-avia-line/60 px-4">
              {members.map((m) => {
                const count = section.buildKey
                  ? buildCountFor(builds, section.buildKey, m.id)
                  : packageCountFor(assignments, m.id);
                return (
                  <button
                    key={m.id}
                    type="button"
                    onClick={() => setDetailStaff({ staff: m, section })}
                    className="flex w-full items-center gap-3 py-3 text-left"
                  >
                    <InitialsAvatar initials={initialsOf(m.first_name, m.last_name)} className="h-9 w-9 text-[11px]" />
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-medium text-avia-black">{fullNameOf(m)}</div>
                      <div className="truncate text-[12px] text-avia-black/45">{m.display_title ?? m.role}</div>
                    </div>
                    <span className="text-[12px] text-avia-black/50">
                      {count} {section.countLabel}
                    </span>
                    <ChevronRight className="h-4 w-4 text-avia-black/35" />
                  </button>
                );
              })}
            </BentoCard>
          </section>
        );
      })}

      {detailStaff && (
        <StaffDetailModal
          staff={detailStaff.staff}
          section={detailStaff.section}
          builds={builds}
          assignments={assignments}
          profiles={profiles}
          onClose={() => setDetailStaff(null)}
        />
      )}
    </div>
  );
}

function StaffDetailModal({
  staff,
  section,
  builds,
  assignments,
  profiles,
  onClose,
}: {
  staff: ProfileRow;
  section: StaffSection;
  builds: BuildRow[];
  assignments: PackageAssignmentRow[];
  profiles: ProfileRow[];
  onClose: () => void;
}) {
  const sid = staff.id.toLowerCase();
  const assignedBuilds = section.buildKey
    ? builds.filter((b) => ((b[section.buildKey as keyof BuildRow] as string | null) ?? "").toLowerCase() === sid)
    : [];
  const pipeline = assignments.filter((a) => (a.assigned_partner_ids ?? []).some((id) => id.toLowerCase() === sid));

  const clientName = (b: BuildRow) => {
    const primary = profiles.find((p) => p.id.toLowerCase() === b.client_id.toLowerCase());
    return primary ? fullNameOf(primary) : b.home_design;
  };

  return (
    <Modal open onClose={onClose} title={fullNameOf(staff)}>
      <BentoCard className="flex items-center gap-3 p-4">
        <InitialsAvatar initials={initialsOf(staff.first_name, staff.last_name)} className="h-11 w-11" />
        <div className="min-w-0">
          <div className="text-[15px] font-medium text-avia-black">{fullNameOf(staff)}</div>
          <div className="text-[12px] text-avia-black/50">{staff.display_title ?? staff.role}</div>
          <div className="truncate text-[12px] text-avia-black/45">{staff.email}</div>
        </div>
      </BentoCard>

      {section.buildKey && (
        <div className="space-y-2">
          <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Assigned Builds</div>
          {assignedBuilds.length === 0 && <div className="py-4 text-center text-[13px] text-avia-black/45">No assigned builds</div>}
          <div className="max-h-64 space-y-2 overflow-y-auto">
            {assignedBuilds.map((b) => (
              <div key={b.id} className="flex items-center gap-3 rounded-[12px] bg-avia-card p-3">
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-medium text-avia-black">{clientName(b)}</div>
                  <div className="truncate text-[12px] text-avia-black/45">
                    {b.home_design} — Lot {b.lot_number}
                  </div>
                </div>
                <StatusPill label={b.status ?? "active"} tone={(b.status ?? "active") === "active" ? "brown" : "muted"} />
              </div>
            ))}
          </div>
        </div>
      )}

      {!section.buildKey && (
        <div className="space-y-2">
          <div className="text-[11px] font-medium uppercase tracking-wider text-avia-black/40">Packages in Pipeline</div>
          {pipeline.length === 0 && <div className="py-4 text-center text-[13px] text-avia-black/45">No packages in pipeline</div>}
          <div className="max-h-64 space-y-2 overflow-y-auto">
            {pipeline.map((a) => (
              <div key={a.id} className="flex items-center gap-3 rounded-[12px] bg-avia-card p-3">
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[13px] font-medium text-avia-black">Package {a.package_id.slice(0, 8)}</div>
                  <div className="text-[12px] text-avia-black/45">
                    {(a.shared_with_client_ids ?? []).length} clients shared
                  </div>
                </div>
                <StatusPill label={a.deposit_status ?? "pending"} tone="warning" />
              </div>
            ))}
          </div>
        </div>
      )}
    </Modal>
  );
}
