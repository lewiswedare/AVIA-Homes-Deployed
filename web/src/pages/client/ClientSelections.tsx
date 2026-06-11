import { LayoutGrid } from "lucide-react";
import { useMemo } from "react";

import { BentoCard, EmptyState, Spinner, StatusPill, type Tone } from "@/components/avia/ui";
import { useAuth } from "@/hooks/useAuth";
import { formatCost, humanize } from "@/lib/format";
import { useMyBuild, useSpecSelections } from "@/lib/queries";
import type { BuildSpecSelectionRow } from "@/lib/types";

function statusTone(status: string | null | undefined): Tone {
  const s = (status ?? "").toLowerCase();
  if (s.includes("approved")) return "blue";
  if (s.includes("submitted")) return "brown";
  if (s.includes("upgrade")) return "warning";
  return "muted";
}

export default function ClientSelections() {
  const { userId } = useAuth();
  const { data: build, isLoading } = useMyBuild(userId);
  const { data: selections, isLoading: selectionsLoading } = useSpecSelections(build?.id ?? null);

  const rooms = useMemo(() => {
    const map = new Map<string, BuildSpecSelectionRow[]>();
    for (const sel of selections ?? []) {
      const room = sel.snapshot_category_name || "Other";
      const list = map.get(room) ?? [];
      list.push(sel);
      map.set(room, list);
    }
    return Array.from(map.entries());
  }, [selections]);

  if (isLoading || selectionsLoading) return <Spinner />;

  if (!build) {
    return (
      <EmptyState
        icon={LayoutGrid}
        title="Selections Unlock With Your Build"
        subtitle="Once your contract is signed, you'll be able to pick item upgrades and colours together, room by room."
      />
    );
  }

  return (
    <div className="space-y-5">
      <div className="flex items-end justify-between">
        <h1 className="text-[28px] font-medium text-avia-black">Selections</h1>
        {build.spec_tier && <StatusPill label={`${build.spec_tier} range`} tone="brown" />}
      </div>

      {rooms.length === 0 && (
        <EmptyState
          icon={LayoutGrid}
          title="No selections yet"
          subtitle="Your room-by-room selections will appear here once your specification is prepared."
        />
      )}

      <div className="space-y-6">
        {rooms.map(([room, items]) => (
          <div key={room} className="space-y-2.5">
            <div className="flex items-center gap-2">
              <span className="text-[11px] font-medium uppercase tracking-[0.1em] text-avia-black/35">
                {room}
              </span>
              <span className="rounded-full bg-avia-brown/10 px-1.5 py-px text-[10px] font-medium text-avia-brown">
                {items.length}
              </span>
            </div>
            <div className="grid gap-2.5 sm:grid-cols-2">
              {items.map((sel) => (
                <BentoCard key={sel.id} className="flex gap-3.5 p-3.5">
                  <div className="h-16 w-16 shrink-0 overflow-hidden rounded-[10px] bg-avia-elevated">
                    {sel.snapshot_image_url && (
                      <img
                        src={sel.snapshot_image_url}
                        alt={sel.snapshot_name}
                        className="h-full w-full object-cover"
                        loading="lazy"
                      />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="truncate text-[14px] font-medium text-avia-black">
                      {sel.snapshot_name}
                    </div>
                    {sel.snapshot_description && (
                      <div className="mt-0.5 line-clamp-2 text-[12px] text-avia-black/55">
                        {sel.snapshot_description}
                      </div>
                    )}
                    <div className="mt-2 flex flex-wrap items-center gap-1.5">
                      <StatusPill label={humanize(sel.status)} tone={statusTone(sel.status)} />
                      {sel.upgrade_cost !== null && sel.upgrade_cost > 0 && (
                        <span className="text-[12px] font-medium text-avia-brown">
                          +{formatCost(sel.upgrade_cost)}
                        </span>
                      )}
                    </div>
                  </div>
                </BentoCard>
              ))}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
