import { useCallback, useEffect, useRef, useState } from "react";

interface RotaryDialProps {
  label: string;
  value: number;
  min?: number;
  max?: number;
  step?: number;
  unit?: string;
  size?: number;
  accentClass?: string;
  onChange?: (value: number) => void;
  formatValue?: (value: number) => string;
}

/**
 * Skeuomorphic rotary dial. Drag vertically (or use scroll) to adjust value.
 * The conic ring around the dial visualizes the current position.
 */
export function RotaryDial({
  label,
  value,
  min = 0,
  max = 10,
  step = 1,
  unit,
  size = 168,
  accentClass = "text-accent",
  onChange,
  formatValue,
}: RotaryDialProps) {
  const [internal, setInternal] = useState(value);
  const dragRef = useRef<{ startY: number; startVal: number } | null>(null);

  useEffect(() => setInternal(value), [value]);

  const pct = (internal - min) / (max - min);
  const angle = 30 + pct * 300; // dial sweep from -150° to +150°
  const ringAngle = pct * 360;

  const commit = useCallback(
    (next: number) => {
      const clamped = Math.max(min, Math.min(max, next));
      const stepped = Math.round(clamped / step) * step;
      setInternal(stepped);
      onChange?.(stepped);
    },
    [min, max, step, onChange],
  );

  const onPointerDown = (e: React.PointerEvent) => {
    (e.target as HTMLElement).setPointerCapture(e.pointerId);
    dragRef.current = { startY: e.clientY, startVal: internal };
  };

  const onPointerMove = (e: React.PointerEvent) => {
    if (!dragRef.current) return;
    const dy = dragRef.current.startY - e.clientY;
    const range = max - min;
    const delta = (dy / 140) * range;
    commit(dragRef.current.startVal + delta);
  };

  const onPointerUp = (e: React.PointerEvent) => {
    (e.target as HTMLElement).releasePointerCapture(e.pointerId);
    dragRef.current = null;
  };

  const onWheel = (e: React.WheelEvent) => {
    e.preventDefault();
    commit(internal + (e.deltaY < 0 ? step : -step));
  };

  const displayValue = formatValue
    ? formatValue(internal)
    : Number.isInteger(step)
      ? String(Math.round(internal)).padStart(2, "0")
      : internal.toFixed(1);

  return (
    <div className="flex flex-col items-center gap-3 select-none">
      <div
        className="relative cursor-ns-resize touch-none"
        style={{ width: size, height: size }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
        onWheel={onWheel}
        role="slider"
        aria-label={label}
        aria-valuemin={min}
        aria-valuemax={max}
        aria-valuenow={internal}
        tabIndex={0}
        onKeyDown={(e) => {
          if (e.key === "ArrowUp" || e.key === "ArrowRight") commit(internal + step);
          if (e.key === "ArrowDown" || e.key === "ArrowLeft") commit(internal - step);
        }}
      >
        {/* Outer progress ring */}
        <div
          className="absolute inset-0 rounded-full"
          style={{
            background: `conic-gradient(from -90deg, var(--color-accent) 0deg, var(--color-accent) ${ringAngle}deg, oklch(0.22 0.01 260) ${ringAngle}deg 360deg)`,
            filter: "drop-shadow(0 0 8px oklch(0.82 0.135 198 / 0.35))",
          }}
        />
        {/* Gap between ring and dial body */}
        <div className="absolute inset-[6px] rounded-full bg-background" />
        {/* Dial body */}
        <div className="absolute inset-[10px] rounded-full dial-skin">
          {/* Tick marks */}
          <svg className="absolute inset-0 w-full h-full" viewBox="0 0 100 100">
            {Array.from({ length: 21 }).map((_, i) => {
              const a = (30 + (i / 20) * 300) * (Math.PI / 180);
              const r1 = 44;
              const r2 = i % 5 === 0 ? 39 : 41;
              const x1 = 50 + Math.cos(a - Math.PI / 2) * r1;
              const y1 = 50 + Math.sin(a - Math.PI / 2) * r1;
              const x2 = 50 + Math.cos(a - Math.PI / 2) * r2;
              const y2 = 50 + Math.sin(a - Math.PI / 2) * r2;
              const active = (i / 20) * (max - min) + min <= internal;
              return (
                <line
                  key={i}
                  x1={x1}
                  y1={y1}
                  x2={x2}
                  y2={y2}
                  stroke={active ? "currentColor" : "oklch(0.35 0.01 260)"}
                  strokeWidth={i % 5 === 0 ? 1 : 0.5}
                  className={active ? accentClass : ""}
                />
              );
            })}
          </svg>

          {/* Indicator notch */}
          <div
            className="absolute left-1/2 top-1/2 origin-bottom"
            style={{
              width: 2,
              height: size * 0.32,
              transform: `translate(-50%, -100%) rotate(${angle - 180}deg)`,
              transformOrigin: "50% 100%",
            }}
          >
            <div
              className="w-full h-full rounded-full"
              style={{
                background:
                  "linear-gradient(to bottom, var(--color-accent), transparent)",
                filter: "drop-shadow(0 0 4px var(--color-accent))",
              }}
            />
          </div>

          {/* Center cap with value */}
          <div className="absolute inset-[18%] rounded-full bg-gradient-to-br from-zinc-800 to-zinc-950 ring-1 ring-white/5 flex flex-col items-center justify-center shadow-[inset_0_1px_0_rgba(255,255,255,0.05)]">
            <span className={`font-mono text-2xl ${accentClass}`}>{displayValue}</span>
            {unit && (
              <span className="text-[9px] font-mono uppercase tracking-widest text-muted-foreground mt-0.5">
                {unit}
              </span>
            )}
          </div>
        </div>
      </div>

      <div className="text-center">
        <p className="text-[10px] font-mono uppercase tracking-widest text-muted-foreground">
          {label}
        </p>
      </div>
    </div>
  );
}
