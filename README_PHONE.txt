MONEYMAP PHONE / WEB RELEASE

This project is now a PWA (installable website) and includes a hosted Python backend.
See PHONE_AND_HOSTING_GUIDE.html for the one-time publishing steps and iPhone/Android installation instructions.

Quick summary:
- Owner publishes once using GitHub + Render Blueprint (render.yaml).
- Owner sets OPENAI_API_KEY in Render Environment. Never commit the key.
- Owner adds the Render HTTPS URL to Supabase Authentication URL Configuration.
- Visitors open the HTTPS website on a phone and use Add to Home Screen / Install app.
- Visitors do not extract ZIPs, install npm, or enter Supabase details.

Local Windows use remains available with start-moneymap.bat and MoneyMap-Server.ps1.
Hosted server uses app.py, requirements.txt and gunicorn.
