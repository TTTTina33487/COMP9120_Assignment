# Account and password sign-in

The English sign-in page now requires an account ID and a password.
The configured demonstration account ID is `560601108`; use the test password
provided by the project owner. The configured application password is stored as a salted hash. Its plaintext
value is not included in the source, session cookie, screenshot or delivery package.

## Sign in

1. Start the application as described in [LOCAL_SETUP.md](LOCAL_SETUP.md).
2. Enter your account ID in **Account** and the configured password in **Password**.
3. Leave **Workspace** on **Student / Ava Mitchell**, or select
   **Coordinator / Amelia Carter** for the same-school coordinator workflow.
4. Click **Sign in**. The student workspace opens the student overview;
   the coordinator workspace includes review, usage and reports.
5. Use **Sign out** before signing in to the other workspace.

Only these two same-school workspaces are assigned to the default account.
Changing a posted role or actor ID cannot grant access to another workspace.
The previous identity-only login form no longer authenticates a session.

## Configuration

- `DEMO_USERNAME`: account ID; defaults to the configured demonstration account.
- `DEMO_PASSWORD_HASH`: optional Werkzeug password-hash override, never a plaintext password.
- `DEMO_LOGIN=0`: disables this demonstration sign-in flow.

The default password is stored as a salted scrypt hash in
`resource_hub/auth.py`. Credentials are checked by Werkzeug. The session stores
the account identifier and an authentication marker, not the password or its hash.
Changing the configured account or password hash invalidates existing sessions.
CSRF validation, session rotation on sign-in, HttpOnly cookies and school-scoped
resource permissions remain active.

This is one configured prototype account with two explicitly assigned workspaces.
User registration, password recovery and institution-managed identity integration
are outside this change.

## Browser verification

Run the existing integration tests normally; their credentials are isolated test fixtures.
To record the real configured account, run:

```bash
source scripts/env.sh
.venv/bin/python scripts/browser_check.py
```

The script prompts privately for the application password, then fills and submits
the actual sign-in form for both workspaces. Automated environments can supply
`DEMO_TEST_PASSWORD` through their secure process environment instead of the prompt.
The password is never included in the saved verification result or command output.
Captured password inputs are masked.
