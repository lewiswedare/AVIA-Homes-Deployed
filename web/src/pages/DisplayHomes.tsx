import { useMutation, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  Bath,
  BedDouble,
  CalendarCheck,
  CalendarDays,
  Car,
  Check,
  ChevronLeft,
  ChevronRight,
  Clock,
  Home,
  MapPin,
  Maximize,
  Phone,
  Users,
} from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";

import {
  BentoCard,
  EmptyState,
  FieldLabel,
  Modal,
  PrimaryButton,
  SecondaryButton,
  Spinner,
  StatusPill,
  inputClass,
} from "@/components/avia/ui";
import { CatalogSection, CoverImage } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import { fmtDateTime, fullNameOf, nowISO } from "@/lib/format";
import { useDisplayHomes, useMyVisits } from "@/lib/queries";
import { supabase } from "@/lib/supabase";
import type { DisplayHomeRow, VisitStatusKey } from "@/lib/types";
import { isClientRole, visitStatusLabel } from "@/lib/types";

/** Display homes — /display-homes list and /display-homes/:id detail (iOS parity). */
export default function DisplayHomes() {
  const { id } = useParams<{ id?: string }>();
  const { role, userId } = useAuth();
  const homesQ = useDisplayHomes(!isClientRole(role));
  const visitsQ = useMyVisits(userId);
  const [visitsOpen, setVisitsOpen] = useState<boolean>(false);

  const upcoming = useMemo(
    () =>
      (visitsQ.data ?? []).filter(
        (v) => ["pending", "confirmed"].includes(v.status) && new Date(v.requested_at).getTime() > Date.now(),
      ),
    [visitsQ.data],
  );

  if (homesQ.isLoading) return <Spinner />;
  if (id) {
    const home = (homesQ.data ?? []).find((h) => h.id === id) ?? null;
    if (!home) return <EmptyState icon={Home} title="Display home not found" />;
    return <DisplayHomeDetail home={home} />;
  }

  const homes = homesQ.data ?? [];

  return (
    <div className="animate-fade-in space-y-5">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h1 className="text-[26px] font-medium text-avia-black">Display Homes</h1>
          <p className="text-[13px] text-avia-black/50">Walk through our designs in person</p>
        </div>
        {isClientRole(role) && (
          <button
            type="button"
            onClick={() => setVisitsOpen(true)}
            className="flex items-center gap-1.5 rounded-full border border-avia-brown/30 px-4 py-2 text-[13px] font-medium text-avia-brown transition-colors hover:bg-avia-brown/10"
          >
            <CalendarDays className="h-4 w-4" /> My Visits
          </button>
        )}
      </div>

      <BentoCard className="flex items-start gap-3 p-4">
        <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-avia-brown/10 text-avia-brown">
          <Home className="h-5 w-5" />
        </div>
        <div>
          <div className="text-[14px] font-medium text-avia-black">Visit a Display Home</div>
          <p className="text-[12px] text-avia-black/55">
            Experience the quality and finishes first-hand. Book a time and our team will be ready to walk you through.
          </p>
        </div>
      </BentoCard>

      {upcoming.length > 0 && (
        <button
          type="button"
          onClick={() => setVisitsOpen(true)}
          className="flex w-full items-center gap-3 rounded-[13px] border border-avia-brown/25 bg-avia-brown/10 p-4 text-left"
        >
          <CalendarCheck className="h-5 w-5 text-avia-brown" />
          <span className="flex-1 text-[14px] font-medium text-avia-brown">
            {upcoming.length} upcoming visit{upcoming.length === 1 ? "" : "s"} — tap to view your bookings
          </span>
          <ChevronRight className="h-4 w-4 text-avia-brown" />
        </button>
      )}

      {homes.length === 0 ? (
        <EmptyState icon={Home} title="No display homes open right now" subtitle="Check back soon — new displays are on the way." />
      ) : (
        <div className="grid gap-4 sm:grid-cols-2">
          {homes.map((home) => (
            <DisplayHomeCard key={home.id} home={home} />
          ))}
        </div>
      )}

      {visitsOpen && <MyVisitsModal onClose={() => setVisitsOpen(false)} homes={homes} />}
    </div>
  );
}

