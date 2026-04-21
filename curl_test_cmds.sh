# simple_note
curl -X POST http://localhost:8000/api/generate-print \
  -F 'template=simple_note' \
  -F 'elements=[{"type":"text","value":"Good Morning!"}]' \
  -F 'save_image=true' \
  -F 'do_print=false'

# note_with_picture
curl -X POST http://localhost:8000/api/generate-print \
  -F 'template=note_with_picture' \
  -F 'elements=[{"type":"image","image_key":"image_0"},{"type":"text","value":"A nice memory"}]' \
  -F 'save_image=true' \
  -F 'do_print=false' \
  -F 'image_0=@backend/static/people.jpg'

# weekly_mood_tracker
curl -X POST http://localhost:8000/api/generate-print \
  -F 'template=weekly_mood_tracker' \
  -F 'elements=[{"type":"text","value":"How are you feeling?"},{"type":"mood","name":"Alice"},{"type":"text","value":"Just want to check in"}]' \
  -F 'save_image=true' \
  -F 'do_print=false'


curl -X POST http://localhost:8000/api/generate-print \
  -F 'template=health_update' \
  -F 'elements=[
    {"type":"text","value":"Here is every element type:"},
    {"type":"image","image_key":"image_0","style":"polaroid","caption":"A polaroid photo"},
    {"type":"mood","name":"Alice"},
    {"type":"image","image_key":"image_1","style":"full_width"},
    {"type":"icons","names":["involves medical information","need transportation"]},
    {"type":"image","image_key":"image_1","style":"full_width"},
    {"type":"datetime","date":"Mon, Apr 7","time":"10:30 AM"},
    {"type":"yesno","question":"Can you bring me food?"},
    {"type":"weekly_tracker"},
    {"type":"checklist", "tasks":["Pick up prescription", "Buy groceries", "Return package"]}
  ]' \
  -F 'save_image=true' \
  -F 'do_print=false' \
  -F 'image_0=@backend/static/people.jpg' \
  -F 'image_1=@backend/static/cat.jpg'`
