# frontend

A new Flutter project.

## Getting Started

Setup supabase database and storage:


Run the backend Flask server:

```
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Run the frontend Flutter app

On Web
```
flutter run -d chrome --web-port 3000 --dart-define-from-file .env
```

On Mobile
```
flutter run --dart-define-from-file .env
```

