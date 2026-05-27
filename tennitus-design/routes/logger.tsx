import { useState } from "react";
import { createFileRoute, useRouter } from "@tanstack/react-router";
import { MobileFrame } from "@/components/MobileFrame";
import { BottomNav } from "@/components/BottomNav";
import { RotaryDial } from "@/components/RotaryDial";
import { SpectrumAnalyzer } from "@/components/SpectrumAnalyzer";

export const Route = createFileRoute("/logger")({
  head: () => ({
    meta: [
      { title: "Event Logger — Tennitus" },
      { name: "description", content: "Capture an ambient environment profile and log distress and loudness with precision dials." },
      { property: "og:title", content: "Event Logger — Tennitus" },
      { property: "og:description", content: "Capture an ambient environment profile and log distress and loudness with precision dials." },
    ],
  }),
  component: EventLogger,
});

const ALL_TAGS = ["OFFICE", "OUTDOOR", "AFTER_CAFFEINE", "LOW_SLEEP", "HEADPHONES", "QUIET_ROOM"];

function EventLogger() {
  const router = useRouter();
  const [loudness, setLoudness] = useState(7);
  const [distress, setDistress] = useState(3);
  const [active, setActive] = useState<string[]>(["OFFICE", "AFTER_CAFFEINE"]);

  const toggleTag = (t: string) =>
    setActive((a) => (a.includes(t) ? a.filter((x) => x !== t) : [...a, t]));

  return (
    <MobileFrame
      statusLeft={
        <span className="animate-pulse-glow text-accent">● REC ACTIVE</span>
      }
      statusRight={<span>14.2 kHz</span>}
    >
      <div className="flex flex-col min-h-[calc(100vh-3rem)]">
        <main className="px-6 pt-2 pb-6 space-y-6 animate-slide-up">
          <header>
            <p className="text-[10px] font-mono uppercase tracking-[0.2em] text-muted-foreground mb-2">
              Capture · Step 2 of 3
            </p>
            <h1 className="text-2xl font-bold tracking-tight">Analyze Ambient</h1>
            <p className="text-sm text-muted-foreground mt-1">
              Capturing environment profile&hellip;
            </p>
          </header>

          {/* Spectrum analyzer hero */}
          <section className="glass rounded-3xl p-5 space-y-4">
            <SpectrumAnalyzer />

            <div className="flex justify-between items-end pt-2 border-t border-border">
              <div>
                <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground block">
                  Ambient Pressure
                </span>
                <span className="font-mono text-3xl text-foreground">
                  64.2 <span className="text-sm text-muted-foreground">dB</span>
                </span>
              </div>
              <div className="text-right">
                <span className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground block">
                  Peak Freq
                </span>
                <span className="font-mono text-lg text-accent">
                  14,200 <span className="text-xs">Hz</span>
                </span>
              </div>
            </div>
          </section>

          {/* Skeuomorphic rotary dials */}
          <section className="glass rounded-3xl p-5">
            <div className="flex justify-between items-center mb-5">
              <h3 className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
                Subjective Readings
              </h3>
              <span className="text-[10px] font-mono text-muted-foreground">DRAG · SCROLL</span>
            </div>
            <div className="grid grid-cols-2 gap-2">
              <RotaryDial
                label="Loudness"
                value={loudness}
                onChange={setLoudness}
                accentClass="text-accent"
              />
              <RotaryDial
                label="Distress"
                value={distress}
                onChange={setDistress}
                accentClass="text-warning"
              />
            </div>
          </section>

          {/* Environment tags */}
          <section className="space-y-3">
            <h3 className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
              Context
            </h3>
            <div className="flex flex-wrap gap-2">
              {ALL_TAGS.map((tag) => {
                const isActive = active.includes(tag);
                return (
                  <button
                    key={tag}
                    type="button"
                    onClick={() => toggleTag(tag)}
                    className={`px-3 py-1.5 rounded-full text-[10px] font-mono border transition-colors ${
                      isActive
                        ? "bg-accent/15 border-accent/40 text-accent"
                        : "bg-secondary border-border text-muted-foreground"
                    }`}
                  >
                    #{tag}
                  </button>
                );
              })}
            </div>
          </section>

          {/* CTA */}
          <button
            type="button"
            onClick={() => router.navigate({ to: "/" })}
            className="w-full py-4 rounded-2xl bg-foreground text-background font-semibold tracking-wide active:scale-[0.99] transition-transform"
          >
            SAVE DATA ENTRY
          </button>
        </main>

        <div className="mt-auto">
          <BottomNav />
        </div>
      </div>
    </MobileFrame>
  );
}
