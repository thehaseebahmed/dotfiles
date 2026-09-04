"""Optional place-metadata enrichment: pull place mentions (name/city/country)
out of a reel's text via the self-hosted litellm proxy, then resolve each one
against the Google Maps Places API for a rating and canonical Maps URL.

Both integrations are optional and independent of each other and of the core
pipeline: if litellm or the Maps key isn't configured, or either call fails,
the corresponding piece is just left out rather than failing /process — this
is enrichment on top of the transcript/OCR result, not something callers can
already depend on existing.
"""

import json
import logging
import re

import requests

from . import config

logger = logging.getLogger("insta_parser")

_JSON_ARRAY_RE = re.compile(r"\[.*\]", re.DOTALL)

_SYSTEM_PROMPT = (
    "You extract real-world place mentions from Instagram reel content (caption, "
    "spoken transcript, on-screen text). Return a JSON array of distinct places "
    "worth visiting that are mentioned (restaurants, cafes, bars, landmarks, hotels, "
    "shops, or cities/regions the reel is about). Each item must be an object with "
    'keys "name" (the specific venue/landmark name, or null if only a city/region '
    'is mentioned), "city", and "country". Use null for any field you cannot '
    "determine. Do not invent places that aren't mentioned. If none are mentioned, "
    "return []. Respond with ONLY the JSON array, no other text."
)


def places_configured() -> bool:
    return bool(config.LITELLM_BASE_URL and config.LITELLM_MODEL)


def maps_configured() -> bool:
    return bool(config.GOOGLE_MAPS_API_KEY)


def _build_context(metadata: dict, transcript: dict | None, ocr_results: list[dict] | None) -> str:
    parts = [metadata.get("caption") or ""]
    if metadata.get("location"):
        parts.append(f"Tagged location: {metadata['location']}")
    if transcript and transcript.get("text"):
        parts.append(transcript["text"])
    if ocr_results:
        parts.extend(item["text"] for item in ocr_results if item.get("text"))
    text = "\n".join(p for p in parts if p)
    return text[: config.PLACE_EXTRACTION_MAX_CHARS]


def extract_place_mentions(
    metadata: dict, transcript: dict | None, ocr_results: list[dict] | None
) -> list[dict]:
    """Ask the configured litellm model for place mentions in the reel's text.
    Returns [] if extraction isn't configured, finds nothing, or the call
    fails — a broken/unreachable model shouldn't fail /process."""
    if not places_configured():
        return []

    context = _build_context(metadata, transcript, ocr_results)
    if not context.strip():
        return []

    headers = {"Content-Type": "application/json"}
    if config.LITELLM_API_KEY:
        headers["Authorization"] = f"Bearer {config.LITELLM_API_KEY}"

    try:
        response = requests.post(
            f"{config.LITELLM_BASE_URL.rstrip('/')}/chat/completions",
            headers=headers,
            json={
                "model": config.LITELLM_MODEL,
                "messages": [
                    {"role": "system", "content": _SYSTEM_PROMPT},
                    {"role": "user", "content": context},
                ],
                "temperature": 0,
            },
            timeout=config.LITELLM_TIMEOUT,
        )
        response.raise_for_status()
        content = response.json()["choices"][0]["message"]["content"]
    except Exception as exc:
        logger.warning("Place extraction via litellm failed: %s", exc)
        return []

    match = _JSON_ARRAY_RE.search(content)
    if not match:
        logger.warning("Place extraction model did not return a JSON array: %r", content[:200])
        return []

    try:
        places = json.loads(match.group(0))
    except json.JSONDecodeError as exc:
        logger.warning("Place extraction returned invalid JSON (%s): %r", exc, content[:200])
        return []

    if not isinstance(places, list):
        return []

    cleaned = []
    for place in places:
        if not isinstance(place, dict):
            continue
        name, city, country = place.get("name"), place.get("city"), place.get("country")
        if not (name or city or country):
            continue
        cleaned.append({"name": name, "city": city, "country": country})
    return cleaned


def _search_query(place: dict) -> str:
    return ", ".join(part for part in (place.get("name"), place.get("city"), place.get("country")) if part)


def resolve_place_on_maps(place: dict) -> dict:
    """Look up one extracted place via the Google Maps Places API. Returns the
    place enriched with rating/maps_url, both None if the lookup fails or the
    Maps API isn't configured — the extracted name/city/country is still
    useful on its own."""
    enriched = {**place, "rating": None, "maps_url": None}
    if not maps_configured():
        return enriched

    query = _search_query(place)
    if not query:
        return enriched

    try:
        response = requests.post(
            "https://places.googleapis.com/v1/places:searchText",
            headers={
                "Content-Type": "application/json",
                "X-Goog-Api-Key": config.GOOGLE_MAPS_API_KEY,
                "X-Goog-FieldMask": "places.displayName,places.rating,places.googleMapsUri",
            },
            json={"textQuery": query},
            timeout=config.GOOGLE_MAPS_TIMEOUT,
        )
        response.raise_for_status()
        candidates = response.json().get("places") or []
    except Exception as exc:
        logger.warning("Google Maps lookup failed for %r: %s", query, exc)
        return enriched

    if not candidates:
        return enriched

    best = candidates[0]
    enriched["name"] = (best.get("displayName") or {}).get("text") or place.get("name")
    enriched["rating"] = best.get("rating")
    enriched["maps_url"] = best.get("googleMapsUri")
    return enriched


def build_places_metadata(
    metadata: dict, transcript: dict | None, ocr_results: list[dict] | None
) -> list[dict]:
    mentions = extract_place_mentions(metadata, transcript, ocr_results)
    return [resolve_place_on_maps(place) for place in mentions]
