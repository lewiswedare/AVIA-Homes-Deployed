import { CheckCircle2, CircleDashed, Clock, TrendingUp } from "lucide-react";

import { BentoCard, EmptyState, ErrorState, ProgressBar, Spinner, StatusPill } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { fmtDate } from "@/lib/format";
import { useMyBuild, useStages } from "@/lib/queries";
import { cn } from "@/lib/utils";

export default function ClientProgress() {
  const { userId } = useAuth();
  const { data: build, isLoading, isError, refetch } = useMyBuild(userId);
  const { data: stages, isLoading: stagesLoading } = useStages(build?.id ?? null);

  if (isLoading || stagesLoading) return <Spinner />;
  if (isError && !build) return <ErrorState onRetry={() => void refetch()} />;

  const stageList = stages ?? [];
  const completed = stageList.filter((s) => s.status === "Completed").length;
  const inProgress = stageList.find((s) => s.status === "In Progress");
  const overall =
    stageList.length > 0
      ? completed / stageList.length + (inProgress?.progress ?? 0) / stageList.length
      : 0;

  if (!build) {
    return (
      <EmptyState
        icon={TrendingUp}
        title="Progress Unlocks With Your Build"
        subtitle="Once your build starts, you'll see every construction stage and live progress here."
      />
    );
  }

  return (
    <div className="space-y-5">
      <h1 className="text-[28px] font-medium text-avia-black">Progress</h1>

      <BentoCard className="p-5">
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[13px] text-avia-black/55">{build.home_design}</div>
            <div className="text-[24px] font-medium text-avia-black">
              {Math.round(overall * 100)}% complete
            </div>
          </div>
          <StatusPill label={inProgress ? inProgress.name : "Pre-Construction"} tone="brown" />
        </div>
        <ProgressBar value={overall} className="mt-4" />
      </BentoCard>

      <div className="space-y-3">
        {stageList.map((stage, index) => {
          const isDone = stage.status === "Completed";
          const isActive = stage.status === "In Progress";
          const isDelayed = stage.status === "Delayed";
          return (
            <div key={stage.id} className="flex gap-4">
              {/* Timeline */}
              <div className="flex flex-col items-center">
                <div
                  className={cn(
                    "flex h-8 w-8 items-center justify-center rounded-full",
                    isDone && "bg-avia-blue/20 text-avia-blue",
                    isActive && "bg-avia-brown text-avia-white",
                    !isDone && !isActive && "bg-avia-black/5 text-avia-black/30",
                  )}
                >
                  {isDone ? (
                    <CheckCircle2 className="h-4 w-4" />
                  ) : isActive ? (
                    <Clock className="h-4 w-4" />
                  ) : (
                    <CircleDashed className="h-4 w-4" />
                  )}
                </div>
                {index < stageList.length - 1 && (
                  <div className={cn("w-px flex-1", isDone ? "bg-avia-blue/40" : "bg-avia-line")} />
                )}
              </div>

              <BentoCard className="mb-1 flex-1 p-4">
                <div className="flex items-start justify-between gap-3">
                  <div>
                    <div className="text-[15px] font-medium text-avia-black">{stage.name}</div>
                    {stage.description && (
                      <div className="mt-0.5 text-[13px] text-avia-black/55">{stage.description}</div>
                    )}
                  </div>
                  <StatusPill
                    label={stage.status}
                    tone={isDone ? "blue" : isActive ? "brown" : isDelayed ? "warning" : "muted"}
                  />
                </div>

                {isActive && (
                  <div className="mt-3">
                    <div className="mb-1.5 flex justify-between text-[12px] text-avia-black/55">
                      <span>Stage progress</span>
                      <span>{Math.round((stage.progress ?? 0) * 100)}%</span>
                    </div>
                    <ProgressBar value={stage.progress ?? 0} />
                  </div>
                )}

                {(stage.estimated_start_date || stage.estimated_end_date) && (
                  <div className="mt-3 flex flex-wrap gap-x-5 gap-y-1 text-[12px] text-avia-black/45">
                    {stage.estimated_start_date && <span>Est. start {fmtDate(stage.estimated_start_date)}</span>}
                    {stage.estimated_end_date && <span>Est. finish {fmtDate(stage.estimated_end_date)}</span>}
                    {stage.actual_end_date && <span>Finished {fmtDate(stage.actual_end_date)}</span>}
                  </div>
                )}
              </BentoCard>
            </div>
          );
        })}
        {stageList.length === 0 && (
          <EmptyState
            icon={TrendingUp}
            title="No stages yet"
            subtitle="Your build stages will appear here once construction is planned."
          />
        )}
      </div>
    </div>
  );
}
