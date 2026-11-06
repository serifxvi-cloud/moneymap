MONEYMAP — EMAIL ACCOUNTS EDITION
=================================

CREATE AN ACCOUNT
1. Extract this folder.
2. Double-click start-moneymap.bat.
3. Open the Your MoneyMap account section.
4. Enter your email and choose a password (at least 8 characters).
5. Click Create account.
6. If asked, open the confirmation email and verify your address. Return to MoneyMap and sign in.

No Supabase URL, API key, npm, Node.js, or dashboard setup is required from an ordinary user. MoneyMap is preconfigured to connect to its account service.

SIGN IN / PASSWORD RESET
- Enter the email and password used when creating the account, then click Sign in.
- For a forgotten password, enter your email and click Reset password.
- Sign out does not delete data stored on this device or in your cloud account.

CLOUD SYNC
When signed in, MoneyMap backs up your profile, weekly transactions, notes, and AI chat history to your account. Use Sync now to request an immediate save.

IMPORTANT FOR THE APP OWNER
This build uses the configured Supabase project for authentication and cloud storage. The browser contains only its public publishable key (not a secret key). The Supabase project must have email/password authentication enabled, email delivery configured, and the included MONEYMAP_CLOUD_SETUP.sql applied once by the project administrator. This is owner-side infrastructure setup, not something each MoneyMap user needs to do. If the database table has not been created or email confirmation is misconfigured, account creation or sync can fail until the project owner fixes it.

AI CHAT
The AI coach uses a separate API key through the local PowerShell server. Account creation does not require an AI key.

SECURITY
Never put a Supabase secret/service_role key in this website. The included public key is designed for browser use; private account data relies on authentication and Row Level Security.
