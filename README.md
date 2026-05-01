# Care Connect

Care Connect is a system that lets family members and caregivers send physical printed notes to older adults via a USB thermal printer. A caregiver or family member fills out a form on their phone or computer, taps send, and a note prints out on a small thermal printer in the older adult's home — no screen required on their end.

The system is designed around one core belief: staying connected should not require the older adult to learn new technology.

---

## How it works

1. A user logs in via email OTP on the Flutter app
2. They choose a **template** from the gallery (e.g. Meal Delivery, Weekly Mood Tracker)
3. They fill in the form fields, optionally preview the print, and tap **Print & Send**
4. The backend renders a PNG and sends it to a USB thermal printer connected to a Raspberry Pi
5. Every print gets a QR code linking to a stored copy in Supabase Storage

---

## Glossary

**Element** — a single visual block on a printed note. Each element has a type: `text`, `image`, `checklist`, `yesno`, `datetime`, `location`, `icons`, `mood`, or `weekly_tracker`. Elements are composed vertically to build up the final printout.

**Template** — a named collection of elements with a fixed order and pre-filled defaults. Templates define what the form looks like in the app and what gets printed. Each template is tagged with a `sender_role` so it only appears for relevant users.

**Template gallery** — the main screen after login. Shows cards for each template available to the logged-in user based on their role (caregiver or older adult). Tapping a card opens the form.

**Element field** — the form input corresponding to one element. A `text` element shows a text field; a `datetime` element shows date and time pickers. Fields can be required or optional.

**Sender role** — each template is tagged `caregiver`, `older_adult`, or `both`. The gallery filters templates so users only see what is relevant to them.

---

## System design

```
frontend/lib/
  main.dart               — app entry, Supabase init, auth flow, profile check
  onboarding_page.dart    — name + role selection on first login
  form_page.dart          — template gallery with role-based filtering
  template_form_page.dart — dynamic form built from template fields
  api.dart                — HTTP client, Supabase profile helpers, data models

backend/
  main.py                 — FastAPI app with endpoints:
                            GET  /api/templates
                            GET  /api/icons
                            POST /api/generate-print
                            POST /api/preview
  templates.py            — Pydantic element models, TEMPLATE_CATALOG, build_canvas
  canvas.py               — Canvas class: renders elements as PIL image strips,
                            saves to file or buffer, sends to USB printer
  static/icons/           — PNG icon assets served at /static/icons/
  output/                 — locally saved PNG copies of each print

database/
  profiles.sql            — profiles table (name, role) with auto-create trigger
  prints.sql              — prints table with storage URL and user FK
  print_responses.sql     — future: links photo responses to original prints
```

**Request flow for a print:**

1. Flutter collects form values → calls `POST /api/generate-print` with `elements` JSON, images as multipart, and a JWT in the `Authorization` header
2. `main.py` validates elements against a Pydantic discriminated union and applies `ImageOps.exif_transpose` to correct phone camera rotation
3. `build_canvas()` in `templates.py` dispatches each element to the matching `canvas.add_*()` method
4. Each `add_*()` method creates a 384px-wide PIL image strip and appends it to `self.strips`
5. `canvas.render()` stacks all strips vertically into the final image
6. A QR code linking to Supabase Storage is appended, the image is uploaded, and a row is inserted into `prints`
7. The image is saved locally to `output/` and sent to the USB printer

---

## What you need

- A **Raspberry Pi** (any model with USB) running Raspberry Pi OS
- A **USB thermal printer** — we used a 58mm (384px paper width) model. If your printer uses a different paper width, update `PAPER_WIDTH` in `backend/canvas.py` and the canvas should adapt automatically
- An **iOS, Android, or macOS device** to run the Flutter app, or a web browser
- A **Supabase account** (free tier is sufficient)
- **Python 3.11+** on the Pi and **Flutter SDK 3.11+** on the development machine

---

## Supabase setup

