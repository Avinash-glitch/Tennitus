interface SpectrumAnalyzerProps {
  bars?: number;
  height?: number;
}

/**
 * Animated spectrum analyzer hero. Pure CSS — no audio API required for prototype UI.
 */
export function SpectrumAnalyzer({ bars = 28, height = 160 }: SpectrumAnalyzerProps) {
  return (
    <div
      className="flex items-center justify-center gap-[3px]"
      style={{ height }}
      aria-hidden
    >
      {Array.from({ length: bars }).map((_, i) => {
        // Bell-curve-ish heights centered on peak
        const center = bars / 2;
        const dist = Math.abs(i - center) / center;
        const base = Math.max(0.08, 1 - dist * dist);
        const opacity = 0.18 + base * 0.82;
        const duration = 0.7 + ((i * 13) % 11) / 10;
        const delay = ((i * 7) % 13) / 20;
        return (
          <div
            key={i}
            className="w-1 rounded-full bg-accent origin-bottom"
            style={{
              height: `${base * 100}%`,
              opacity,
              animation: `float-bar ${duration}s ease-in-out ${delay}s infinite`,
              filter: i === Math.round(center) ? "drop-shadow(0 0 6px var(--color-accent))" : undefined,
            }}
          />
        );
      })}
    </div>
  );
}