function DisplayHomeCard({ home }: { home: DisplayHomeRow }) {
  const navigate = useNavigate();
  return (
    <button type="button" onClick={() => navigate(`/display-homes/${encodeURIComponent(home.id)}`)} className="block w-full text-left">
      <BentoCard className="overflow-hidden transition-transform hover:-translate-y-0.5">
        <CoverImage src={home.image_urls?.[0]} alt={home.name} className="h-44">
          {home.estate && (
            <span className="absolute left-3 top-3 rounded-full bg-avia-black/50 px-2.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-white backdrop-blur">
              {home.estate}
            </span>
          )}
          {!home.is_active && (
            <span className="absolute right-3 top-3 rounded-full bg-avia-black/60 px-2.5 py-0.5 text-[10px] font-medium text-white backdrop-blur">
              Inactive
            </span>
          )}
        </CoverImage>
        <div className="space-y-1.5 p-4">
          <div className="text-[15px] font-medium text-avia-black">{home.name}</div>
          {(home.address || home.suburb) && (
            <div className="flex items-center gap-1 text-[12px] text-avia-black/50">
              <MapPin className="h-3.5 w-3.5" /> {[home.address, home.suburb].filter(Boolean).join(", ")}
            </div>
          )}
          <div className="flex flex-wrap items-center gap-3 text-[12px] text-avia-black/60">
            {home.bedrooms != null && <span className="flex items-center gap-1"><BedDouble className="h-3.5 w-3.5" />{home.bedrooms}</span>}
            {home.bathrooms != null && <span className="flex items-center gap-1"><Bath className="h-3.5 w-3.5" />{home.bathrooms}</span>}
            {home.garages != null && <span className="flex items-center gap-1"><Car className="h-3.5 w-3.5" />{home.garages}</span>}
            {home.opening_hours && <span className="flex items-center gap-1"><Clock className="h-3.5 w-3.5" />{home.opening_hours}</span>}
          </div>
        </div>
      </BentoCard>
    </button>
  );
}

