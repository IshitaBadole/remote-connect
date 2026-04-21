from typing import Annotated, Literal, Union

from canvas import Canvas
from pydantic import BaseModel, Field


class TextElement(BaseModel):
    type: Literal["text"]
    value: str


class ImageElement(BaseModel):
    type: Literal["image"]
    image_key: str = "image_0"  # matches the multipart file field name
    style: Literal["full_width", "polaroid"] = "full_width"
    caption: str | None = None


class MoodElement(BaseModel):
    type: Literal["mood"]
    name: str = ""


class IconsElement(BaseModel):
    type: Literal["icons"]
    names: list[str]


class DateTimeElement(BaseModel):
    type: Literal["datetime"]
    date: str
    time: str


class YesNoElement(BaseModel):
    type: Literal["yesno"]
    question: str


class ChecklistElement(BaseModel):
    type: Literal["checklist"]
    tasks: list[str]


class WeeklyTrackerElement(BaseModel):
    type: Literal["weekly_tracker"]


class LocationElement(BaseModel):
    type: Literal["location"]
    name: str
    address: str = ""


# Discriminated union — Pydantic picks the right model by "type" field
Element = Annotated[
    Union[
        TextElement,
        ImageElement,
        MoodElement,
        IconsElement,
        DateTimeElement,
        YesNoElement,
        ChecklistElement,
        WeeklyTrackerElement,
        LocationElement,
    ],
    Field(discriminator="type"),
]


def _dispatch_element(canvas: Canvas, el: Element, images: dict):
    if isinstance(el, TextElement):
        canvas.add_text(el.value)
    elif isinstance(el, ImageElement):
        img = images.get(el.image_key)
        if img:
            canvas.add_image(img, polaroid=el.style == "polaroid", caption=el.caption)
    elif isinstance(el, MoodElement):
        canvas.add_mood_tracker(el.name)
    elif isinstance(el, IconsElement):
        canvas.add_icons(el.names)
    elif isinstance(el, DateTimeElement):
        canvas.add_datetime(el.date, el.time)
    elif isinstance(el, YesNoElement):
        canvas.add_yesno(el.question)
    elif isinstance(el, ChecklistElement):
        canvas.add_checklist(el.tasks)
    elif isinstance(el, WeeklyTrackerElement):
        canvas.add_weekly_tracker()
    elif isinstance(el, LocationElement):
        canvas.add_location(el.name, el.address)


def build_canvas(
    template, validated_elements, images, to_name: str = "", from_name: str = ""
) -> Canvas:
    c = Canvas()
    if to_name:
        c.add_postcard_header(to_name)
    for el in validated_elements:
        _dispatch_element(c, el, images)
    c.add_postcard_footer(from_name)
    return c


class ElementField(BaseModel):
    type: str
    label: str
    required: bool
    has_image: bool = False
    options: list[str] | None = None  # pre-selected icon names for this template


class TemplateMetadata(BaseModel):
    id: str
    display_name: str
    description: str
    sender_role: str = "both"  # "caregiver" | "older_adult" | "both"
    default_elements: list[dict]  # pre-fills the UI form
    allowed_extra_elements: list[str]  # types the user can add (Day 2)
    fields: list[ElementField]  # schema for the UI to render inputs


TEMPLATE_CATALOG: list[TemplateMetadata] = [
    TemplateMetadata(
        id="simple_note",
        display_name="Simple Note",
        description="Write a short note to send",
        sender_role="both",
        default_elements=[{"type": "text", "value": ""}],
        allowed_extra_elements=["yesno", "mood", "datetime"],
        fields=[ElementField(type="text", label="Your message", required=True)],
    ),
    TemplateMetadata(
        id="note_with_picture",
        display_name="Note with Picture",
        description="A photo with a handwritten-style caption",
        sender_role="both",
        default_elements=[
            {"type": "image", "image_key": "image_0", "style": "polaroid"},
            {"type": "text", "value": ""},
        ],
        allowed_extra_elements=["yesno", "mood"],
        fields=[
            ElementField(type="image", label="Photo", required=True, has_image=True),
            ElementField(type="text", label="Caption", required=False),
        ],
    ),
    TemplateMetadata(
        id="weekly_mood_tracker",
        display_name="Weekly Mood Tracker",
        description="Send a weekly mood sheet to fill out",
        sender_role="caregiver",
        default_elements=[
            {"type": "text", "value": ""},
            {"type": "mood", "name": ""},
            {"type": "text", "value": ""},
        ],
        allowed_extra_elements=["yesno", "datetime"],
        fields=[
            ElementField(
                type="text", label="Opening message (optional)", required=False
            ),
            ElementField(
                type="mood",
                label="Who is this tracker for?",
                required=True,
            ),
            ElementField(
                type="text", label="Closing message (optional)", required=False
            ),
        ],
    ),
    TemplateMetadata(
        id="meal_delivery",
        display_name="Meal Delivery",
        description="Coordinate a meal drop-off",
        sender_role="caregiver",
        default_elements=[
            {"type": "text", "value": ""},
            {"type": "datetime"},
            {"type": "icons", "names": ["do together"]},
            {"type": "yesno", "question": ""},
        ],
        allowed_extra_elements=["text"],
        fields=[
            ElementField(
                type="text", label="Notes or special requests", required=False
            ),
            ElementField(type="datetime", label="Date & Time", required=True),
            ElementField(
                type="icons",
                label="Icons",
                required=False,
                options=["do together"],
            ),
            ElementField(type="yesno", label="Yes/No question to ask", required=False),
        ],
    ),
    TemplateMetadata(
        id="health_update",
        display_name="Health Update",
        description="Send a health check-in",
        sender_role="caregiver",
        default_elements=[
            {"type": "image", "image_key": "image_0", "style": "full_width"},
            {"type": "text", "value": ""},
            {"type": "mood", "name": ""},
            {"type": "icons", "names": ["involves medical information"]},
        ],
        allowed_extra_elements=["yesno", "datetime"],
        fields=[
            ElementField(type="image", label="Photo", required=False, has_image=True),
            ElementField(
                type="text", label="What would you like to know?", required=False
            ),
            ElementField(
                type="mood", label="Who is this check-in for?", required=False
            ),
            ElementField(
                type="icons",
                label="Icons",
                required=False,
                options=["involves medical information"],
            ),
        ],
    ),
]
