# Google Postmaster Tools & Microsoft SNDS Enrollment Guide

This guide covers enrolling your Mailu IP and sending domain into Google Postmaster Tools and Microsoft SNDS. This is essential for monitoring your "Sender Reputation" and ensuring high-volume emails consistently reach the inbox instead of the spam folder.

## Prerequisites for Mailu

Before starting, ensure your Mailu server has the following aliases active. Both Google and Microsoft will send verification emails to these addresses to confirm ownership:

1. **postmaster@yourdomain.com**
2. **abuse@yourdomain.com**

You can verify and create these in your Mailu Admin UI under **Mailboxes > Aliases**.

---

## 1. Google Postmaster Tools

Google uses Postmaster Tools to show you your IP/Domain reputation, spam complaint rate, and encryption (TLS) success over time.

### Enrollment Steps:

1. **Access:** Go to [postmaster.google.com](https://postmaster.google.com/).
2. **Add Domain:** Click the **"+"** button at the bottom right of the screen.
3. **Enter Domain:** Enter your primary sending domain (e.g., `ravact.com`).
4. **DNS Verification:** 
    * Google will provide a **TXT record** (usually starting with `google-site-verification=...`).
    * Add this record to your DNS provider (e.g., Cloudflare, Route53, Namecheap).
5. **Verify:** Once the DNS record has propagated, go back to the Google dashboard and click **Verify**.
6. **Sharing Access:** If you need to share the dashboard internally or with clients, use the "Manage Users" option in the domain settings.

> **Note:** Data usually takes 48–72 hours to start appearing after you begin sending a significant volume of emails (a few thousand) to Gmail users.

---

## 2. Microsoft SNDS (Smart Network Data Services)

Microsoft SNDS monitors IP-level reputation for all `@outlook.com`, `@hotmail.com`, and `@live.com` addresses.

### Step 1: JMRP (Junk Mail Reporting Program)

1. Go to the [Microsoft SNDS/JMRP Portal](https://postmaster.live.com/snds/JMRP.aspx).
2. Sign in with a Microsoft account.
3. Click on **"Add new Feed"**.
4. Enter your **Mailu Server IP address**.
5. **Recipient Email:** Set this to `abuse@yourdomain.com`. 
    * *Result:* When a user clicks "Report Spam" in Outlook, Microsoft will forward a copy of that email (in ARF format) to your Mailu server so you can automatically or manually unsubscribe them.

### Step 2: SNDS Enrollment

1. Go to [SNDS Request Access](https://postmaster.live.com/snds/AddNetwork.aspx).
2. Enter your **Mailu Server IP address** or IP range.
3. **Verification:** Microsoft will ask to send a verification email. Choose `postmaster@yourdomain.com` from the drop-down list.
4. Log in to your Mailu Webmail (Roundcube/SnappyMail), click the verification link in the Microsoft email, and confirm.

### Step 3: View the Data

1. Once verified, you can go to the [SNDS Dashboard](https://postmaster.live.com/snds/data.aspx) to view your daily sending volume and reputation.
2. It uses a "Traffic Light" system:
    * **Green:** Good reputation. Spam rate is low.
    * **Yellow:** Minor issues or some spam complaints. Deliverability might be impacted.
    * **Red:** Severe issues or blocklisted. Emails will likely go to junk or be rejected.

---

## High Volume Best Practices & Next Steps

Enrolling in these tools means you are no longer "flying blind." If your deliverability drops, these dashboards will show you whether Google or Microsoft is penalizing you due to high spam rates, broken authentication, or other IP issues.

**Automated Bounce Processor:** Once you receive a JMRP (spam complaint) email from Microsoft, you should set up a process (like a webhook mapper or mail parser) that reads that ARF report and automatically marks the user as "Unsubscribed" in your marketing tool (e.g., Listmonk or GoHighLevel). Continuing to send emails to someone who already marked you as spam will rapidly destroy your reputation.
