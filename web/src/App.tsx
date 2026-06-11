import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";
import { BrowserRouter, Navigate, Outlet, Route, Routes } from "react-router-dom";

import AppShell from "@/components/AppShell";
import { Toaster as Sonner } from "@/components/ui/sonner";
import { TooltipProvider } from "@/components/ui/tooltip";
import { AuthProvider, useAuth } from "@/hooks/useAuth";
import { isClientRole } from "@/lib/types";

import ClientRecord from "./pages/ClientRecord";
import ForgotPassword from "./pages/ForgotPassword";
import Login from "./pages/Login";
import Messages from "./pages/Messages";
import NotFound from "./pages/NotFound";
import Notifications from "./pages/Notifications";
import Profile from "./pages/Profile";
import ProfileSetup from "./pages/ProfileSetup";
import SignUp from "./pages/SignUp";
import Workspace from "./pages/Workspace";
import ClientDashboard from "./pages/client/ClientDashboard";
import ClientDocuments from "./pages/client/ClientDocuments";
import ClientProgress from "./pages/client/ClientProgress";
import ClientSelections from "./pages/client/ClientSelections";

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 1,
      staleTime: 15000,
    },
  },
});

function Splash() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-10 bg-avia-white">
      <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-10 w-auto" />
      <Loader2 className="h-6 w-6 animate-spin text-avia-brown" />
    </div>
  );
}

function Protected() {
  const { session, restoring, profile, profileLoading } = useAuth();

  if (restoring) return <Splash />;
  if (!session) return <Navigate to="/login" replace />;
  if (profileLoading && !profile) return <Splash />;
  if (!profile || !profile.profile_completed) return <ProfileSetup />;
  return <Outlet />;
}

function RoleHome() {
  const { role } = useAuth();
  return <Navigate to={isClientRole(role) ? "/home" : "/workspace"} replace />;
}

const App = () => (
  <QueryClientProvider client={queryClient}>
    <TooltipProvider>
      <Sonner position="top-center" />
      <AuthProvider>
        <BrowserRouter>
          <Routes>
            <Route path="/login" element={<Login />} />
            <Route path="/signup" element={<SignUp />} />
            <Route path="/forgot-password" element={<ForgotPassword />} />
            <Route element={<Protected />}>
              <Route element={<AppShell />}>
                <Route path="/" element={<RoleHome />} />
                <Route path="/home" element={<ClientDashboard />} />
                <Route path="/selections" element={<ClientSelections />} />
                <Route path="/progress" element={<ClientProgress />} />
                <Route path="/documents" element={<ClientDocuments />} />
                <Route path="/workspace" element={<Workspace />} />
                <Route path="/clients/:clientId" element={<ClientRecord />} />
                <Route path="/messages" element={<Messages />} />
                <Route path="/alerts" element={<Notifications />} />
                <Route path="/profile" element={<Profile />} />
              </Route>
            </Route>
            <Route path="*" element={<NotFound />} />
          </Routes>
        </BrowserRouter>
      </AuthProvider>
    </TooltipProvider>
  </QueryClientProvider>
);

export default App;
