import { useMutation } from "@tanstack/react-query";
import {
  ArrowLeft,
  Bath,
  BedDouble,
  Car,
  Check,
  Download,
  FileText,
  Home,
  Layers,
  Leaf,
  Phone,
  ShieldCheck,
  Sofa,
  XCircle,
} from "lucide-react";
import { useMemo, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { toast } from "sonner";

import { BentoCard, EmptyState, FieldLabel, Modal, PrimaryButton, Spinner, inputClass } from "@/components/avia/ui";
import { CatalogSection, CoverImage, DetailRow } from "@/components/catalog/shared";
import { useAuth } from "@/hooks/useAuth";
import { fullNameOf, nowISO } from "@/lib/format";
import { useHomeDesigns } from "@/lib/queries";
import { supabase } from "@/lib/supabase";

const KEY_FEATURES: { icon: typeof Home; title: string; subtitle: string }[] = [
  { icon: Home, title: "Multiple Facades", subtitle: "Choose a look that suits your street" },
  { icon: Layers, title: "3 Spec Levels", subtitle: "Volos, Messina & Portobello" },
  { icon: Leaf, title: "Energy Efficient", subtitle: "Designed for Queensland living" },
  { icon: ShieldCheck, title: "HIA Warranty", subtitle: "Built with confidence" },
];

/** Home design detail — mirrors iOS HomeDesignDetailView. */
export default function DesignDetail() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const designsQ = useHomeDesigns();
  const [floorplanOpen, setFloorplanOpen] = useState<boolean>(false);
  const [enquiryOpen, setEnquiryOpen] = useState<boolean>(false);

  const design = useMemo(() => (designsQ.data ?? []).find((d) => d.id === id) ?? null, [designsQ.data, id]);

  if (designsQ.isLoading) return <Spinner />;
  if (!design) return <EmptyState icon={XCircle} title="Design not found" />;

  return (
    <div className="animate-fade-in space-y-5">
      <button
        type="button"
        onClick={() => navigate(-1)}
        className="flex items-center gap-1.5 text-[13px] font-medium text-avia-black/55 transition-colors hover:text-avia-black"
      >
        <ArrowLeft className="h-4 w-4" /> Back
      </button>

      <BentoCard className="overflow-hidden">
        <CoverImage src={design.image_url} alt={design.name} className="h-64 sm:h-96">
          <div className="absolute inset-x-0 bottom-0 bg-gradient-to-t from-avia-black/70 to-transparent p-5 pt-16">
            <h1 className="text-[28px] font-medium text-white">{design.name}</h1>
            <div className="text-[14px] text-white/80">{design.square_meters}m² · {design.storeys === 2 ? "Double" : "Single"} storey</div>
          </div>
        </CoverImage>
      </BentoCard>

      <div className="grid gap-5 lg:grid-cols-[2fr,1fr]">
        <div className="space-y-5">
          {design.description && (
            <CatalogSection title="About This Design">
              <BentoCard className="p-4">
                <p className="text-[14px] leading-relaxed text-avia-black/70">{design.description}</p>
              </BentoCard>
            </CatalogSection>
          )}

          <div className="grid grid-cols-4 gap-3">
            <QuickStat icon={BedDouble} value={String(design.bedrooms)} label="Bed" />
            <QuickStat icon={Bath} value={String(design.bathrooms)} label="Bath" />
            <QuickStat icon={Car} value={String(design.garages)} label="Car" />
            <QuickStat icon={Sofa} value={String(design.living_areas ?? 1)} label="Living" />
          </div>

          <div className="scrollbar-none flex gap-2 overflow-x-auto pb-1">
            {design.house_width != null && <DimChip label="Width" value={`${design.house_width}m`} />}
            {design.house_length != null && <DimChip label="Length" value={`${design.house_length}m`} />}
            <DimChip label="Total" value={`${design.square_meters}m²`} />
            {design.lot_width != null && <DimChip label="Min lot width" value={`${design.lot_width}m`} />}
          </div>

          {(design.floorplan_image_url ?? design.image_url) && (
            <CatalogSection title="Floor Plan">
              <button type="button" onClick={() => setFloorplanOpen(true)} className="block w-full">
                <BentoCard className="overflow-hidden bg-avia-brown p-4 transition-transform hover:-translate-y-0.5">
                  <img
                    src={design.floorplan_image_url ?? design.image_url}
                    alt={`${design.name} floor plan`}
                    className="mx-auto max-h-[360px] w-auto object-contain"
                    loading="lazy"
                  />
                  <div className="mt-3 text-center text-[12px] font-medium text-white/75">Tap to view full screen</div>
                </BentoCard>
              </button>
            </CatalogSection>
          )}

          {design.floorplan_pdf_url && (
            <BentoCard className="flex items-center gap-3 p-4">
              <div className="flex h-11 w-11 items-center justify-center rounded-[10px] bg-avia-brown/10 text-avia-brown">
                <FileText className="h-5 w-5" />
              </div>
              <div className="min-w-0 flex-1">
                <div className="text-[14px] font-medium text-avia-black">{design.name} Floor Plan PDF</div>
                <div className="text-[12px] text-avia-black/50">Detailed dimensions & layout</div>
              </div>
              <a
                href={design.floorplan_pdf_url}
                target="_blank"
                rel="noreferrer"
                className="flex items-center gap-1.5 rounded-full bg-avia-brown px-4 py-2 text-[13px] font-medium text-white transition-opacity hover:opacity-90"
              >
                <Download className="h-4 w-4" /> Download
              </a>
            </BentoCard>
          )}

          {(design.room_highlights ?? []).length > 0 && (
            <CatalogSection title="Room Highlights">
              <BentoCard className="px-4 py-2">
                {(design.room_highlights ?? []).map((h, i) => (
                  <div key={`${h}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                    <span className="text-[13px] text-avia-black/75">{h}</span>
                  </div>
                ))}
              </BentoCard>
            </CatalogSection>
          )}

          <CatalogSection title="Specifications">
            <BentoCard className="px-4 py-1.5">
              <DetailRow label="Total Area" value={`${design.square_meters}m²`} />
              {design.house_width != null && <DetailRow label="House Width" value={`${design.house_width}m`} />}
              {design.house_length != null && <DetailRow label="House Length" value={`${design.house_length}m`} />}
              <DetailRow label="Bedrooms" value={String(design.bedrooms)} />
              <DetailRow label="Bathrooms" value={String(design.bathrooms)} />
              {design.living_areas != null && <DetailRow label="Living Areas" value={String(design.living_areas)} />}
              <DetailRow label="Garage" value={String(design.garages)} />
              <DetailRow label="Storeys" value={design.storeys === 2 ? "Double" : "Single"} />
              {design.lot_width != null && <DetailRow label="Min. Lot Width" value={`${design.lot_width}m`} />}
            </BentoCard>
          </CatalogSection>

          {(design.inclusions ?? []).length > 0 && (
            <CatalogSection title="Standard Inclusions">
              <BentoCard className="px-4 py-2">
                {(design.inclusions ?? []).map((inc, i) => (
                  <div key={`${inc}-${i}`} className="flex items-start gap-2.5 border-b border-avia-line/60 py-2.5 last:border-0">
                    <Check className="mt-0.5 h-4 w-4 shrink-0 text-avia-brown" />
                    <span className="text-[13px] text-avia-black/75">{inc}</span>
                  </div>
                ))}
              </BentoCard>
            </CatalogSection>
          )}

          <div className="grid grid-cols-2 gap-3">
            {KEY_FEATURES.map((f) => (
              <BentoCard key={f.title} className="space-y-1.5 p-4">
                <f.icon className="h-5 w-5 text-avia-brown" />
                <div className="text-[13px] font-medium text-avia-black">{f.title}</div>
                <div className="text-[11px] text-avia-black/50">{f.subtitle}</div>
              </BentoCard>
            ))}
          </div>
        </div>

        <div className="space-y-3 lg:sticky lg:top-8 lg:self-start">
          <BentoCard className="space-y-1 p-4">
            <div className="text-[14px] font-medium text-avia-black">Love the {design.name}?</div>
            <p className="text-[12px] text-avia-black/55">Enquire for pricing on your block, or talk to our team.</p>
          </BentoCard>
          <PrimaryButton onClick={() => setEnquiryOpen(true)}>Enquire for Pricing</PrimaryButton>
          <a
            href="tel:0756545123"
            className="flex h-[50px] w-full items-center justify-center gap-2 rounded-[11px] border border-avia-brown/20 bg-avia-brown/10 text-[15px] font-medium text-avia-brown transition-colors hover:bg-avia-brown/15"
          >
            <Phone className="h-4 w-4" /> 07 5654 5123
          </a>
        </div>
      </div>

      <Modal open={floorplanOpen} onClose={() => setFloorplanOpen(false)} title={`${design.name} Floor Plan`}>
        <img
          src={design.floorplan_image_url ?? design.image_url}
          alt={`${design.name} floor plan`}
          className="mx-auto max-h-[70vh] w-auto object-contain"
        />
      </Modal>

      <DesignEnquiryModal open={enquiryOpen} onClose={() => setEnquiryOpen(false)} designName={design.name} />
    </div>
  );
}

function QuickStat({ icon: Icon, value, label }: { icon: typeof BedDouble; value: string; label: string }) {
  return (
    <BentoCard className="flex flex-col items-center gap-1 py-3.5">
      <Icon className="h-5 w-5 text-avia-brown" />
      <span className="text-[17px] font-medium text-avia-black">{value}</span>
      <span className="text-[10px] font-medium uppercase tracking-wider text-avia-black/40">{label}</span>
    </BentoCard>
  );
}

function DimChip({ label, value }: { label: string; value: string }) {
  return (
    <span className="whitespace-nowrap rounded-full border border-avia-line bg-avia-card px-3.5 py-1.5 text-[12px] text-avia-black/70">
      <span className="text-avia-black/45">{label}</span> <span className="font-medium">{value}</span>
    </span>
  );
}

/** Pricing enquiry form — inserts into design_enquiries (iOS parity). */
function DesignEnquiryModal({ open, onClose, designName }: { open: boolean; onClose: () => void; designName: string }) {
  const { profile } = useAuth();
  const [name, setName] = useState<string>(profile ? fullNameOf(profile) : "");
  const [email, setEmail] = useState<string>(profile?.email ?? "");
  const [phone, setPhone] = useState<string>(profile?.phone ?? "");
  const [message, setMessage] = useState<string>("");

  const submit = useMutation({
    mutationFn: async () => {
      if (!name.trim() || !email.trim()) throw new Error("Name and email are required");
      const { error } = await supabase.from("design_enquiries").insert({
        id: crypto.randomUUID().toLowerCase(),
        design_name: designName,
        full_name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        message: message.trim() || null,
        created_at: nowISO(),
      });
      if (error) throw error;
    },
    onSuccess: () => {
      toast.success("Enquiry sent — our team will be in touch");
      onClose();
    },
    onError: (err: Error) => toast.error(err.message),
  });

  return (
    <Modal open={open} onClose={onClose} title={`Enquire — ${designName}`}>
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
        <FieldLabel>Message (optional)</FieldLabel>
        <textarea className={`${inputClass} min-h-24 resize-y`} value={message} onChange={(e) => setMessage(e.target.value)} />
      </div>
      <PrimaryButton onClick={() => submit.mutate()} loading={submit.isPending}>
        Send Enquiry
      </PrimaryButton>
    </Modal>
  );
}
