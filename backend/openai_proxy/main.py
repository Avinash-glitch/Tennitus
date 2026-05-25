import os
from pathlib import Path
from typing import Any, Literal

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field


def load_env_file() -> None:
    env_path = Path(__file__).resolve().parents[2] / ".env"
    if not env_path.exists():
        return
    for line in env_path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        os.environ.setdefault(key.strip(), value.strip())


load_env_file()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") or ""
GEMINI_MODEL = os.getenv("GEMINI_MODEL") or "gemini-2.5-flash"

app = FastAPI(title="Tennitus AI Proxy")


class BandEnergy(BaseModel):
    label: str
    low_hz: float
    high_hz: float
    energy_dbfs: float
    relative_energy: float = Field(ge=0, le=1)

class TargetSoundMatch(BaseModel):
    label: str
    time_range_seconds: dict[str, float]
    score_0_to_1: float
    confidence: str
    dominant_frequency_hz: int
    top_frequency_peaks_hz: list[int]
    rationale: str

class SourceDetection(BaseModel):
    label: str
    confidence: float
    time_range_seconds: dict[str, float]
    matched_user_description: bool

class WeightedTriggerScoreFactor(BaseModel):
    name: str
    weight: float
    value_0_to_1: float
    contribution: float
    evidence: str

class WeightedTriggerScore(BaseModel):
    score_0_to_1: float
    tier: str
    factors: list[WeightedTriggerScoreFactor]

class AppleHealthSleep(BaseModel):
    lookback_days: int
    latest_night_asleep_hours: float
    average_asleep_hours: float

class AppleHealthHearing(BaseModel):
    latest_audiogram_date: str
    source_name: str
    average_left_db_hl: float | None = None
    average_right_db_hl: float | None = None

class AppleHealthContext(BaseModel):
    sleep: AppleHealthSleep | None = None
    hearing: AppleHealthHearing | None = None

class PatternProfile(BaseModel):
    primary: str
    modifiers: list[str]
    confidence: str
    pitch_hz: float | None = None

class ComfortSessionRequest(BaseModel):
    user_description: str
    background_description: str = ""
    tinnitus_match_hz: float
    duration_seconds: float
    rms_dbfs: float
    peak_dbfs: float
    spectral_centroid_hz: float
    dominant_frequency_hz: int = 0
    top_frequency_peaks_hz: list[int] = []
    target_sound_matches: list[TargetSoundMatch] = []
    source_detections: list[SourceDetection] = []
    dominant_band: str
    high_frequency_ratio: float
    transient_count: int
    sensitive_range_hz: dict[str, float]
    band_energy: list[BandEnergy]
    weighted_trigger_score: WeightedTriggerScore | None = None
    apple_health_context: AppleHealthContext | None = None
    pattern_profile: PatternProfile


