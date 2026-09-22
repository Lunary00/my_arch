---
name: outbound-email-sending
description: "Use when the user asks you to send an email for them."
version: 0.1.0
metadata:
  hermes:
    tags: [Email, Outbound, Sending, Recipients, Confirmation]
    related_skills: [m365-mailbox, himalaya, google-workspace, email-inbox-triage]
---

# Outbound Email Sending

Compose and send mail **as the user**. Triggers: "envie um email para <nome> avisando que ...", "send an email to <name> saying ...", "tell <person> the <thing> worked", or any request whose deliverable is mail leaving the user's account. Connector skills (`m365-mailbox`, `himalaya`, `google-workspace`) own provider mechanics; this skill owns the decisions around them: who the recipient really is, how the message should read, when to stop and ask, and how to prove it went out. Not for inbox triage (`email-inbox-triage`) or read-only retrieval.

## Procedure

### 1. Locate the configured backend before composing

Check which backend actually exists on this machine: an M365 Graph profile (`~/.openclaw/secrets/m365-mailbox/<profile>.json`), a himalaya config (`~/.config/himalaya/config.toml`), or google-workspace credentials. Use the one that is set up; do not invent another.

For a Graph profile, read the JSON first — it carries the sending address, `requestedScopes`, and `policy.allow` / `policy.requireConfirm`. Done when you know the sending address and the confirmation gate.

### 2. Resolve the recipient; never guess it

A first name the user drops casually is not an address. Match it against what the mailbox already holds and disambiguate before composing:

- Minimal-consent Graph profiles have no Contacts/People access, so scan the mailbox itself (paged `/me/messages` over `from`/`toRecipients`/`ccRecipients`, aggregate distinct addresses in code). Recipe: `references/graph-recipient-and-send.md`.
- Present candidates with display name, address, domain, and how often/last they appeared, then ask which one. One first name legitimately maps to several people (a colleague, a supplier contact, a namesake).
- Drop automated senders before the list reaches the user: `no-reply@`/notification domains and "Name via <service>" aliases repeat one real person as several rows and bury the humans. Filter on the address or domain, never on the display name, which usually carries the person's real name.
- Do not treat the sending domain as the deciding signal. One company routinely operates several domains (the user may send from one while colleagues sit on another), so rank candidates by being a real human correspondent plus recency and message volume instead of by domain match.
- A partial address the user gave (local part only, no domain) that matches exactly one human candidate does not need a question of its own: fold the resolved address into the same confirmation that shows the draft text (step 4), so one answer approves recipient and wording together.

Done when the To: address was confirmed by the user or was stated unambiguously in the request.

### 3. Compose in the user's voice

- Language: Brazilian Portuguese by default; match the thread's language when replying into a non-PT exchange.
- Short. Greeting, one line carrying the news, at most one supporting detail, sign-off. No bullets, no restating the request, no narrating how the work was done.
- Sign with the account's own display name (`Abraço,` + full name).
- A status update is a status update: no invented deadlines, numbers, or commitments.
- Wording you cannot ground is not yours to invent. When the content hinges on a term you do not recognise — a nickname, an in-joke, a word that may be a typo — grep the mailbox for it first, since an inside term leaves traces in old threads; if nothing turns up, ask for the sentence instead of paraphrasing it. Keep the user's own spelling, accents included, and say in the report that it went out verbatim.
- A one-line playful message ("tell X he is the ...") asserts nothing and owes no explanation: send the line with greeting and sign-off, and do not pad it with invented context.

### 4. Respect the send gate

- If the profile policy lists `draft`/`send` in `requireConfirm`, draft first and get an explicit go-ahead. The user saying "send an email to X saying Y" *is* that confirmation for that message; anything else is not.
- Never delete the gate from the stored config to make the send succeed — that is a standing change to the user's autonomy policy. Leave the config as found and say so in the report.
- Never send to an address the user has not seen when the recipient was ambiguous.

### 5. Send, then verify

Read back the newest `sentitems` entry (subject + recipients + timestamp + `bodyPreview`, so you confirm the text that actually went out) and only then report success. Convert UTC timestamps to the profile's timezone before quoting them. If the send call and the sent-items read disagree, report the read.

After a draft is submitted its ID stops resolving in `/me/messages`, so a 404 from `get-message.mjs` immediately after a send is expected, not a failed send — read `sentitems` instead.

### 6. Report

Short: who it went to (name + address), subject, when, one line of what it said. Mention any deviation the user should know (gate bypassed via a confirmed one-off, recipient chosen after asking, delivery unverified), and omit the process narration.

## Pitfalls

- **Requesting scopes the profile never consented to** turns a working token into `AADSTS65001: consent_required`, because MSAL refreshes carrying the extra scope. `requestedScopes` is a hard ceiling: re-issue the call with consented scopes (`Mail.Read` to read, `Mail.ReadWrite` to draft, `Mail.Send` to send) instead of re-authenticating.
- **Subject-only search hides names.** The Graph `search.mjs` helper filters on subject, so a recipient who appears only in To/Cc looks absent. Page and aggregate instead.
- **A name found in a thread is context, not consent.** The person who appears most often in the user's mail is not automatically the intended "Alex".
- **Silently loosening a confirmation gate** (editing the policy file, or reimplementing the send path without mentioning it) is worse than asking once. Do it transparently or not at all.
- **Declaring success from the send call's exit status.** Delivery is confirmed by the sent-items read, not by `OK: sent`.
- **Helper scripts must live in the backend skill's `scripts/`** for relative imports of `./_graph.mjs`, `./_lib.mjs`, `./_policy.mjs` to resolve; write them there and delete them when done.
- **Prefer direct sends over drafts only when the user asked for a send**; "write to X" without a send verb still means draft-and-confirm under a gated profile.

## Verification

- [ ] Backend and sending address identified from real config, not assumed.
- [ ] Recipient address confirmed, with the disambiguation shown when the name was ambiguous.
- [ ] Message is in the user's language, short, and free of invented commitments.
- [ ] Send happened inside the profile's policy, or the deviation is disclosed.
- [ ] Sent-items read-back quoted in the response (recipient, subject, sent body, local time).
- [ ] Wording you could not ground was taken verbatim from the request or asked for, never paraphrased.
