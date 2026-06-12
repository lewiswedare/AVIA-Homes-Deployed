import { Home, PackageOpen, SlidersHorizontal } from "lucide-react";
import { useMemo, useState } from "react";
import { Link, Navigate } from "react-router-dom";

import { EmptyState, MetricCard, Spinner } from "@/components/avia/ui";
import { PackageCard } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import { estateOf, visiblePackages } from "@/lib/catalog";
import { usePackageAssignments, usePackages } from "@/lib/queries";
import { canManagePackages, canViewPackages, isClientRole } from "@/lib/types";
import { cn } from "@/lib/utils";

/**
 * Packages catalog — mirrors the iOS PackagesContentView (summary cards,
 * estate filter, role-scoped grid). Clients are routed to their review page.
 */
export default function Packages() {
  const { role, userId } = useAuth();
  const packagesQ = usePackages();
  const assignmentsQ = usePackageAssignments();
  const [estate, setEstate] = useState<string>("");

  const packages = useMemo(
    () => visiblePackages(role, userId, packagesQ.data, assignmentsQ.data),
    [role, userId, packagesQ.data, assignmentsQ.data],
  );

  const estates = useMemo(
    () => Array.from(new Set(packages.map((p) => estateOf(p)).filter(Boolean))).sort(),
    [packages],
  );

  const filtered = useMemo(
    () => (estate ? packages.filter((p) => estateOf(p) === estate) : packages),
    [packages, estate],
  );

  if (isClientRole(role)) return <Navigate to="/my-package" replace />;
  if (!canViewPackages(role)) return <Navigate to="/" replace />;
  if (packagesQ.isLoading || assignmentsQ.isLoading) return <Spinner />;

  return (
    <div className="animate-fade-in space-y-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[26px] font-medium text-avia-black">
            {role === "Partner" || role === "SalesPartner" ? "My Packages" : "Packages"}
          </h1>
          <p className="text-[13px] text-avia-black/50">House & land packages across our estates</p>
        </div>
        {canManagePackages(role) && (
          <Link
            to="/packages/manage"
            className="flex items-center gap-2 rounded-full border border-avia-brown/30 px-4 py-2 text-[13px] font-medium text-avia-brown transition-colors hover:bg-avia-brown/10"
          >
            <SlidersHorizontal className="h-4 w-4" />
            Manage
          </Link>
        )}
      </div>

      <div className="grid grid-cols-2 gap-3">
        <MetricCard value={String(packages.length)} label="Total Packages" icon={PackageOpen} />
        <MetricCard value={String(packages.length)} label="Available Now" icon={Home} tone="blue" />
      </div>

      {estates.length > 0 && (
        <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
          <FilterChip label="All Estates" active={estate === ""} onClick={() => setEstate("")} />
          {estates.map((e) => (
            <FilterChip key={e} label={e} active={estate === e} onClick={() => setEstate(e)} />
          ))}
        </div>
      )}

      <div className="text-[12px] font-medium uppercase tracking-wider text-avia-black/35">
        {filtered.length} package{filtered.length === 1 ? "" : "s"}
      </div>

      {filtered.length === 0 ? (
        <EmptyState
          icon={PackageOpen}
          title="No packages found"
          subtitle={
            role === "Partner" || role === "SalesPartner"
              ? "Packages assigned to you will appear here."
              : "Adjust the filters or check back soon."
          }
        />
      ) : (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {filtered.map((pkg) => (
            <PackageCard key={pkg.id} pkg={pkg} />
          ))}
        </div>
      )}
    </div>
  );
}

function FilterChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "whitespace-nowrap rounded-full border px-3.5 py-1.5 text-[12px] font-medium transition-colors",
        active
          ? "border-avia-brown bg-avia-brown text-avia-white"
          : "border-avia-line bg-avia-card text-avia-black/60 hover:border-avia-brown/40",
      )}
    >
      {label}
    </button>
  );
}
