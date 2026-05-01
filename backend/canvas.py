import os
import string
from datetime import datetime, timedelta
from pathlib import Path

import qrcode
from escpos.printer import Usb
from PIL import Image, ImageDraw, ImageFont, ImageOps

# Initialise USB printer
VENDOR_ID = 0x0485
PRODUCT_ID = 0x5741


class Canvas:
    def __init__(self):
        self.PAPER_WIDTH = 384
        self.current_y = 0
        self.strips: list[Image.Image] = []
        self._font_cache: dict[tuple, ImageFont] = {}
        self.p = None

    def _get_font(self, name: str, size: int) -> ImageFont.FreeTypeFont:
        key = (name, size)
        if key not in self._font_cache:
            try:
                font_file = "arialbd.ttf" if name == "bold" else "arial.ttf"
                self._font_cache[key] = ImageFont.truetype(font_file, size)
            except (IOError, OSError):
                self._font_cache[key] = ImageFont.load_default(size)
        return self._font_cache[key]

    def _wrap_text(
        self, text: str, font: ImageFont.FreeTypeFont, max_width: int
    ) -> list[str]:
        dummy_draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        lines = []
        for paragraph in text.splitlines():
            words = paragraph.split()
            if not words:
                lines.append("")
                continue
            current = words[0]
            for word in words[1:]:
                candidate = current + " " + word
                if dummy_draw.textlength(candidate, font=font) <= max_width:
                    current = candidate
                else:
                    lines.append(current)
                    current = word
            lines.append(current)
        return lines

    def add_text(
        self,
        text: str,
        font_size: int = 20,
        bold: bool = False,
        align: str = "left",
        padding: int = 12,
    ) -> None:
        font = self._get_font("bold" if bold else "regular", font_size)
        max_width = self.PAPER_WIDTH - (2 * padding)
        lines = self._wrap_text(text, font, max_width)

        dummy_draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        line_height = (
            dummy_draw.textbbox((0, 0), "Ag", font=font)[3] + 4
        )  # height + line spacing
        strip_height = line_height * len(lines) + 2 * padding

        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_height), "white")
        draw = ImageDraw.Draw(strip)

        y = padding
        for line in lines:
            if align == "center":
                x = (self.PAPER_WIDTH - draw.textlength(line, font=font)) / 2
            elif align == "right":
                x = self.PAPER_WIDTH - padding - draw.textlength(line, font=font)
            else:
                x = padding
            draw.text((x, y), line, fill="black", font=font)
            y += line_height

        self.strips.append(strip)

    def _draw_checkbox(
        self, draw: ImageDraw.ImageDraw, x: int, y: int, size: int
    ) -> None:
        pad = max(2, size // 10)
        draw.rectangle(
            [x + pad, y + pad, x + size - pad, y + size - pad], outline="black", width=2
        )

    def add_yesno(self, question: str, padding: int = 12) -> None:
        font = self._get_font("regular", 20)
        dummy_draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        line_height = dummy_draw.textbbox((0, 0), "Ag", font=font)[3] + 4

        lines = self._wrap_text(question, font, self.PAPER_WIDTH - 2 * padding)
        question_height = line_height * len(lines) + padding
        strip_height = question_height + line_height + padding

        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_height), "white")
        draw = ImageDraw.Draw(strip)

        y = padding
        for line in lines:
            draw.text((padding, y), line, fill="black", font=font)
            y += line_height

        # Yes / No checkboxes on same row
        self._draw_checkbox(draw, padding, y, line_height)
        draw.text((padding + line_height + 6, y), "Yes", fill="black", font=font)

        no_x = padding + line_height + 6 + int(draw.textlength("Yes", font=font)) + 20
        self._draw_checkbox(draw, no_x, y, line_height)
        draw.text((no_x + line_height + 6, y), "No", fill="black", font=font)

        self.strips.append(strip)

    def _flatten_alpha(self, img: Image.Image) -> Image.Image:
        """Composite RGBA/P images onto a white background, return RGB."""
        if img.mode in ("RGBA", "LA", "P"):
            background = Image.new("RGB", img.size, "white")
            background.paste(img, mask=img.convert("RGBA").split()[3])
            return background
        return img.convert("RGB")

    def add_image(
        self, img: Image.Image, polaroid: bool = False, caption: str | None = None
    ) -> None:
        img = self._flatten_alpha(img)
        if polaroid:
            # Square-crop to 360px, wrap in polaroid frame (380px wide), center on 384px strip
            img = resize_img(img)
            frame = create_polaroid(img, caption)
            strip = Image.new("RGB", (self.PAPER_WIDTH, frame.height), "white")
            strip.paste(frame, ((self.PAPER_WIDTH - frame.width) // 2, 0))
        else:
            # Resize preserving aspect ratio to fill paper width minus padding
            padding = 10
            max_w = self.PAPER_WIDTH - 2 * padding
            scale = max_w / img.width
            img = img.resize((max_w, int(img.height * scale)), Image.LANCZOS)
            strip = Image.new(
                "RGB", (self.PAPER_WIDTH, img.height + 2 * padding), "white"
            )
            strip.paste(img, (padding, padding))

        self.strips.append(strip)

    def add_weekly_tracker(self):
        # 1. Setup for 384px wide thermal paper
        width = 384
        row_height = 120  # Height per day
        height = row_height * 7 + 100  # 7 days + some margin
        img = Image.new("RGB", (width, height), "white")
        draw = ImageDraw.Draw(img)

        # 2. Dates
        now = datetime.now()
        monday = now - timedelta(days=now.weekday())

        font_large = self._get_font("bold", 24)
        font_small = self._get_font("regular", 18)

        # 3. Draw Header
        draw.text(
            (width // 2, 30),
            "WEEKLY CHECKLIST",
            fill="black",
            font=font_large,
            anchor="mm",
        )
        draw.line([(20, 60), (364, 60)], fill="black", width=2)

        # 4. Draw Daily Rows
        for i in range(7):
            y_offset = 80 + (i * row_height)
            curr_date = monday + timedelta(days=i)

            # Draw Day & Date (Left Aligned)
            date_str = curr_date.strftime("%a %d")
            draw.text(
                (20, y_offset + 40),
                date_str,
                fill="black",
                font=font_large,
                anchor="lm",
            )

            # Draw 3 Large Bubbles (Right Aligned)
            bubble_radius = 22
            for b in range(3):
                # Spacing bubbles from the right edge
                bx = width - 50 - (b * 65)
                by = y_offset + 40
                bbox = [
                    bx - bubble_radius,
                    by - bubble_radius,
                    bx + bubble_radius,
                    by + bubble_radius,
                ]

                # Draw the bubble
                draw.ellipse(bbox, outline="black", width=3)
                # Label above bubble (optional)
                draw.text(
                    (bx, by - 35), f"T{3-b}", fill="black", font=font_small, anchor="mm"
                )

            # Row Separator
            draw.line(
                [(10, y_offset + row_height), (374, y_offset + row_height)],
                fill="lightgrey",
                width=1,
            )

        # 5. Add Corner Registration Marks (Crucial for OpenCV)
        # Top-left and Bottom-right anchors
        draw.rectangle([0, 0, 30, 30], fill="black")
        draw.rectangle([width - 30, height - 30, width, height], fill="black")

        self.strips.append(img)

    def add_checklist(self, tasks: list[str], padding: int = 12, font_size: int = 20):
        font = self._get_font("regular", font_size)
        dummy_draw = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        line_height = dummy_draw.textbbox((0, 0), "Ag", font=font)[3] + 4
        strip_height = line_height * len(tasks) + 2 * padding

        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_height), "white")
        draw = ImageDraw.Draw(strip)

        y = padding
        for task in tasks:
            self._draw_checkbox(draw, padding, y, line_height)
            draw.text((padding + line_height + 6, y), task, fill="black", font=font)
            y += line_height
        self.strips.append(strip)

    def add_qr(self, data: str, size: int = 160):
        """Render a QR code centred on the paper. size is the pixel dimension."""
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_H,
            box_size=10,
            border=4,
        )
        qr.add_data(data)
        qr.make(fit=True)
        qr_img = qr.make_image(fill_color="black", back_color="white").get_image()
        qr_img = qr_img.resize((size, size), Image.LANCZOS)
        strip = Image.new("RGB", (self.PAPER_WIDTH, size + 16), "white")
        strip.paste(qr_img, ((self.PAPER_WIDTH - size) // 2, 8))
        self.strips.append(strip)

    def add_mood_tracker(self, name):
        moods = ["emotion_sad", "emotion_okay", "emotion_happy"]
        icon_size = 56
        row_height = 70
        date_col_width = 110
        header_h = 40
        subheader_h = 28

        # Evenly space 3 icons in the right column
        icons_area = self.PAPER_WIDTH - date_col_width
        spacing = (icons_area - 3 * icon_size) // 4
        icon_xs = [
            date_col_width + spacing + i * (icon_size + spacing) for i in range(3)
        ]
        icon_centers = [x + icon_size // 2 for x in icon_xs]

        total_height = header_h + subheader_h + 7 * row_height
        img = Image.new("RGB", (self.PAPER_WIDTH, total_height), "white")
        draw = ImageDraw.Draw(img)

        font_name = self._get_font("regular", 16)
        font_date = self._get_font("bold", 20)
        font_label = self._get_font("regular", 13)

        # Name centered at top, smaller font
        header = f"{name}'s mood this week" if name else "mood this week"
        draw.text(
            (self.PAPER_WIDTH // 2, header_h // 2),
            header,
            fill="black",
            font=font_name,
            anchor="mm",
        )
        draw.line(
            [(10, header_h), (self.PAPER_WIDTH - 10, header_h)], fill="black", width=1
        )

        # Mood labels as column headers — drawn once (strip emotion_ prefix)
        for i, mood in enumerate(moods):
            draw.text(
                (icon_centers[i], header_h + subheader_h // 2),
                mood.replace("emotion_", ""),
                fill="black",
                font=font_label,
                anchor="mm",
            )
        draw.line(
            [
                (10, header_h + subheader_h),
                (self.PAPER_WIDTH - 10, header_h + subheader_h),
            ],
            fill="lightgrey",
            width=1,
        )

        # Daily rows — icons only, no repeated labels
        now = datetime.now()
        monday = now - timedelta(days=now.weekday())

        for i in range(7):
            y_top = header_h + subheader_h + i * row_height
            curr_date = monday + timedelta(days=i)

            draw.text(
                (20, y_top + row_height // 2),
                curr_date.strftime("%a %d"),
                fill="black",
                font=font_date,
                anchor="lm",
            )

            icon_y = y_top + (row_height - icon_size) // 2
            for j, mood in enumerate(moods):
                icon = Image.open(
                    os.path.join("static", "icons", f"{mood}.png")
                ).convert("RGBA")
                icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
                img.paste(icon, (icon_xs[j], icon_y), mask=icon.split()[3])

            draw.line(
                [
                    (10, y_top + row_height - 1),
                    (self.PAPER_WIDTH - 10, y_top + row_height - 1),
                ],
                fill="lightgrey",
                width=1,
            )

        self.strips.append(img)

    def add_icons(self, names: list[str], padding: int = 12) -> None:
        icon_size = 48
        circle_pad = 8
        cell = icon_size + 2 * circle_pad  # diameter of the bordered circle
        gap = 12

        n = len(names)
        total_width = n * cell + (n - 1) * gap
        strip_height = cell + 2 * padding

        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_height), "white")
        draw = ImageDraw.Draw(strip)

        # Right-aligned
        start_x = self.PAPER_WIDTH - padding - total_width

        for i, name in enumerate(names):
            icon = Image.open(os.path.join("static", "icons", f"{name}.png")).convert("RGBA")
            icon = icon.resize((icon_size, icon_size), Image.LANCZOS)
            bg = Image.new("RGB", (icon_size, icon_size), "white")
            bg.paste(icon, mask=icon.split()[3])

            cx = start_x + i * (cell + gap)
            cy = padding
            draw.ellipse([cx, cy, cx + cell, cy + cell], outline="black", width=2)
            strip.paste(bg, (cx + circle_pad, cy + circle_pad))

        self.strips.append(strip)

    def add_location(self, name: str, address: str = "", padding: int = 12) -> None:
        font_name = self._get_font("bold", 20)
        font_addr = self._get_font("regular", 17)
        dummy = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        name_h = dummy.textbbox((0, 0), "Ag", font=font_name)[3] + 4
        addr_h = dummy.textbbox((0, 0), "Ag", font=font_addr)[3] + 4

        # pin head radius and tail height
        pin_r = 10
        pin_tail = 8
        pin_w = pin_r * 2 + 2
        pin_total_h = pin_r * 2 + pin_tail

        text_x = padding + pin_w + 8
        max_text_w = self.PAPER_WIDTH - text_x - padding

        name_lines = self._wrap_text(name, font_name, max_text_w)
        addr_lines = self._wrap_text(address, font_addr, max_text_w) if address else []

        content_h = name_h * len(name_lines) + addr_h * len(addr_lines)
        strip_h = max(pin_total_h, content_h) + 2 * padding

        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_h), "white")
        draw = ImageDraw.Draw(strip)

        # Draw map-pin shape: filled circle + triangle tail
        cx = padding + pin_r + 1
        cy = padding + pin_r
        draw.ellipse([cx - pin_r, cy - pin_r, cx + pin_r, cy + pin_r], fill="black")
        draw.ellipse([cx - pin_r + 3, cy - pin_r + 3, cx + pin_r - 3, cy + pin_r - 3], fill="white")
        draw.polygon([
            (cx - 4, cy + pin_r - 2),
            (cx + 4, cy + pin_r - 2),
            (cx, cy + pin_r + pin_tail),
        ], fill="black")

        # Place name
        y = padding
        for line in name_lines:
            draw.text((text_x, y), line, fill="black", font=font_name)
            y += name_h

        # Address
        for line in addr_lines:
            draw.text((text_x, y), line, fill="#444444", font=font_addr)
            y += addr_h

        self.strips.append(strip)

    def add_datetime(self, date: str, time: str, padding: int = 12) -> None:
        self.add_text(f"Date: {date}   Time: {time}", padding=padding)

    def add_postcard_header(self, to_name: str, padding: int = 14) -> None:
        font = self._get_font("bold", 22)
        dummy = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        line_h = dummy.textbbox((0, 0), "Ag", font=font)[3] + 4
        strip_h = line_h + 2 * padding + 2  # +2 for bottom rule
        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_h), "white")
        draw = ImageDraw.Draw(strip)
        draw.text((padding, padding), f"To: {to_name}", fill="black", font=font)
        draw.line([(0, strip_h - 2), (self.PAPER_WIDTH, strip_h - 2)], fill="black", width=2)
        self.strips.insert(0, strip)  # prepend — always first

    def add_postcard_footer(self, from_name: str, padding: int = 14) -> None:
        font = self._get_font("regular", 18)
        font_bold = self._get_font("bold", 18)
        dummy = ImageDraw.Draw(Image.new("RGB", (1, 1)))
        line_h = dummy.textbbox((0, 0), "Ag", font=font)[3] + 4
        strip_h = line_h + 2 * padding + 2
        strip = Image.new("RGB", (self.PAPER_WIDTH, strip_h), "white")
        draw = ImageDraw.Draw(strip)
        draw.line([(0, 1), (self.PAPER_WIDTH, 1)], fill="black", width=2)
        date_str = datetime.now().strftime("%B %d, %Y")
        draw.text((padding, padding + 2), date_str, fill="black", font=font)
        from_text = f"From: {from_name}"
        from_w = draw.textlength(from_text, font=font_bold)
        draw.text((self.PAPER_WIDTH - padding - from_w, padding + 2), from_text, fill="black", font=font_bold)
        self.strips.append(strip)

    def render(self) -> Image:
        total_height = sum(s.height for s in self.strips)
        canvas = Image.new("RGB", (self.PAPER_WIDTH, total_height), "white")
        y = 0
        for strip in self.strips:
            canvas.paste(strip, (0, y))
            y += strip.height
        return canvas

    def save(self, output_path: str = "output/output.jpg"):
        canvas = self.render()
        directory = os.path.dirname(output_path)
        if not os.path.exists(directory):
            os.makedirs(directory, exist_ok=True)

        canvas.save(output_path)
        print(f"Canvas saved to {output_path}")

    def save_to_buffer(self, buf):
        self.render().save(buf, format="PNG")

    def print_img(self):
        canvas = self.render()
        try:
            self.p = Usb(VENDOR_ID, PRODUCT_ID)
            self.p.image(canvas, center=True)

            try:
                self.p.cut()
            except Exception as e:
                print(f"Cutting the paper is not supported: {e}")

            self.p.close()
        except Exception as e:
            raise RuntimeError(f"Printer not available: {e}")


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
    image_margin = 10
    if text:
        # larger bottom border to have space for text
        bottom_border = 100
    else:
        bottom_border = 10

    image_width, image_height = img.size
    # Create a new white frame with borders
    frame_w = image_width + (2 * image_margin)
    # frame height = image height + top border + bottom border
    frame_h = image_height + image_margin + bottom_border

    frame = Image.new("RGB", (frame_w, frame_h), "white")

    # Paste the image onto the frame centered horizontally
    paste_x = image_margin
    paste_y = image_margin
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
        text_y = image_margin + image_height + ((bottom_border - text_bbox_height) / 2)

        draw.multiline_text((text_x, text_y), text, fill="black", font=font)

    return frame


def print_image(file_path="static/people.jpg", layout="default"):

    img = Image.open(file_path)
    print(f"Image size: {img.size}")
    img = resize_img(img)

    save_image = True
    print_image = True

    if not file_path:
        text = "".join([f"{c}" for c in string.ascii_letters])
        text += "\n"
        # font size = 10 can fit 7 lines, 52 letters each line
        # font size = 14 can fit 5 lines, 39 letters each lines
        num_lines = 5
        full_text = "".join([(f"{text}") for i in range(num_lines)])
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
