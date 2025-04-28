import json
from firebase_admin import credentials, firestore, initialize_app

# Initialize Firebase
cred = credentials.Certificate("eventconnect-5c542-firebase-adminsdk-fbsvc-2bb5e593e2.json")
initialize_app(cred)
db = firestore.client()

# Load events from the JSON file
with open('events.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

events = data.get("items", [])

for event in events:
    try:
        # Extract required fields
        title = event.get("name", "Untitled Event")
        description = event.get("description", "")
        date = event.get("startsOn", "")
        location = event.get("address", {}).get("address") or event.get("address", {}).get("name", "No Location")
        category = "Chico"
        image = event.get("imageUrl")
        email = "chico@gmail.com"

        # Prepare Firestore document
        doc = {
            "title": title,
            "description": description,
            "date": date,
            "location": location,
            "category": category,
            "email": email,
            "imageUrls": [image] if image else [],
            "createdAt": firestore.SERVER_TIMESTAMP,
            "organizerId": "UF96s49oz7epIK7qGAMY4xlTYrd2",
            "interestedUserEmails": [],
            "interestedUserIds": [],
            "interestedUsers": [],
        }

        db.collection("events").add(doc)
        print(f"✅ Uploaded: {title}")

    except Exception as e:
        print(f"❌ Failed to upload: {event.get('name', 'Unknown')} — {e}")
