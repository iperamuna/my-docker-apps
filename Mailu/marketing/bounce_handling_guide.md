# Automated Bounce and Complaint Handling (Mailu + Listmonk)

To achieve enterprise-grade, high-volume sending equivalent to SaaS platforms like GoHighLevel it is **critical** to automatically process bounces and spam complaints. Sending emails to inactive addresses or users who marked you as spam will quickly destroy your IP and domain reputation.

Because we are pairing **Mailu** with **Listmonk**, we do not need to build complex custom webhooks to parse Mailu's raw logs. Listmonk features a powerful built-in Bounce/Complaint Processor that connects directly to Mailu via IMAP to handle this natively.

Here is the setup to achieve a fully automated reputation guard loop.

---

## Step 1: Create a Dedicated "Bounces" Mailbox in Mailu

Instead of parsing raw server logs, we force all delivery failures and spam complaints to go to a single, dedicated inbox that Listmonk will monitor.

1. Go to your **Mailu Admin Panel**.
2. Navigate to **Mailboxes** and click **Add Mailbox**.
3. Create a new mailbox designated for bounces (e.g., `bounces@yourdomain.com`).
4. Generate a strong password and save it securely. You will need this for Listmonk.

---

## Step 2: Route Abuse Reports to the Bounce Mailbox

When someone clicks "Report Spam" in Outlook or Yahoo, those providers send an automatic "ARF" (Abuse Reporting Format) email back to the Sender. By default, these go to your `abuse@` alias. We want Listmonk to automatically read and process these complaints in the same way it processes dead email addresses.

1. In Mailu Admin, go to **Aliases**.
2. Edit (or create) the `abuse@yourdomain.com` alias.
3. Set the **Destination** to your dedicated bounce mailbox: `bounces@yourdomain.com`.
4. *(Optional)* Do the same for `postmaster@yourdomain.com` to catch all overarching system delivery errors in the same place.

---

## Step 3: Configure Listmonk to "Listen" (IMAP Polling)

Now we tell Listmonk to act as the "listener." It will log into `bounces@yourdomain.com` frequently, read any failure or spam complaint emails, automatically update the subscriber in the database, and then delete the email to keep the inbox clean.

1. Open your **Listmonk Admin Dashboard**.
2. Navigate to **Settings > Bounces**.
3. Configure the IMAP connection to your Mailu server:
   * **Host:** `mail.yourdomain.com` (Your Mailu IMAP hostname)
   * **Port:** `993`
   * **Protocol:** `IMAP`
   * **TLS:** Check "Enable TLS"
   * **Username:** `bounces@yourdomain.com`
   * **Password:** The password you generated in Step 1.
   * **Mailbox:** `INBOX`
4. **Scan interval:** Set this to `5m` (5 minutes). This dictates how often Listmonk checks Mailu for bounces.
5. Click **Save** and verify the connection.

---

## Step 4: Configure Listmonk Routing (Return-Path / VERP)

Finally, we need to enforce that Listmonk stamps every outgoing email with instructions that dictate: *"If this delivery fails, do not reply to the sender; send the NDR (Non-Delivery Report) to our bounce mailbox."*

1. Still in Listmonk, navigate to **Settings > SMTP**.
2. Edit your Mailu SMTP connection.
3. Under the **Bounce / Return-Path** setting, insert your bounce mailbox: `bounces@yourdomain.com`.
4. Save the SMTP connection settings.

---

## The Production Workflow (How it works behind the scenes)

Once configured, your system operates identical to top-tier enterprise setups:

1. **The Campaign Starts:** Listmonk dispatches 10,000 emails. It secretly injects a header into every email: `Return-Path: <bounces@yourdomain.com>`.
2. **A Hard Bounce Occurs:** 50 of those emails are dead addresses. The receiving MTAs (Message Transfer Agents like Gmail or Yahoo) immediately reject the connection and fire back a standard `550 User Not Found` email straight to `bounces@yourdomain.com` inside Mailu.
3. **A Spam Complaint Occurs:** 2 people click "Spam" inside their Outlook client. Microsoft's Sender Network (SNDS/JMRP) fires back an ARF complaint to `abuse@yourdomain.com`. Mailu instantly routes this to `bounces@yourdomain.com`.
4. **The Auto-Purge:** Within 5 minutes, Listmonk logs into `bounces@yourdomain.com` via IMAP. It reads the 52 total emails, matches the ARF and bounce patterns using its internal regex library, identifies the specific subscribers via their hidden Listmonk UUIDs, changes their status from `Enabled` to `Bounced` or `Blacklisted`, and finally deletes the processed emails. 

Your reputation remains safe without manual intervention.
