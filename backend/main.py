# backend/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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

@app.get("/")
async def root():
    return {"status": "Backend is running"}

@app.get("/api/data")
async def get_data():
    return {"message": "Hello from FastAPI backend!"}