class ComfortSessionSuggestion(BaseModel):
    title: str
    summary: str
    targetFrequencyRange: str
    suggestedSound: str
    suggestedFrequencyHz: float | None
    durationMinutes: int = Field(ge=1, le=20)
    volumeGuidance: str
    rationale: list[str] = Field(min_length=1, max_length=5)
    safetyNotes: list[str] = Field(min_length=1, max_length=5)
    confidence: Literal["Low", "Medium", "High"]
    disclaimer: str


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/v1/comfort-session", response_model=ComfortSessionSuggestion)
async def comfort_session(payload: ComfortSessionRequest) -> Any:
    if not GEMINI_API_KEY:
        raise HTTPException(status_code=500, detail="GEMINI_API_KEY is not configured")

    system_inst = (
        "You are helping a user understand a recorded sound event for tinnitus and sound sensitivity support. "
        "Use only the provided numeric audio summary and the user's description. "
        "Do not diagnose, treat, prescribe, or claim a cure. "
        "Recommend a short comfort session, not medical therapy. "
        "Do not suggest loud playback. Always include stop-if-worse guidance. "
        f"The user's pattern profile is: {payload.pattern_profile.primary}.\n"
    )
    if payload.pattern_profile.modifiers:
        system_inst += f"Active Modifiers: {', '.join(payload.pattern_profile.modifiers)}.\n"
    if payload.pattern_profile.pitch_hz:
        system_inst += f"Matched Pitch Frequency: {int(payload.pattern_profile.pitch_hz)} Hz.\n"

    primary = payload.pattern_profile.primary.lower()
    if primary == "tonal":
        pitch = int(payload.pattern_profile.pitch_hz or 4000)
        system_inst += f"Since their pattern is Tonal, recommend masking or relaxation audio that avoids or notches the sound around their matched pitch frequency ({pitch} Hz).\n"
    elif primary == "narrowband noise":
        system_inst += "Since their pattern is Narrowband Noise (hissing/buzzing), recommend soft broadband noise profiles (pink/brown noise) slightly above the bothersome band.\n"
    elif primary == "pulsatile":
        system_inst += "Since their pattern is Pulsatile (pulse/whoosh), ensure safety warnings highlight that pulsatile symptoms should be discussed with an ENT specialist. Focus the session on low-frequency somatic relaxation.\n"
    elif primary == "complex":
        system_inst += "Since their pattern is Complex, suggest a mixture of nature soundscapes and soft drones to enrich the audio background.\n"
    
    modifiers_lower = [m.lower() for m in payload.pattern_profile.modifiers]
    if "somatic" in modifiers_lower:
        system_inst += "Since they have a Somatic modifier, suggest gentle jaw/neck physical relaxation exercises or somatic mindfulness exercises as part of the session suggestion.\n"
    if "reactive" in modifiers_lower:
        system_inst += "Since they have a Reactive modifier, warn against sudden sound increases and suggest starting comfort sessions at near-silence with very gradual fades.\n"

    body = {
        "contents": [
            {
                "parts": [
                    {
                        "text": f"System Instructions:\n{system_inst}\n\nInput Payload:\n{payload.model_dump_json()}"
                    }
                ]
            }
        ],
        "generationConfig": {
            "responseMimeType": "application/json",
            "responseSchema": response_schema()
        }
    }

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"

    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(
            url,
            headers={
                "Content-Type": "application/json",
            },
            json=body,
        )

    if response.status_code >= 400:
        raise HTTPException(status_code=response.status_code, detail=response.text)

    data = response.json()
    output_text = extract_output_text(data)
    if not output_text:
        raise HTTPException(status_code=502, detail="Gemini response did not include output text")

    return ComfortSessionSuggestion.model_validate_json(output_text)


def extract_output_text(data: dict[str, Any]) -> str | None:
    try:
        return data["candidates"][0]["content"]["parts"][0]["text"]
    except (KeyError, IndexError):
        return None


def response_schema() -> dict[str, Any]:
    return {
        "type": "OBJECT",
        "properties": {
            "title": {"type": "STRING"},
            "summary": {"type": "STRING"},
            "targetFrequencyRange": {"type": "STRING"},
            "suggestedSound": {"type": "STRING"},
            "suggestedFrequencyHz": {"type": "NUMBER"},
            "durationMinutes": {"type": "INTEGER"},
            "volumeGuidance": {"type": "STRING"},
            "rationale": {
                "type": "ARRAY",
                "items": {"type": "STRING"},
            },
            "safetyNotes": {
                "type": "ARRAY",
                "items": {"type": "STRING"},
            },
            "confidence": {"type": "STRING", "enum": ["Low", "Medium", "High"]},
            "disclaimer": {"type": "STRING"},
        },
        "required": [
            "title",
            "summary",
            "targetFrequencyRange",
            "suggestedSound",
            "suggestedFrequencyHz",
            "durationMinutes",
            "volumeGuidance",
            "rationale",
            "safetyNotes",
            "confidence",
            "disclaimer",
        ],
    }
