import type { LucideIcon } from "lucide-react";
import {
  Bell,
  Building2,
  ClipboardList,
  Compass,
  FileText,
  Home,
  LayoutGrid,
  LifeBuoy,
  LogOut,
  MessageSquare,
  MoreHorizontal,
  Package,
  TrendingUp,
  User,
  Users,
} from "lucide-react";
import { useState } from "react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";

import { useAuth } from "@/hooks/useAuth";
import { useRealtimeSync } from "@/hooks/useRealtimeSync";
import { initialsOf } from "@/lib/format";
import { useMyBuild, useNotifications } from "@/lib/queries";
import { canViewPackages, canViewStocklist, isClientRole, isPartnerRole, isStaffRole } from "@/lib/types";
import { cn } from "@/lib/utils";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
}

/**
 * Role-based navigation mirroring the iOS tab layouts:
 * - Client w/ build  → Home, Selections, Progress, More (My Package, Display Homes, Requests…)
 * - Client w/o build → Discover, Packages, Messages, Alerts, More
 * - Staff            → Builds, Packages, Messages, Alerts, More
 * - Admin/SalesAdmin → Workspace, Packages, Stocklist, Messages, Alerts, More
 * - SuperAdmin       → Overview, Workspace, Packages, Stocklist, Messages, More
 * - Partner          → Clients, Packages, Stocklist, Messages, Alerts, More
 */
