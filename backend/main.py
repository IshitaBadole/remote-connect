# backend/main.py
from fastapi.middleware.cors import CORSMiddleware
from fastapi import FastAPI, UploadFile, File, Form
import shutil
import os
import uvicorn
from print_image import print_image

app = FastAPI()

origins = [
    "http://localhost:3000",           # Local Create React App
    "https://remote-connect.ishitabadole.me/"
]

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins, # Adjust this to your React app's URL in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure an 'uploads' directory exists
UPLOAD_DIR = "local_storage"
os.makedirs(UPLOAD_DIR, exist_ok=True)

@app.get("/")
async def root():
    return {"status": "Backend is running"}

@app.get("/api/data")
async def get_data():
    return {"message": "Hello from FastAPI backend!"}

@app.post("/api/upload")
async def upload_memory(
    description: str = Form(...), 
    file: UploadFile = File(...)
):
    # Create a clean filename
    file_path = os.path.join(UPLOAD_DIR, file.filename)
    
    # Save the file locally
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    # Also save the description to a simple text file for now
    with open(f"{file_path}.txt", "w") as f:
        f.write(description)

    print(f"Received: {description}, Saved to: {file_path}")

    print_image(file_path)
    return {"status": "success", "filename": file.filename}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
