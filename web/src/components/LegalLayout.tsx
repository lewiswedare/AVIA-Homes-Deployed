import { ArrowLeft } from "lucide-react";
import { Link } from "react-router-dom";

import { LEGAL_LAST_UPDATED, type LegalSection } from "@/lib/legal";

/** Shared layout for the public /terms and /privacy pages. */
export default function LegalLayout({
  title,
  sections,
}: {
  title: string;
  sections: LegalSection[];
}) {
  return (
    <div className="min-h-screen bg-avia-white">
      <header className="sticky top-0 z-10 border-b border-avia-line bg-avia-white/90 backdrop-blur">
        <div className="mx-auto flex w-full max-w-3xl items-center justify-between px-6 py-4">
          <Link to="/login" className="flex items-center gap-2 text-[13px] font-medium text-avia-black/60 hover:text-avia-black">
            <ArrowLeft className="h-4 w-4" /> Back
          </Link>
          <img src="/brand/avia-logo.png" alt="AVIA Homes" className="h-6 w-auto" />
        </div>
      </header>

      <main className="mx-auto w-full max-w-3xl px-6 pb-24 pt-10">
        <h1 className="text-[30px] font-medium text-avia-black">{title}</h1>
        <p className="mt-1 text-[13px] text-avia-black/45">Last updated: {LEGAL_LAST_UPDATED}</p>

        <div className="mt-10 space-y-9">
          {sections.map((section) => (
            <section key={section.heading}>
              <h2 className="text-[16px] font-medium text-avia-black">{section.heading}</h2>
              <div className="mt-2 space-y-2.5">
                {section.paragraphs.map((p) => (
                  <p key={p.slice(0, 40)} className="text-[14px] leading-relaxed text-avia-black/65">
                    {p}
                  </p>
                ))}
                {section.bullets && (
                  <ul className="list-disc space-y-1 pl-5">
                    {section.bullets.map((b) => (
                      <li key={b.slice(0, 40)} className="text-[14px] leading-relaxed text-avia-black/65">
                        {b}
                      </li>
                    ))}
                  </ul>
                )}
                {section.trailing?.map((t) => (
                  <p key={t.slice(0, 40)} className="text-[14px] leading-relaxed text-avia-black/65">
                    {t}
                  </p>
                ))}
              </div>
            </section>
          ))}
        </div>

        <div className="mt-14 flex items-center justify-between border-t border-avia-line pt-6">
          <img src="/brand/avia-logo.png" alt="" className="h-5 w-auto opacity-40" />
          <div className="flex gap-4 text-[13px] font-medium text-avia-brown">
            <Link to="/terms" className="hover:underline">Terms of Service</Link>
            <Link to="/privacy" className="hover:underline">Privacy Policy</Link>
          </div>
        </div>
      </main>
    </div>
  );
}
