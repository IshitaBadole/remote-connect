# backend/main.py
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, UploadFile, File, Form, Header, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.responses import Response
import os
import uuid
import uvicorn
import json
import io
import traceback
from datetime import datetime
from pydantic import TypeAdapter, ValidationError
from dotenv import load_dotenv
from supabase import create_client as supabase_create_client, ClientOptions
from PIL import Image, ImageOps

from templates import Element, TemplateMetadata, build_canvas, TEMPLATE_CATALOG

# Load env vars from frontend/.env (same file Flutter uses)
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "frontend", ".env"))

app = FastAPI()

_SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
_SUPABASE_ANON_KEY = os.environ.get("SUPABASE_PUBLISHABLE_DEFAULT_KEY", "")

def _user_client(user_jwt: str):
    """Return a Supabase client scoped to the given user JWT (RLS applies)."""
    return supabase_create_client(
        _SUPABASE_URL,
        _SUPABASE_ANON_KEY,
        options=ClientOptions(headers={"Authorization": f"Bearer {user_jwt}"}),
    )

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://remote-connect.ishitabadole.me/"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.mount("/static", StaticFiles(directory="static"), name="static")

os.makedirs("local_storage", exist_ok=True)

@app.get("/")
async def root():
    return {"status": "Backend is running"}

@app.get("/api/templates")
def list_templates() -> list[TemplateMetadata]:
    return TEMPLATE_CATALOG

@app.get("/api/icons")
def list_icons() -> list[str]:
    icons_dir = os.path.join("static", "icons")
    return [
        os.path.splitext(f)[0]
        for f in sorted(os.listdir(icons_dir))
        if f.endswith(".png") and not f.startswith("emotion_")
    ]

@app.post("/api/generate-print")
async def generate_print(
    template: str = Form(...),
    elements: str = Form(...),
    to_name: str = Form(""),
    from_name: str = Form(""),
    save_image: str = Form("true"),
    do_print: str = Form("true"),
    image_0: UploadFile | None = File(None),
    image_1: UploadFile | None = File(None),
    authorization: str = Header(default=""),
):
    try:
        adapter = TypeAdapter(list[Element])
        validated_elements = adapter.validate_python(json.loads(elements))
    except (json.JSONDecodeError, ValidationError) as e:
        raise HTTPException(status_code=422, detail=str(e))

    images = {}
    for key, upload in [("image_0", image_0), ("image_1", image_1)]:
        if upload is not None:
            data = await upload.read()
            img = Image.open(io.BytesIO(data))
            images[key] = ImageOps.exif_transpose(img)

    canvas = build_canvas(template, validated_elements, images, to_name=to_name, from_name=from_name)

    # ── QR code — always added when Supabase is configured ───────────────────
    print_id = str(uuid.uuid4())
    image_url = None
    if _SUPABASE_URL:
        image_url = f"{_SUPABASE_URL}/storage/v1/object/public/prints/{print_id}.png"
        canvas.add_qr(image_url)

    # ── Supabase: upload + record (best-effort) ───────────────────────────────
    token = authorization.removeprefix("Bearer ").strip()
    if _SUPABASE_URL and _SUPABASE_ANON_KEY and token:
        try:
            sb = _user_client(token)
            user_id = sb.auth.get_user(token).user.id

            buf = io.BytesIO()
            canvas.save_to_buffer(buf)

            sb.storage.from_("prints").upload(
                f"{print_id}.png",
                buf.getvalue(),
                file_options={"content-type": "image/png"},
            )

            sb.table("prints").insert({
                "id": print_id,
                "user_id": user_id,
                "template_id": template,
                "to_name": to_name or None,
                "from_name": from_name or None,
                "image_url": image_url,
            }).execute()

        except Exception:
            traceback.print_exc()

    # ── Local save ────────────────────────────────────────────────────────────
    output_path = None
    if save_image.lower() == "true":
        fname = f"{template}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        output_path = os.path.join("output", fname)
        os.makedirs("output", exist_ok=True)
        canvas.save(output_path)

    if do_print.lower() == "true":
        canvas.print_img()

    return {"status": "success", "template": template, "saved_to": output_path,
            "image_url": image_url, "printed": do_print.lower() == "true"}

@app.post("/api/preview")
async def preview_print(
    template: str = Form(...),
    elements: str = Form(...),
    to_name: str = Form(""),
    from_name: str = Form(""),
    image_0: UploadFile | None = File(None),
    image_1: UploadFile | None = File(None),
):
    try:
        adapter = TypeAdapter(list[Element])
        validated_elements = adapter.validate_python(json.loads(elements))
    except (json.JSONDecodeError, ValidationError) as e:
        raise HTTPException(status_code=422, detail=str(e))

    images = {}
    for key, upload in [("image_0", image_0), ("image_1", image_1)]:
        if upload is not None:
            data = await upload.read()
            img = Image.open(io.BytesIO(data))
            images[key] = ImageOps.exif_transpose(img)

    canvas = build_canvas(template, validated_elements, images, to_name=to_name, from_name=from_name)
    buf = io.BytesIO()
    canvas.save_to_buffer(buf)
    return Response(content=buf.getvalue(), media_type="image/png")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