### 1. Create a project

Go to [supabase.com](https://supabase.com), create a new project, and note your **Project URL** and **anon key** from Project Settings → API.

### 2. Run the database schema

In the SQL Editor, run each file in `database/` in this order:

1. `database/profiles.sql`
2. `database/prints.sql`
3. `database/print_responses.sql`

### 3. Create a Storage bucket

Go to **Storage → New bucket**, name it `prints`, and set it to **public** so QR code URLs are accessible without authentication.

Then add this storage policy in the SQL editor:

```sql
create policy "authenticated upload" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'prints');
```

### 4. Disable email confirmations

Go to **Authentication → Settings → Email Auth** and disable **Enable email confirmations**. This ensures all users receive a 6-digit OTP code rather than a magic link.

### 5. Configure environment variables

Create `frontend/.env` — this file is gitignored and must never be committed:

```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_DEFAULT_KEY=your-anon-key
BACKEND_URL=http://<pi-ip-address>:8000
```

The backend reads from this same file automatically via `python-dotenv`.

---

## Raspberry Pi setup

The Pi sits in the older adult's home, connected to the thermal printer by USB. Once set up, it only needs to be powered on — the server starts automatically on boot and waits for print requests from family members on the same network.

### 1. Clone the repo

```bash
git clone https://github.com/your-username/remote-connect.git
cd remote-connect/backend
```

### 2. Set up Python environment

```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### 3. Install fonts

The canvas renderer uses `arial.ttf` and `arialbd.ttf`. On Raspberry Pi OS, install Liberation fonts as a compatible alternative:

```bash
sudo apt install fonts-liberation
```

Then update `_get_font()` in `backend/canvas.py` to use the installed font paths:

```python
font_file = "/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf" if name == "bold" \
    else "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf"
```

### 4. Configure environment variables

Copy your `frontend/.env` file to the Pi. The backend automatically loads it from `../frontend/.env` relative to `backend/`.

### 5. Configure the printer

Find your printer's USB vendor and product IDs:

```bash
lsusb
# Example: Bus 001 Device 003: ID 0485:5741 ...
```

Update these constants near the top of `backend/canvas.py`:

```python
VENDOR_ID = 0x0485   # replace with your printer's vendor ID
PRODUCT_ID = 0x5741  # replace with your printer's product ID
```

If your printer uses a different paper width, also update:

```python
self.PAPER_WIDTH = 384  # pixels — 384 corresponds to 58mm at 203dpi
```

Grant USB access without requiring sudo:

```bash
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="0485", ATTR{idProduct}=="5741", MODE="0666"' \
  | sudo tee /etc/udev/rules.d/99-thermal-printer.rules
sudo udevadm control --reload-rules
```

### 6. Auto-start on boot

Create a systemd service so the backend starts whenever the Pi is powered on:

```bash
sudo nano /etc/systemd/system/care-connect.service
```

Paste the following, replacing `/home/pi` with your actual home directory if different:

```ini
[Unit]
Description=Care Connect backend
After=network.target

[Service]
User=pi
WorkingDirectory=/home/pi/remote-connect/backend
ExecStart=/home/pi/remote-connect/backend/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable care-connect
sudo systemctl start care-connect

# Confirm it is running
sudo systemctl status care-connect
```

From this point, the Pi only needs to be plugged in and powered on. The server starts automatically, the printer is ready, and family members can send prints from anywhere on the same network.

To view server logs at any time:

```bash
sudo journalctl -u care-connect -f
```

---

## Updating the server on the Pi

> **Note:** The steps below have not been tested in a live remote deployment. They are a suggested approach for when the Pi is in a remote location and the backend needs to be updated.

### From the same network

If your device is on the same Wi-Fi as the Pi, SSH in using its local IP:

```bash
ssh pi@<pi-ip-address>
```

Then pull the latest code and restart the service:

```bash
cd remote-connect
git pull
sudo systemctl restart care-connect

# Confirm the new version is running
sudo systemctl status care-connect
```

If dependencies changed, reinstall before restarting:

```bash
source backend/venv/bin/activate
pip install -r backend/requirements.txt
sudo systemctl restart care-connect
```

### From a remote location (different network)

If the Pi is in someone else's home and not on your local network, you will need a way to reach it over the internet. **Tailscale** is one option — it is a free mesh VPN that allows SSH access to the Pi from anywhere without requiring port forwarding on the remote router.

Suggested setup:

1. On the Pi: install Tailscale and authenticate it to your Tailscale account
   ```bash
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up
   ```
2. On your development machine: install Tailscale and sign in with the same account
3. Find the Pi's Tailscale IP in the admin console (typically `100.x.x.x`)
4. SSH using the Tailscale IP: `ssh pi@100.x.x.x`
5. Then `git pull` and `sudo systemctl restart care-connect` as above

This approach has not been tested in this project. Other options worth considering include exposing SSH via a reverse tunnel (e.g. with `ngrok` or `bore`) or setting up a VPN on the remote router directly.

---

## Flutter app setup

### Requirements

- Flutter SDK 3.11+
- Xcode (for iOS/macOS builds)
- `frontend/.env` configured (see Supabase setup)

### Run on a device or simulator

```bash
cd frontend
flutter pub get
flutter run --dart-define-from-file .env
```

To target a specific device:

```bash
flutter devices                                          # list connected devices
flutter run -d <device-id> --dart-define-from-file .env
```

### Run in a web browser

```bash
flutter run -d chrome --dart-define-from-file .env
```

The camera picker is not available in browsers. File upload from disk works fine.

### Build for iOS (iPad or iPhone)

1. Open `frontend/ios/Runner.xcworkspace` in Xcode
2. Select your device from the device dropdown
3. Under **Signing & Capabilities**, select your Apple development team
4. Press **Run**

The device and the Pi must be on the same Wi-Fi network.

### Keeping the Pi's IP stable

If the Pi's IP address changes after a router restart, update `BACKEND_URL` in `frontend/.env` and rebuild the app. To avoid this, assign the Pi a **static IP** in your router's settings — usually listed as "Address Reservation" or "DHCP Reservation." Use the Pi's MAC address (`ip link show`) to pin it to a fixed IP permanently.

---

## Adding a new icon

Icons appear as printable stamps on notes and as selectable options in the icon picker form field.

1. Create a PNG with a transparent background, square dimensions (e.g. 128×128px)
2. Name it in lowercase with underscores, e.g. `involves_finances.png`
3. Place it in `backend/static/icons/`

Icons whose filenames start with `emotion_` (e.g. `emotion_happy.png`) are reserved for the mood tracker rows and are automatically excluded from the picker. No code changes needed — `GET /api/icons` reads the directory at runtime.

---

## Adding a new element type

**1. Backend model** — add a Pydantic class in `backend/templates.py`:

```python
class MyElement(BaseModel):
    type: Literal["my_type"]
    my_field: str
```

Add it to the `Element` union and dispatch it in `_dispatch_element`:

```python
elif isinstance(el, MyElement):
    canvas.add_my_type(el.my_field)
```

**2. Canvas renderer** — add `add_my_type()` to the `Canvas` class in `backend/canvas.py`. The method must create a PIL `Image` strip exactly `self.PAPER_WIDTH` (384px) wide and append it to `self.strips`:

```python
def add_my_type(self, my_field: str) -> None:
    strip = Image.new("RGB", (self.PAPER_WIDTH, 60), "white")
    draw = ImageDraw.Draw(strip)
    # draw your content here
    self.strips.append(strip)
```

**3. Flutter form** — in `frontend/lib/template_form_page.dart`:
- Initialise state in the `initState` switch
- Add a `_buildMyTypeField()` widget method
- Add a case in `_buildField()` to return it
- Add a case in `_buildElements()` to serialise it to JSON
- Add a required-field check in `_send()` if applicable

---

## Adding a new template

Templates live entirely in `backend/templates.py`. No other backend file needs to change.

Add a `TemplateMetadata` entry to `TEMPLATE_CATALOG`:

```python
TemplateMetadata(
    id="my_template",                     # unique snake_case id
    display_name="My Template",
    description="One sentence description",
    sender_role="caregiver",              # "caregiver" | "older_adult" | "both"
    default_elements=[
        {"type": "text", "value": ""},
        {"type": "datetime"},
    ],
    allowed_extra_elements=[],
    fields=[
        ElementField(type="text", label="Your message", required=True),
        ElementField(type="datetime", label="Date & Time", required=True),
    ],
),
```

Optionally add a gallery card icon in `frontend/lib/form_page.dart` inside `_iconForTemplate()`:

```dart
case 'my_template': return Icons.my_icon;
```

Restart the backend — the new template appears in the gallery immediately.

---

## Limitations and future work

### One printer per household

The system assumes a single printer at the older adult's home. There is no option to print to a different destination — for example, sending a personal copy to a caregiver's own printer.

**Suggested approach:** Introduce a `printer_id` field in user profiles. Each Pi registers itself with a unique ID in a `printers` Supabase table on startup. The Flutter app lets the sender choose from registered printers. Replace the direct HTTP call with a `print_jobs` table — the Flutter app inserts a job row, and the Pi subscribes to new rows via Supabase Realtime and processes them as they arrive.

### Devices must be on the same network

The Pi's address is set at build time in `frontend/.env`, so the app only works when the sender's device and the Pi are on the same local network. A distant family member cannot send a print over the internet.

**Suggested approach:** The job queue approach described above solves this at the same time. Once the Pi processes jobs from Supabase rather than receiving direct HTTP calls, the sender and the Pi no longer need to be on the same network or even online simultaneously.

### QR code response flow

Every print includes a QR code that links to its stored image in Supabase. The intended use is: the older adult fills out or marks a template with a pen, someone photographs it with the app, and the app links the photo back to the original print. This would enable tracking of routines, checklists, and mood over time.

The database schema already exists in `database/print_responses.sql`. What remains:
- A screen in the Flutter app to scan the QR code (using the `mobile_scanner` package) and pre-populate `original_print_id`
- An image picker to attach the filled-out photo
- A `POST /api/submit-response` endpoint that uploads the photo and inserts into `print_responses`
- A Supabase Realtime subscription or push notification to alert the original sender

### Custom and composable templates

The template gallery is currently static — every template is defined in code. A natural extension would be letting users compose their own templates by adding elements from a picker, or saving a personalised version of an existing template.

**Suggested approach:** Store custom templates as JSON in a `custom_templates` Supabase table, keyed by `user_id`. The Flutter form page gets an "Add element" button that opens a picker of available element types. `GET /api/templates` merges the static catalog with the current user's saved templates. The backend already handles arbitrary element lists, so no rendering changes are needed.

---

## Environment variables reference

| Variable | Used by | Description |
|---|---|---|
| `SUPABASE_URL` | Flutter + backend | Your Supabase project URL |
| `SUPABASE_PUBLISHABLE_DEFAULT_KEY` | Flutter + backend | Supabase anon key |
| `BACKEND_URL` | Flutter only | Pi's local IP and port, e.g. `http://192.168.1.42:8000` |

All three go in `frontend/.env`. Flutter reads them at build time via `--dart-define-from-file .env`. The backend reads the same file at startup via `python-dotenv`.

---

## Acknowledgements

Care Connect was designed and built by **Ishita Badole** as part of CSCI 5900: Master's Level Independent Study at the University of Colorado Boulder.

Thanks to **Krithik Ranjan**, **Dr. Stephen Voida** and **the TMI lab** for their collaboration, advising, and feedback throughout the project.