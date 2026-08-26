import logging
import shutil
import uuid
from pathlib import Path

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from . import config, pipeline

logging.basicConfig(
    level=config.LOG_LEVEL,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
logger = logging.getLogger("reel_processor")

app = FastAPI(title="Instagram Reel Processor")


class DownloadRequest(BaseModel):
    url: str


class JobRequest(BaseModel):
    job_id: str


def job_dir_for(job_id: str) -> Path:
    job_dir = Path(config.WORK_DIR) / job_id
    if not job_dir.is_dir():
        raise HTTPException(status_code=404, detail=f"Unknown job_id: {job_id}")
    return job_dir


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/download")
def download(req: DownloadRequest):
    job_id = uuid.uuid4().hex
    job_dir = Path(config.WORK_DIR) / job_id
    logger.info("job=%s step=download url=%s", job_id, req.url)
    try:
        metadata = pipeline.download_post(req.url, job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=download failed: %s", job_id, exc)
        raise HTTPException(status_code=502, detail=str(exc))
    return {"job_id": job_id, "metadata": metadata}


@app.post("/extract-audio")
def extract_audio(req: JobRequest):
    job_dir = job_dir_for(req.job_id)
    logger.info("job=%s step=extract-audio", req.job_id)
    try:
        audio_path = pipeline.extract_audio(job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=extract-audio failed: %s", req.job_id, exc)
        raise HTTPException(status_code=422, detail=str(exc))
    return {"job_id": req.job_id, "audio_path": str(audio_path)}


@app.post("/transcribe")
def transcribe(req: JobRequest):
    job_dir = job_dir_for(req.job_id)
    logger.info("job=%s step=transcribe", req.job_id)
    try:
        result = pipeline.transcribe(job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=transcribe failed: %s", req.job_id, exc)
        raise HTTPException(status_code=422, detail=str(exc))
    return {"job_id": req.job_id, **result}


@app.post("/extract-frames")
def extract_frames(req: JobRequest):
    job_dir = job_dir_for(req.job_id)
    logger.info("job=%s step=extract-frames", req.job_id)
    try:
        frames = pipeline.extract_frames(job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=extract-frames failed: %s", req.job_id, exc)
        raise HTTPException(status_code=422, detail=str(exc))
    return {"job_id": req.job_id, "frames": [str(f) for f in frames]}


@app.post("/ocr")
def ocr(req: JobRequest):
    job_dir = job_dir_for(req.job_id)
    logger.info("job=%s step=ocr", req.job_id)
    try:
        results = pipeline.run_ocr(job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=ocr failed: %s", req.job_id, exc)
        raise HTTPException(status_code=422, detail=str(exc))
    return {"job_id": req.job_id, "results": results}


@app.post("/process")
def process(req: DownloadRequest):
    job_id = uuid.uuid4().hex
    job_dir = Path(config.WORK_DIR) / job_id
    logger.info("job=%s step=process url=%s", job_id, req.url)
    try:
        metadata = pipeline.download_post(req.url, job_dir)
        pipeline.extract_audio(job_dir)
        transcript = pipeline.transcribe(job_dir)
        pipeline.extract_frames(job_dir)
        ocr_results = pipeline.run_ocr(job_dir)
    except pipeline.PipelineError as exc:
        logger.error("job=%s step=process failed: %s", job_id, exc)
        raise HTTPException(status_code=502, detail=str(exc))
    finally:
        if not config.KEEP_FILES and job_dir.exists():
            logger.info("job=%s cleaning up %s", job_id, job_dir)
            shutil.rmtree(job_dir, ignore_errors=True)

    return {"metadata": metadata, "transcript": transcript, "ocr_results": ocr_results}
