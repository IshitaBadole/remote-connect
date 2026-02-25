import os
import string
from pathlib import Path

from escpos.printer import Usb
from PIL import Image, ImageDraw, ImageFont, ImageOps

# TODO: move constants outside functions


def resize_img(img: Image.Image, size: int = 360, centering: float = 0.5):
    """
    Crop image around its center to a 1:1 aspect ratio of the given size
    """
    return ImageOps.fit(img, (size, size), centering=(centering, centering))


def create_polaroid(img: Image.Image, text: str | None = None) -> Image.Image:
    """
    Create a polaroid frame with the given image and text (optional)
    """
    # Thermal printer maximum width is 384 pixels
    image_border = 10
    if text:
        # larger bottom border to have space for text
        bottom_border = 100
    else:
        bottom_border = 10

    img_w, img_h = img.size
    # Create a new white frame with borders
    frame_w = img_w + 2 * image_border
    # frame height = image height + top border + bottom border
    frame_h = img_h + image_border + bottom_border

    frame = Image.new("RGB", (frame_w, frame_h), "white")

    # Paste the image onto the frame centered horizontally
    paste_x = image_border
    paste_y = image_border
    frame.paste(img, (paste_x, paste_y))

    draw = ImageDraw.Draw(frame)
    # add rectangle outline for the frame
    frame_border_width = 2
    frame_border_padding = 0
    draw.rectangle(
        (
            0 + frame_border_padding,
            0 + frame_border_padding,
            frame_w - 1 - frame_border_padding,
            frame_h - 1 - frame_border_padding,
        ),
        outline="black",
        width=frame_border_width,
    )

    if text:
        font_size = 20
        try:
            font = ImageFont.truetype("arial.ttf", font_size)
        except:
            font = ImageFont.load_default(font_size)

        # Calculate text position
        left, top, right, bottom = draw.multiline_textbbox((0, 0), text=text, font=font)
        text_bbox_width = right - left
        text_bbox_height = bottom - top

        text_x = (frame_w - text_bbox_width) / 2
        text_y = image_border + img_h + ((bottom_border - text_bbox_height) / 2)

        draw.multiline_text((text_x, text_y), text, fill="black", font=font)

    return frame


# Initialise USB printer
VENDOR_ID = 0x0485
PRODUCT_ID = 0x5741

def print_image(file_path=None):

    if not file_path:
        img = Image.open("static/people.jpg")
    else:
        img = Image.open(file_path)
    print(f"Image size: {img.size}")
    text = "".join([f"{c}" for c in string.ascii_letters])
    text += "\n"
    # font size = 10 can fit 7 lines, 52 letters each line
    # font size = 14 can fit 5 lines, 39 letters each lines
    num_lines = 5
    full_text = "".join([(f"{text}") for i in range(num_lines)])

    save_image = True
    print_image = True

    img = resize_img(img)
    if not file_path:
        frame = create_polaroid(img, full_text)
    else:
        file_path = Path(f"{file_path}.txt")
        caption = file_path.read_text()
        frame = create_polaroid(img, caption)

    if save_image:
        if not file_path:
            output_image_path = "output/people_polaroid.jpg"
        else:
            file_name = Path(file_path).stem
            output_image_path = f"output/{file_name}_polaroid.jpg"
        directory = os.path.dirname(output_image_path)
        if not os.path.exists(directory):
            os.makedirs(directory, exist_ok=True)

        frame.save(output_image_path)
        print(f"Polaroid saved to {output_image_path}")

    if print_image:
        p = Usb(VENDOR_ID, PRODUCT_ID)
        # Print
        p.image(frame, center=True)

        try:
            p.cut()
        except Exception as e:
            print(f"Cutting the paper is not supported: {e}")

        p.close()


if __name__ == "__main__":
    print_image()