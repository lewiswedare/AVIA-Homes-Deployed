import type { LucideIcon } from "lucide-react";
import {
  Bell,
  FileText,
  Home,
  LayoutGrid,
  LogOut,
  MessageSquare,
  TrendingUp,
  User,
} from "lucide-react";
import { NavLink, Outlet, useNavigate } from "react-router-dom";

import { useAuth } from "@/hooks/useAuth";
import { useRealtimeSync } from "@/hooks/useRealtimeSync";
import { initialsOf } from "@/lib/format";
import { useNotifications } from "@/lib/queries";
import { isClientRole } from "@/lib/types";
import { cn } from "@/lib/utils";

interface NavItem {
  to: string;
  label: string;
  icon: LucideIcon;
}

export default function AppShell() {
  const { role, profile, userId, signOut } = useAuth();
  const navigate = useNavigate();
  useRealtimeSync(userId);
  const { data: notifications } = useNotifications(userId);
  const unread = (notifications ?? []).filter((n) => !n.is_read).length;

  const client = isClientRole(role);

  const items: NavItem[] = client
    ? [
        { to: "/home", label: "Home", icon: Home },
        { to: "/selections", label: "Selections", icon: LayoutGrid },
        { to: "/progress", label: "Progress", icon: TrendingUp },
        { to: "/documents", label: "Documents", icon: FileText },
        { to: "/profile", label: "More", icon: User },
      ]
    : [
        { to: "/workspace", label: "Workspace", icon: LayoutGrid },
        { to: "/messages", label: "Messages", icon: MessageSquare },
        { to: "/alerts", label: "Alerts", icon: Bell },
        { to: "/profile", label: "Profile", icon: User },
      ];

  const sideItems: NavItem[] = client
    ? [
        ...items.slice(0, 4),
        { to: "/messages", label: "Messages", icon: MessageSquare },
        { to: "/alerts", label: "Alerts", icon: Bell },
        { to: "/profile", label: "Profile & Settings", icon: User },
      ]
    : items;

  const displayName = `${profile?.first_name ?? ""} ${profile?.last_name ?? ""}`.trim() || (profile?.email ?? "");

  return (
    <div className="min-h-screen bg-avia-white">
      {/* Desktop sidebar */}
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-60 flex-col border-r border-avia-line bg-avia-card md:flex">
        <div className="px-6 pb-4 pt-7">
          <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-7 w-auto opacity-90" />
        </div>
        <nav className="flex-1 space-y-1 px-3">
          {sideItems.map((item) => (
            <NavLink
              key={item.to}
              to={item.to}
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
          <NavLink to="/messages" className="rounded-full p-2 text-avia-brown hover:bg-avia-brown/10">
            <MessageSquare className="h-5 w-5" />
          </NavLink>
          <NavLink to="/alerts" className="relative rounded-full p-2 text-avia-brown hover:bg-avia-brown/10">
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

      {/* Mobile bottom tabs */}
      <nav className="fixed inset-x-0 bottom-0 z-30 flex border-t border-avia-line bg-avia-card pb-[env(safe-area-inset-bottom)] md:hidden">
        {items.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              cn(
                "flex flex-1 flex-col items-center gap-1 py-2.5 text-[10px] font-medium transition-colors",
                isActive ? "text-avia-brown" : "text-avia-black/40",
              )
            }
          >
            <item.icon className="h-5 w-5" />
            {item.label}
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