export default function AppShell() {
  const { role, profile, userId, signOut } = useAuth();
  const navigate = useNavigate();
  const [moreOpen, setMoreOpen] = useState<boolean>(false);
  useRealtimeSync(userId);
  const { data: notifications } = useNotifications(userId);
  const unread = (notifications ?? []).filter((n) => !n.is_read).length;

  const client = isClientRole(role);
  const { data: myBuild, isLoading: buildLoading, isError: buildError } = useMyBuild(client ? userId : null);
  // Treat an unresolved build (still loading OR a failed fetch) as "has build"
  // for navigation, so a transient error never strips a real client of their
  // Selections/Progress/Documents tabs. The pages themselves surface a retry.
  const hasBuild = Boolean(myBuild) || buildLoading || buildError;

  let items: NavItem[];
  let sideItems: NavItem[];

  if (client) {
    if (hasBuild) {
      items = [
        { to: "/home", label: "Home", icon: Home },
        { to: "/selections", label: "Selections", icon: LayoutGrid },
        { to: "/progress", label: "Progress", icon: TrendingUp },
        { to: "/documents", label: "Documents", icon: FileText },
        { to: "/profile", label: "More", icon: User },
      ];
      sideItems = [
        ...items.slice(0, 4),
        { to: "/my-package", label: "My Package", icon: Package },
        { to: "/display-homes", label: "Display Homes", icon: Building2 },
        { to: "/requests", label: "Requests & Support", icon: LifeBuoy },
        { to: "/messages", label: "Messages", icon: MessageSquare },
        { to: "/alerts", label: "Alerts", icon: Bell },
        { to: "/profile", label: "Profile & Settings", icon: User },
      ];
    } else {
      items = [
        { to: "/home", label: "Discover", icon: Compass },
        { to: "/my-package", label: "Packages", icon: Package },
        { to: "/messages", label: "Messages", icon: MessageSquare },
        { to: "/alerts", label: "Alerts", icon: Bell },
        { to: "/profile", label: "More", icon: User },
      ];
      sideItems = [
        { to: "/home", label: "Discover", icon: Compass },
        { to: "/my-package", label: "Packages", icon: Package },
        { to: "/display-homes", label: "Display Homes", icon: Building2 },
        { to: "/requests", label: "Requests & Support", icon: LifeBuoy },
        { to: "/documents", label: "Documents", icon: FileText },
        { to: "/messages", label: "Messages", icon: MessageSquare },
        { to: "/alerts", label: "Alerts", icon: Bell },
        { to: "/profile", label: "Profile & Settings", icon: User },
      ];
    }
  } else if (isStaffRole(role)) {
    items = [
      { to: "/workspace", label: "Builds", icon: Building2 },
      { to: "/packages", label: "Packages", icon: Package },
      { to: "/messages", label: "Messages", icon: MessageSquare },
      { to: "/alerts", label: "Alerts", icon: Bell },
      { to: "/profile", label: "Profile", icon: User },
    ];
    sideItems = [
      ...items.slice(0, 2),
      { to: "/display-homes", label: "Display Homes", icon: Home },
      { to: "/requests", label: "Requests", icon: LifeBuoy },
      ...items.slice(2),
    ];
  } else if (isPartnerRole(role)) {
    items = [
      { to: "/workspace", label: "Clients", icon: Users },
      { to: "/packages", label: "Packages", icon: Package },
      { to: "/stocklist", label: "Stocklist", icon: ClipboardList },
      { to: "/messages", label: "Messages", icon: MessageSquare },
      { to: "/profile", label: "Profile", icon: User },
    ];
    sideItems = [
      ...items.slice(0, 4),
      { to: "/alerts", label: "Alerts", icon: Bell },
      { to: "/profile", label: "Profile", icon: User },
    ];
  } else if (role === "SuperAdmin") {
    items = [
      { to: "/overview", label: "Overview", icon: TrendingUp },
      { to: "/workspace", label: "Workspace", icon: LayoutGrid },
      { to: "/packages", label: "Packages", icon: Package },
      { to: "/stocklist", label: "Stocklist", icon: ClipboardList },
      { to: "/profile", label: "More", icon: User },
    ];
    sideItems = [
      ...items.slice(0, 4),
      { to: "/display-homes", label: "Display Homes", icon: Home },
      { to: "/requests", label: "Requests", icon: LifeBuoy },
      { to: "/messages", label: "Messages", icon: MessageSquare },
      { to: "/alerts", label: "Alerts", icon: Bell },
      { to: "/profile", label: "Profile", icon: User },
    ];
  } else {
    // Admin / SalesAdmin
    items = [
      { to: "/workspace", label: "Workspace", icon: LayoutGrid },
      { to: "/packages", label: "Packages", icon: Package },
      { to: "/stocklist", label: "Stocklist", icon: ClipboardList },
      { to: "/messages", label: "Messages", icon: MessageSquare },
      { to: "/profile", label: "More", icon: User },
    ];
    sideItems = [
      ...items.slice(0, 4),
      { to: "/display-homes", label: "Display Homes", icon: Home },
      { to: "/requests", label: "Requests", icon: LifeBuoy },
      { to: "/alerts", label: "Alerts", icon: Bell },
      { to: "/profile", label: "Profile", icon: User },
    ];
  }

  // Stocklist is admin/partner-only — strip it for anyone else (defensive).
  if (!canViewStocklist(role)) {
    items = items.filter((i) => i.to !== "/stocklist");
    sideItems = sideItems.filter((i) => i.to !== "/stocklist");
  }
  // Packages dead-ends in a redirect for roles that can't view it (e.g.
  // PreConstruction / BuildingSupport staff) — drop the tab for them.
  if (!canViewPackages(role)) {
    items = items.filter((i) => i.to !== "/packages");
    sideItems = sideItems.filter((i) => i.to !== "/packages");
  }

  const displayName = `${profile?.first_name ?? ""} ${profile?.last_name ?? ""}`.trim() || (profile?.email ?? "");

  return (
    <div className="min-h-screen bg-avia-white">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r border-avia-line bg-avia-card md:flex">
        <div className="px-6 pb-4 pt-7">
          <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-7 w-auto opacity-90" />
        </div>
        <nav className="flex-1 space-y-1 overflow-y-auto px-3">
          {sideItems.map((item) => (
            <NavLink
              key={`${item.to}-${item.label}`}
              to={item.to}
              end={item.to === "/home"}
              className={({ isActive }) =>
                cn(
                  "flex items-center gap-3 rounded-[10px] px-3 py-2.5 text-[14px] font-medium transition-colors",
                  isActive
                    ? "bg-avia-brown text-avia-white"
                    : "text-avia-black/60 hover:bg-avia-black/5 hover:text-avia-black",
                )
              }
            >
              <item.icon className="h-[18px] w-[18px]" />
              <span className="flex-1">{item.label}</span>
              {item.to === "/alerts" && unread > 0 && (
                <span className="rounded-full bg-avia-brown/80 px-1.5 py-px text-[10px] font-medium text-avia-white">
                  {unread}
                </span>
              )}
            </NavLink>
          ))}
        </nav>
        <div className="border-t border-avia-line p-4">
          <div className="flex items-center gap-3">
            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-gradient-to-br from-avia-black to-avia-brown text-[11px] font-medium text-avia-white">
              {initialsOf(profile?.first_name, profile?.last_name)}
            </div>
            <div className="min-w-0 flex-1">
              <div className="truncate text-[13px] font-medium text-avia-black">{displayName}</div>
              <div className="truncate text-[11px] text-avia-black/45">{role}</div>
            </div>
            <button
              type="button"
              aria-label="Sign out"
              onClick={() => {
                void signOut().then(() => navigate("/login"));
              }}
              className="rounded-full p-2 text-avia-black/45 transition-colors hover:bg-avia-black/5 hover:text-avia-black"
            >
              <LogOut className="h-4 w-4" />
            </button>
          </div>
        </div>
      </aside>

      {/* Mobile header */}
      <header className="sticky top-0 z-30 flex items-center justify-between border-b border-avia-line bg-avia-white/90 px-4 py-3 backdrop-blur md:hidden">
        <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-6 w-auto" />
        <div className="flex items-center gap-1">
          <NavLink to="/messages" aria-label="Messages" className="rounded-full p-2 text-avia-brown hover:bg-avia-brown/10">
            <MessageSquare className="h-5 w-5" />
          </NavLink>
          <NavLink to="/alerts" aria-label="Alerts" className="relative rounded-full p-2 text-avia-brown hover:bg-avia-brown/10">
            <Bell className="h-5 w-5" />
            {unread > 0 && (
              <span className="absolute right-1 top-1 flex h-4 min-w-4 items-center justify-center rounded-full bg-avia-brown px-1 text-[9px] font-medium text-avia-white">
                {unread}
              </span>
            )}
          </NavLink>
        </div>
      </header>

      {/* Content */}
      <main className="px-4 pb-28 pt-4 md:ml-60 md:px-8 md:pb-12 md:pt-8">
        <div className="mx-auto w-full max-w-5xl">
          <Outlet />
        </div>
      </main>

      {/* Mobile bottom tabs. The /profile tab becomes a "More" trigger so every
          secondary destination stays reachable on a phone. */}
      <nav className="fixed inset-x-0 bottom-0 z-30 flex border-t border-avia-line bg-avia-card pb-[env(safe-area-inset-bottom)] md:hidden">
        {items.map((item) =>
          item.to === "/profile" ? (
            <button
              key="more-tab"
              type="button"
              onClick={() => setMoreOpen(true)}
              aria-label="More"
              className="relative flex flex-1 flex-col items-center gap-1 py-2.5 text-[10px] font-medium text-avia-black/40 transition-colors"
            >
              <MoreHorizontal className="h-5 w-5" />
              More
            </button>
          ) : (
            <NavLink
              key={`${item.to}-${item.label}`}
              to={item.to}
              className={({ isActive }) =>
                cn(
                  "relative flex flex-1 flex-col items-center gap-1 py-2.5 text-[10px] font-medium transition-colors",
                  isActive ? "text-avia-brown" : "text-avia-black/40",
                )
              }
            >
              <item.icon className="h-5 w-5" />
              {item.label}
              {item.to === "/alerts" && unread > 0 && (
                <span className="absolute right-[calc(50%-16px)] top-1 flex h-3.5 min-w-3.5 items-center justify-center rounded-full bg-avia-brown px-1 text-[8px] font-medium text-avia-white">
                  {unread}
                </span>
              )}
            </NavLink>
          ),
        )}
      </nav>

      {/* Mobile "More" sheet — surfaces every secondary destination (My Package,
          Display Homes, Requests, Messages, Alerts, Profile…) that doesn't fit in
          the bottom tab bar, so nothing is unreachable on a phone. */}
      {moreOpen && (
        <div className="fixed inset-0 z-40 md:hidden" role="dialog" aria-modal="true" aria-label="More menu">
          <button
            type="button"
            aria-label="Close menu"
            onClick={() => setMoreOpen(false)}
            className="absolute inset-0 bg-avia-black/40 backdrop-blur-[2px]"
          />
          <div className="absolute inset-x-0 bottom-0 max-h-[80vh] overflow-y-auto rounded-t-[20px] bg-avia-card p-4 pb-[calc(env(safe-area-inset-bottom)+1rem)] shadow-2xl">
            <div className="mx-auto mb-4 h-1 w-10 rounded-full bg-avia-black/15" />
            <div className="grid grid-cols-1 gap-1">
              {sideItems.map((item) => (
                <NavLink
                  key={`more-${item.to}-${item.label}`}
                  to={item.to}
                  end={item.to === "/home"}
                  onClick={() => setMoreOpen(false)}
                  className={({ isActive }) =>
                    cn(
                      "flex items-center gap-3 rounded-[12px] px-3 py-3 text-[15px] font-medium transition-colors",
                      isActive ? "bg-avia-brown text-avia-white" : "text-avia-black/70 hover:bg-avia-black/5",
                    )
                  }
                >
                  <item.icon className="h-[18px] w-[18px]" />
                  <span className="flex-1">{item.label}</span>
                  {item.to === "/alerts" && unread > 0 && (
                    <span className="rounded-full bg-avia-brown/80 px-1.5 py-px text-[10px] font-medium text-avia-white">
                      {unread}
                    </span>
                  )}
                </NavLink>
              ))}
              <button
                type="button"
                onClick={() => {
                  setMoreOpen(false);
                  void signOut().then(() => navigate("/login"));
                }}
                className="mt-1 flex items-center gap-3 rounded-[12px] px-3 py-3 text-left text-[15px] font-medium text-avia-black/70 transition-colors hover:bg-avia-black/5"
              >
                <LogOut className="h-[18px] w-[18px]" />
                Sign out
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
