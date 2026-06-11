import { AlertTriangle, Building2, ChevronRight, Hammer } from "lucide-react";
import { useCallback, useMemo } from "react";
import { Link } from "react-router-dom";

import { BentoCard, EmptyState, MetricCard, ProgressBar, Spinner, StatusPill } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { useAllStages, useBuilds, usePendingSpecReviews, useProfiles } from "@/lib/queries";
import { isAdminRole, type BuildSpecSelectionRow, type BuildStageRow } from "@/lib/types";

/** Per-build review summary — mirrors the iOS BuildSpecReviewBadge resolver. */
function reviewSummary(reviews: BuildSpecSelectionRow[]): string | null {
  const newUpgradeRequests = reviews.filter((r) => r.selection_type === "upgrade_requested").length;
  const acceptedUpgrades = reviews.filter((r) => r.selection_type === "upgrade_accepted").length;
  const newSubmissions = reviews.filter(
    (r) => !["upgrade_requested", "upgrade_accepted", "upgrade_costed"].includes(r.selection_type),
  ).length;

  const parts: string[] = [];
  if (newUpgradeRequests > 0) {
    parts.push(`${newUpgradeRequests} new upgrade req${newUpgradeRequests === 1 ? "" : "s"}`);
  }
  if (acceptedUpgrades > 0) {
    parts.push(`${acceptedUpgrades} spec upgrade${acceptedUpgrades === 1 ? "" : "s"} to approve`);
  }
  if (newSubmissions > 0 && parts.length === 0) {
    parts.push(`${newSubmissions} spec item${newSubmissions === 1 ? "" : "s"} submitted`);
  }
  return parts.length > 0 ? parts.join(" • ") : null;
}

export default function JobsLane({ search }: { search: string }) {
  const { role } = useAuth();
  const admin = isAdminRole(role);
  const { data: builds, isLoading } = useBuilds();
  const { data: stages } = useAllStages();
  const { data: profiles } = useProfiles();
  const { data: pendingReviews } = usePendingSpecReviews(admin);

  const stagesByBuild = useMemo(() => {
    const map = new Map<string, BuildStageRow[]>();
    for (const s of stages ?? []) {
      const list = map.get(s.build_id) ?? [];
      list.push(s);
      map.set(s.build_id, list);
    }
    return map;
  }, [stages]);

  const reviewsByBuild = useMemo(() => {
    const map = new Map<string, BuildSpecSelectionRow[]>();
    for (const r of pendingReviews ?? []) {
      const list = map.get(r.build_id) ?? [];
      list.push(r);
      map.set(r.build_id, list);
    }
    return map;
  }, [pendingReviews]);

  const nameFor = useCallback(
    (clientId: string): string => {
      const p = (profiles ?? []).find((x) => x.id === clientId);
      if (!p) return "Unassigned";
      return `${p.first_name ?? ""} ${p.last_name ?? ""}`.trim() || p.email || "Unassigned";
    },
    [profiles],
  );

  const filtered = useMemo(() => {
    const list = builds ?? [];
    const q = search.trim().toLowerCase();
    if (!q) return list;
    return list.filter(
      (b) =>
        nameFor(b.client_id).toLowerCase().includes(q) ||
        (b.home_design ?? "").toLowerCase().includes(q) ||
        (b.lot_number ?? "").toLowerCase().includes(q) ||
        (b.estate ?? "").toLowerCase().includes(q),
    );
  }, [builds, search, nameFor]);

  const active = (builds ?? []).filter((b) =>
    (stagesByBuild.get(b.id) ?? []).some((s) => s.status === "In Progress"),
  );
  const needsReview = (builds ?? []).filter((b) => (reviewsByBuild.get(b.id) ?? []).length > 0);

  if (isLoading) return <Spinner />;

  return (
    <div className="space-y-4">
      <div className="flex gap-2.5">
        <MetricCard value={`${(builds ?? []).length}`} label="Total Jobs" icon={Building2} tone="brown" />
        <MetricCard value={`${active.length}`} label="Active" icon={Hammer} tone="warning" />
        {admin && (
          <MetricCard value={`${needsReview.length}`} label="Need Review" icon={AlertTriangle} tone="blue" />
        )}
      </div>

      {filtered.length === 0 ? (
        <EmptyState
          icon={Building2}
          title="No jobs found"
          subtitle={search ? "Try a different search." : "New builds will appear here."}
        />
      ) : (
        <div className="space-y-2">
          {filtered.map((build) => {
            const buildStages = stagesByBuild.get(build.id) ?? [];
            const completed = buildStages.filter((s) => s.status === "Completed").length;
            const current = buildStages.find((s) => s.status === "In Progress");
            const overall =
              buildStages.length > 0
                ? completed / buildStages.length + (current?.progress ?? 0) / buildStages.length
                : 0;
            const summary = admin ? reviewSummary(reviewsByBuild.get(build.id) ?? []) : null;
            return (
              <Link key={build.id} to={`/clients/${build.client_id}`} className="block">
                <BentoCard className="p-4">
                  <div className="flex items-center gap-3">
                    <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
                      <Building2 className="h-4 w-4" />
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[14px] font-medium text-avia-black">
                        {nameFor(build.client_id)}
                      </div>
                      <div className="truncate text-[12px] text-avia-black/55">
                        {build.home_design} · Lot {build.lot_number} · {build.estate}
                      </div>
                    </div>
                    <StatusPill
                      label={current ? current.name : "Pre-Construction"}
                      tone={current ? "brown" : "muted"}
                    />
                    <ChevronRight className="h-4 w-4 text-avia-black/30" />
                  </div>
                  {summary && (
                    <div className="mt-2.5 flex items-center gap-1.5 rounded-lg bg-avia-brown/10 px-2.5 py-1.5 text-[11px] font-medium text-avia-brown">
                      <AlertTriangle className="h-3 w-3 shrink-0" />
                      {summary}
                    </div>
                  )}
                  {buildStages.length > 0 && (
                    <div className="mt-3 flex items-center gap-3">
                      <ProgressBar value={overall} className="flex-1" />
                      <span className="text-[11px] font-medium text-avia-black/55">
                        {Math.round(overall * 100)}%
                      </span>
                    </div>
                  )}
                </BentoCard>
              </Link>
            );
          })}
        </div>
      )}
    </div>
  );
}
