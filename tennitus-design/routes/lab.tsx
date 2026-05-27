import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { MobileFrame } from "@/components/MobileFrame";
import { BottomNav } from "@/components/BottomNav";
import { RotaryDial } from "@/components/RotaryDial";

export const Route = createFileRoute("/lab")({
  head: () => ({
    meta: [
      { title: "Tone Match Lab — Tennitus" },
      { name: "description", content: "Match your tinnitus tone by adjusting frequency and waveform with precision controls." },
      { property: "og:title", content: "Tone Match Lab — Tennitus" },
      { property: "og:description", content: "Match your tinnitus tone by adjusting frequency and waveform with precision controls." },
    ],
  }),
  component: ToneLab,
});

const WAVEFORMS = ["SINE", "SAW", "SQUARE", "TRI"] as const;

function ToneLab() {
  const [hz, setHz] = useState(8420);
  const [wave, setWave] = useState<typeof WAVEFORMS[number]>("SINE");

  return (
    <MobileFrame statusLeft={<span className="text-accent">LAB · TONE MATCH</span>} statusRight={<span>{hz} Hz</span>}>
      <div className="flex flex-col min-h-[calc(100vh-3rem)]">
        <main className="px-6 pt-2 pb-6 space-y-6 animate-slide-up">
          <header>
            <p className="text-[10px] font-mono uppercase tracking-[0.2em] text-muted-foreground mb-2">
              Reference vs Generated
            </p>
            <h1 className="text-2xl font-bold tracking-tight">Match the tone you hear.</h1>
          </header>

          <section className="glass rounded-3xl p-6 flex flex-col items-center gap-6">
            <RotaryDial
              label="Frequency"
              value={hz}
              min={250}
              max={20000}
              step={10}
              unit="Hz"
              size={220}
              formatValue={(v) => v.toLocaleString()}
              onChange={setHz}
            />

            <div className="w-full grid grid-cols-4 gap-2">
              {WAVEFORMS.map((w) => (
                <button
                  key={w}
                  type="button"
                  onClick={() => setWave(w)}
                  className={`py-2 rounded-xl text-[10px] font-mono border transition-colors ${
                    wave === w
                      ? "bg-accent/15 border-accent/40 text-accent"
                      : "bg-secondary border-border text-muted-foreground"
                  }`}
                >
                  {w}
                </button>
              ))}
            </div>

            <div className="w-full grid grid-cols-2 gap-3">
              <button className="py-3 rounded-xl border border-border bg-secondary text-sm font-medium">
                Play Reference
              </button>
              <button className="py-3 rounded-xl bg-accent text-accent-foreground text-sm font-semibold shadow-[0_0_20px_var(--color-accent)]">
                Play Match
              </button>
            </div>
          </section>

          <p className="text-xs text-muted-foreground text-center leading-relaxed">
            Adjust the dial until the generated tone matches what you hear.
            <br />Locked values save to your tinnitus profile.
          </p>
        </main>

        <div className="mt-auto">
          <BottomNav />
        </div>
      </div>
    </MobileFrame>
  );
}
