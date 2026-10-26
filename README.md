# Nimbus

A little cloud for your Mac that listens to class, writes bullet notes, explains what you missed, and pops up live answers when the teacher asks the room a question.

- `app/`: the macOS app (SwiftUI + AppKit, macOS 26). Speech is turned into text on the Mac with Apple's SpeechAnalyzer; only text is sent to the backend.
  - `./scripts/build-app.sh` builds `build/Nimbus.app` for this Mac.
  - `./scripts/package.sh` builds the universal `dist/Nimbus-<version>.dmg` and copies it to `web/public/downloads/Nimbus.dmg`.
- `web/`: the landing page (`public/`) and the backend (`netlify/functions/`), deployed to Netlify.
  - `POST /api/notes` turns the transcript into structured notes.
  - `POST /api/ask` answers questions about the class.
  - `POST /api/answer` streams a short live answer to a question the teacher just asked.
  - Needs the `ANTHROPIC_API_KEY` environment variable (scope: Functions). Uses `claude-opus-5-5`.
