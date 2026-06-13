import {
  Calendar,
  ClipboardCheck,
  FileText,
  Footprints,
  Home,
  Key,
  LayoutGrid,
  MessageSquare,
  Palette,
  TrendingUp,
  Users,
  Wrench,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";
import { Link } from "react-router-dom";

import { BentoCard, ErrorState, Spinner, StatusPill } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fmtDate, fmtDateTime, parseDate } from "@/lib/format";
import { useClientDocuments, useMyBuild, useScheduleForClient, useStages } from "@/lib/queries";
import DiscoverDashboard from "./Discover";

export const scheduleTypeIcon: Record<string, LucideIcon> = {
  "Site Visit": Wrench,
  Walkthrough: Footprints,
  "Colour Due": Palette,
  Inspection: ClipboardCheck,
  Meeting: Users,
  Handover: Key,
};

export default function ClientDashboard() {
  const { profile, userId } = useAuth();
  const { data: build, isLoading: buildLoading, isError: buildError, refetch: refetchBuild } = useMyBuild(userId);
  const { data: stages } = useStages(build?.id ?? null);
  const { data: schedule } = useScheduleForClient(userId);
  const { data: documents } = useClientDocuments(userId);

  const hour = new Date().getHours();
  const greeting = hour < 12 ? "Good morning" : hour < 18 ? "Good afternoon" : "Good evening";
  const name = profile?.first_name ?? "";

  const stageList = stages ?? [];
  const completed = stageList.filter((s) => s.status === "Completed").length;
  const inProgress = stageList.find((s) => s.status === "In Progress");
  const overall =
    stageList.length > 0
      ? completed / stageList.length + (inProgress?.progress ?? 0) / stageList.length
      : 0;

  const upcoming = (schedule ?? [])
    .filter((s) => {
      const d = parseDate(s.date);
      return d !== null && d.getTime() >= Date.now() - 3600000;
    })
    .slice(0, 3);

  const recentDocs = (documents ?? []).slice(0, 3);

  if (buildLoading) return <Spinner />;

  // A failed fetch must not masquerade as "no build" — that would wrongly drop a
  // real client into the marketing Discover view. Offer a retry instead.
  if (buildError && !build) return <ErrorState onRetry={() => void refetchBuild()} />;

  // No build yet → the Discover experience (iOS ClientDiscoverDashboardView parity).
  if (!build) return <DiscoverDashboard />;

  return (
    <div className="space-y-5">
      {/* Greeting header */}
      <div className="rounded-2xl bg-avia-brown/10 p-5">
        <div className="text-[11px] font-medium uppercase tracking-[0.08em] text-avia-black/35">
          {new Date().toLocaleDateString("en-AU", { weekday: "long", day: "numeric", month: "long" })}
        </div>
        <h1 className="mt-1 text-[26px] font-medium text-avia-brown">
          {name ? `${greeting}, ${name}` : greeting}
        </h1>
      </div>

      {/* Build hero */}
      {build && (
        <>
          <BentoCard className="overflow-hidden">
            <div className="relative bg-gradient-to-br from-avia-black to-avia-brown p-6 text-avia-white">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-white/60">
                    Your build
                  </div>
                  <div className="mt-1 text-[24px] font-medium">{build.home_design || "Custom Home"}</div>
                  <div className="mt-0.5 text-[13px] text-avia-white/70">
                    Lot {build.lot_number} · {build.estate}
                  </div>
                </div>
                <Home className="h-7 w-7 text-avia-white/50" />
              </div>
              <div className="mt-6">
                <div className="mb-2 flex items-center justify-between text-[12px]">
                  <span className="text-avia-white/70">
                    {inProgress ? inProgress.name : completed === stageList.length && stageList.length > 0 ? "Complete" : "Pre-Construction"}
                  </span>
                  <span className="font-medium">{Math.round(overall * 100)}%</span>
                </div>
                <div className="h-1.5 w-full overflow-hidden rounded-full bg-avia-white/20">
                  <div
                    className="h-full rounded-full bg-avia-white transition-all duration-700"
                    style={{ width: `${Math.round(overall * 100)}%` }}
                  />
                </div>
              </div>
            </div>
            <div className="grid grid-cols-3 divide-x divide-avia-line">
              <div className="p-4">
                <div className="text-[18px] font-medium text-avia-black">{completed}</div>
                <div className="text-[11px] text-avia-black/45">Stages done</div>
              </div>
              <div className="p-4">
                <div className="text-[18px] font-medium text-avia-black">{stageList.length}</div>
                <div className="text-[11px] text-avia-black/45">Total stages</div>
              </div>
              <div className="p-4">
                <div className="text-[18px] font-medium text-avia-black">
                  {build.estimated_completion_date ? fmtDate(build.estimated_completion_date) : "TBC"}
                </div>
                <div className="text-[11px] text-avia-black/45">Est. completion</div>
              </div>
            </div>
          </BentoCard>

          {/* Quick links */}
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
            {[
              { to: "/selections", label: "Selections", icon: LayoutGrid },
              { to: "/progress", label: "Progress", icon: TrendingUp },
              { to: "/documents", label: "Documents", icon: FileText },
              { to: "/messages", label: "Messages", icon: MessageSquare },
            ].map((q) => (
              <Link
                key={q.to}
                to={q.to}
                className="flex flex-col items-start gap-3 rounded-[13px] bg-avia-card p-4 transition-transform hover:-translate-y-0.5"
              >
                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
                  <q.icon className="h-4 w-4" />
                </div>
                <span className="text-[13px] font-medium text-avia-black">{q.label}</span>
              </Link>
            ))}
          </div>
        </>
      )}

      {/* Upcoming schedule */}
      {upcoming.length > 0 && (
        <div className="space-y-2">
          <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
            Coming up
          </div>
          {upcoming.map((item) => {
            const Icon = scheduleTypeIcon[item.type] ?? Calendar;
            return (
              <BentoCard key={item.id} className="flex items-center gap-3.5 p-3.5">
                <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
                  <Icon className="h-4 w-4" />
                </div>
                <div className="min-w-0 flex-1">
                  <div className="truncate text-[14px] font-medium text-avia-black">{item.title}</div>
                  <div className="text-[12px] text-avia-black/55">{fmtDateTime(item.date)}</div>
                </div>
                <StatusPill label={item.type} tone="brown" />
              </BentoCard>
            );
          })}
        </div>
      )}

      {/* Recent documents */}
      {recentDocs.length > 0 && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <div className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
              Recent documents
            </div>
            <Link to="/documents" className="text-[12px] font-medium text-avia-brown hover:underline">
              View all
            </Link>
          </div>
          {recentDocs.map((doc) => (
            <BentoCard key={doc.id} className="flex items-center gap-3.5 p-3.5">
              <div className="flex h-9 w-9 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
                <FileText className="h-4 w-4" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="truncate text-[14px] font-medium text-avia-black">{doc.name}</div>
                <div className="text-[12px] text-avia-black/55">
                  {doc.category} · {fmtDate(doc.date_added)}
                </div>
              </div>
              {doc.is_new && <StatusPill label="NEW" tone="blue" />}
            </BentoCard>
          ))}
        </div>
      )}
    </div>
  );
}