function DisplayHomeDetail({ home }: { home: DisplayHomeRow }) {
  const navigate = useNavigate();
  const { role } = useAuth();
  const [imageIndex, setImageIndex] = useState<number>(0);
  const [bookingOpen, setBookingOpen] = useState<boolean>(false);

  const images = home.image_urls ?? [];

  return (
    <div className="animate-fade-in space-y-5 pb-24">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <BentoCard className="overflow-hidden">
        <CoverImage src={images[imageIndex]} alt={home.name} className="h-64 sm:h-80">
          {images.length > 1 && (
            <>
              <button
                type="button"
                aria-label="Previous image"
                onClick={() => setImageIndex((imageIndex - 1 + images.length) % images.length)}
                className="absolute left-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur"
              >
                <ChevronLeft className="h-4 w-4" />
              </button>
              <button
                type="button"
                aria-label="Next image"
                onClick={() => setImageIndex((imageIndex + 1) % images.length)}
                className="absolute right-2 top-1/2 -translate-y-1/2 rounded-full bg-avia-black/40 p-2 text-white backdrop-blur"
              >
                <ChevronRight className="h-4 w-4" />
              </button>
              <span className="absolute bottom-2 right-3 rounded-full bg-avia-black/50 px-2 py-0.5 text-[11px] text-white backdrop-blur">
                {imageIndex + 1} / {images.length}
              </span>
            </>
          )}
        </CoverImage>
      </BentoCard>

      <div>
        <div className="flex items-center gap-2">
          <h1 className="text-[26px] font-medium text-avia-black">{home.name}</h1>
          {home.estate && <StatusPill label={home.estate} />}
        </div>
        {(home.address || home.suburb) && (
          <div className="mt-1 flex items-center gap-1 text-[13px] text-avia-black/55">
            <MapPin className="h-4 w-4" /> {[home.address, home.suburb].filter(Boolean).join(", ")}
          </div>
        )}
      </div>

      <div className="grid grid-cols-4 gap-3">
        {home.bedrooms != null && <StatBox icon={BedDouble} value={String(home.bedrooms)} label="Beds" />}
        {home.bathrooms != null && <StatBox icon={Bath} value={String(home.bathrooms)} label="Baths" />}
        {home.garages != null && <StatBox icon={Car} value={String(home.garages)} label="Garage" />}
        {home.square_meters != null && <StatBox icon={Maximize} value={`${home.square_meters}`} label="m²" />}
      </div>

      {(home.opening_hours || home.contact_phone) && (
        <BentoCard className="divide-y divide-avia-line/60 px-4">
          {home.opening_hours && (
            <div className="flex items-center gap-3 py-3.5">
              <Clock className="h-4 w-4 text-avia-brown" />
              <div>
                <div className="text-[13px] font-medium text-avia-black">Opening Hours</div>
                <div className="text-[12px] text-avia-black/55">{home.opening_hours}</div>
              </div>
            </div>
          )}
          {home.contact_phone && (
            <a href={`tel:${home.contact_phone}`} className="flex items-center gap-3 py-3.5">
              <Phone className="h-4 w-4 text-avia-brown" />
              <div>
                <div className="text-[13px] font-medium text-avia-black">Call the Display Home</div>
                <div className="text-[12px] text-avia-brown">{home.contact_phone}</div>
              </div>
            </a>
          )}
        </BentoCard>
      )}

      {home.description && (
        <CatalogSection title="About this display">
          <BentoCard className="p-4">
            <p className="text-[14px] leading-relaxed text-avia-black/70">{home.description}</p>
          </BentoCard>
        </CatalogSection>
      )}

      {(home.features ?? []).length > 0 && (
        <CatalogSection title="Features">
          <BentoCard className="px-4 py-2">
            {(home.features ?? []).map((f, i) => (
              <div key={`${f}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                <span className="text-[13px] text-avia-black/75">{f}</span>
              </div>
            ))}
          </BentoCard>
        </CatalogSection>
      )}

      {isClientRole(role) && (
        <div className="fixed inset-x-4 bottom-20 z-20 mx-auto max-w-5xl md:inset-x-auto md:bottom-8 md:left-[calc(50%+7.5rem)] md:w-96 md:-translate-x-1/2">
          <PrimaryButton onClick={() => setBookingOpen(true)} className="shadow-xl">
            <CalendarDays className="h-4 w-4" /> Schedule a Visit
          </PrimaryButton>
        </div>
      )}

      {bookingOpen && <BookVisitModal home={home} onClose={() => setBookingOpen(false)} />}
    </div>
  );
}

function StatBox({ icon: Icon, value, label }: { icon: typeof BedDouble; value: string; label: string }) {
  return (
    <BentoCard className="flex flex-col items-center gap-1 py-3.5">
      <Icon className="h-4 w-4 text-avia-brown" />
      <span className="text-[16px] font-medium text-avia-black">{value}</span>
      <span className="text-[10px] font-medium uppercase tracking-wider text-avia-black/40">{label}</span>
    </BentoCard>
  );
}

function defaultVisitTime(): string {
  const d = new Date();
  d.setDate(d.getDate() + 1);
  d.setHours(11, 0, 0, 0);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function BookVisitModal({ home, onClose }: { home: DisplayHomeRow; onClose: () => void }) {
  const { userId, profile } = useAuth();
  const queryClient = useQueryClient();
  const [when, setWhen] = useState<string>(defaultVisitTime());
  const [party, setParty] = useState<number>(2);
  const [name, setName] = useState<string>(profile ? fullNameOf(profile) : "");
  const [email, setEmail] = useState<string>(profile?.email ?? "");
  const [phone, setPhone] = useState<string>(profile?.phone ?? "");
  const [notes, setNotes] = useState<string>("");

  const book = useMutation({
    mutationFn: async () => {
      if (!name.trim() || !email.trim()) throw new Error("Name and email are required");
      const requested = new Date(when);
      if (Number.isNaN(requested.getTime()) || requested.getTime() < Date.now()) throw new Error("Pick a future date and time");
      const { error } = await supabase.from("display_home_visits").insert({
        id: crypto.randomUUID(),
        display_home_id: home.id,
        client_id: userId,
        requested_at: requested.toISOString(),
        duration_minutes: 45,
        status: "pending",
        attendee_name: name.trim(),
        attendee_email: email.trim(),
        attendee_phone: phone.trim() || null,
        party_size: party,
        notes: notes.trim() || null,
        created_at: nowISO(),
        updated_at: nowISO(),
      });
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["display_home_visits"] });
      toast.success("Visit requested — we'll confirm shortly. Track it in My Visits.");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <Modal open onClose={onClose} title={`Schedule a Visit — ${home.name}`}>
      <div className="space-y-1.5">
        <FieldLabel>Date & Time</FieldLabel>
        <input className={inputClass} type="datetime-local" value={when} min={defaultVisitTime()} onChange={(e) => setWhen(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Party Size</FieldLabel>
        <div className="flex items-center gap-3">
          <SecondaryButton onClick={() => setParty(Math.max(1, party - 1))} className="h-10 w-10 flex-none">−</SecondaryButton>
          <span className="flex items-center gap-1.5 text-[15px] font-medium text-avia-black">
            <Users className="h-4 w-4 text-avia-brown" /> {party}
          </span>
          <SecondaryButton onClick={() => setParty(Math.min(10, party + 1))} className="h-10 w-10 flex-none">+</SecondaryButton>
        </div>
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Full Name</FieldLabel>
        <input className={inputClass} value={name} onChange={(e) => setName(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Email</FieldLabel>
        <input className={inputClass} type="email" value={email} onChange={(e) => setEmail(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Phone</FieldLabel>
        <input className={inputClass} type="tel" value={phone} onChange={(e) => setPhone(e.target.value)} />
      </div>
      <div className="space-y-1.5">
        <FieldLabel>Notes (optional)</FieldLabel>
        <textarea className={`${inputClass} min-h-20 resize-y`} value={notes} onChange={(e) => setNotes(e.target.value)} />
      </div>
      <PrimaryButton onClick={() => book.mutate()} loading={book.isPending} disabled={!name.trim() || !email.trim()}>
        Request Visit
      </PrimaryButton>
    </Modal>
  );
}

function MyVisitsModal({ onClose, homes }: { onClose: () => void; homes: DisplayHomeRow[] }) {
  const { userId } = useAuth();
  const visitsQ = useMyVisits(userId);
  const queryClient = useQueryClient();

  const cancel = useMutation({
    mutationFn: async (visitId: string) => {
      const { error } = await supabase
        .from("display_home_visits")
        .update({ status: "cancelled", cancelled_at: nowISO(), updated_at: nowISO() })
        .eq("id", visitId);
      if (error) throw error;
    },
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ["display_home_visits"] });
      toast.success("Visit cancelled");
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const visits = visitsQ.data ?? [];
  const homeName = (id: string) => homes.find((h) => h.id === id)?.name ?? "Display Home";
  const statusTone = (s: string) => (s === "confirmed" ? "brown" : s === "pending" ? "warning" : "muted");

  return (
    <Modal open onClose={onClose} title="My Visits">
      {visits.length === 0 && <div className="py-8 text-center text-[13px] text-avia-black/45">No visit bookings yet</div>}
      <div className="max-h-96 space-y-2 overflow-y-auto">
        {visits.map((v) => {
          const future = new Date(v.requested_at).getTime() > Date.now();
          const cancellable = ["pending", "confirmed"].includes(v.status) && future;
          return (
            <div key={v.id} className="space-y-2 rounded-[12px] bg-avia-card p-3.5">
              <div className="flex items-center justify-between gap-2">
                <div className="min-w-0">
                  <div className="truncate text-[14px] font-medium text-avia-black">{homeName(v.display_home_id)}</div>
                  <div className="text-[12px] text-avia-black/50">{fmtDateTime(v.requested_at)}</div>
                </div>
                <StatusPill label={visitStatusLabel[v.status as VisitStatusKey] ?? v.status} tone={statusTone(v.status)} />
              </div>
              {v.notes && <div className="text-[12px] text-avia-black/55">{v.notes}</div>}
              {cancellable && (
                <button
                  type="button"
                  disabled={cancel.isPending}
                  onClick={() => cancel.mutate(v.id)}
                  className="text-[12px] font-medium text-red-700 disabled:opacity-50"
                >
                  Cancel Visit
                </button>
              )}
            </div>
          );
        })}
      </div>
    </Modal>
  );
}
