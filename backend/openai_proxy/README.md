# AI Proxy

This backend provides a secure proxy for generating AI comfort session suggestions. It encapsulates API keys (e.g., Gemini) so they do not need to be embedded directly in the iOS app.

## Running Locally

1. Create a `.env` file in the root of the project with your API keys:
   ```
   GEMINI_API_KEY=your_key_here
   GEMINI_MODEL=gemini-2.5-flash
   ```
2. Navigate to this folder:
   ```bash
   cd backend/openai_proxy
   ```
3. Install dependencies:
   ```bash
   pip install -r requirements.txt
   ```
4. Run the server:
   ```bash
   uvicorn main:app --reload --port 8000
   ```

## Production

In production, this FastAPI app should be deployed to a service like Render, Heroku, or Google Cloud Run, with the `GEMINI_API_KEY` set in the environment variables of the deployment platform.
