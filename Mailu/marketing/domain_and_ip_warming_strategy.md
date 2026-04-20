# High-Volume Email Architecture & IP Warming Strategy

When scaling an email infrastructure to 10K+ or 50K+ subscribers, treating your Mailu instance like a standard corporate email server will quickly lead to blocklists and delivery failures. A production-ready "Email Engine" requires strategic architectural separation and a strict, methodical warm-up period.

This guide covers two critical pillars of a GoHighLevel-grade self-hosted infrastructure: Transactional vs. Marketing Separation, and IP/Domain Warming.

---

## 1. Architectural Separation: Transactional vs. Marketing Streams

To protect your core business operations (password resets, invoices, direct client communication), you **must never** send marketing blasts from the same IP/Domain combination as your transactional emails.

### The Two-Stream Setup

1. **Transactional Stream (The VIP Lane)**
    * **Domain:** `app.yourdomain.com` or `billing.yourdomain.com`
    * **Purpose:** System notifications, 1-to-1 client emails, password resets, purchase receipts.
    * **Volume:** Low, consistent, and highly engaged (users almost always open these).
    * **Reputation:** Pristine. Because engagement is near 100%, inbox deliverability remains perfect.

2. **Marketing Stream (The Blast Lane)**
    * **Domain:** `mg.yourdomain.com` or `news.yourdomain.com` (Used by Listmonk)
    * **Purpose:** Newsletters, cold outreach, promotional blasts (e.g., your 10K subscriber import).
    * **Volume:** Spiky, high-volume, and varied engagement.
    * **Reputation:** Variable. This stream absorbs the brunt of spam complaints and bounces, keeping the "VIP Lane" insulated.

### Implementation in Mailu + Listmonk
* Set up two separate domain records in Mailu (`app` and `mg`).
* Ensure both have distinct DKIM, SPF, and DMARC records (`v=DMARC1; p=quarantine;`).
* Configure Listmonk to only send using the `mg.yourdomain.com` SMTP credentials.
* *Advanced Scaling:* In Mailu (`postfix` transport maps), you can eventually route outgoing traffic from `mg.yourdomain.com` through a secondary external IP or relay (like Amazon SES) while keeping transactional mail entirely on your dedicated VPS IP.

---

## 2. IP and Domain Warming Strategy

If you import 10,000 subscribers today and blast them simultaneously from a brand new server IP, Gmail, Yahoo, and Microsoft will automatically flag it as a spam attack and shadowban you.

"Warming" is the process of gradually proving to inbox providers that your traffic is legitimate over a period of 2 to 4 weeks.

### The Golden Rules of Warming
1. **Start small, scale exponentially.** You must begin with heavily constrained daily limits and double them incrementally.
2. **Prioritize top engagers.** When migrating a list, segment your most active subscribers (those who have opened or clicked an email in the last 30 days) and send to them *first*. This proves to Gmail that people actually want what you are sending.

### The 10K List Migration Schedule (Example)

Instead of blasting the full 10K list at once, use Listmonk's campaign throttling tools to portion the sends over 14 days.

* **Day 1:** 50 emails (Manual tests, team members, highly engaged friends).
* **Day 2:** 100 emails
* **Day 3:** 200 emails
* **Day 4:** 400 emails
* **Day 5:** 800 emails (Start migrating your recent engagers).
* **Day 6:** 1,200 emails
* **Day 7:** 1,500 emails
* **Day 8:** 2,000 emails
* **Day 9:** 3,000 emails
* **Day 10:** 5,000 emails
* **Day 14+:** 10,000+ emails (Full list capacity reached).

### Listmonk Configuration for Warming

To automatically enforce this without manually segmenting your list every day, you can use Listmonk's SMTP limits:

1. Edit your SMTP connection in Listmonk.
2. Under **Max connections**, set this to `1` or `2` during the first week.
3. Under **Max Send Rate**, set a strict limit (e.g., `1 / second` or `60 / minute`) to trickle the emails out slowly rather than overwhelming the receiving MTA. 

### What to Monitor During the Warmup (SOP)
* **Check Google Postmaster Tools daily.** Ensure the encryption and domain reputation are turning "Green" (High/Medium).
* **Monitor the Bounce Mailbox.** If your bounce rate exceeds 2-3% on any given day, stop sending immediately and clean your list before resuming.
* **Watch for Deferred Queues.** If Mailu's postfix queue starts growing with `4xx` Temporary Failures from Gmail/Hotmail, it means they are rate-limiting you. *Wait* for the queue to clear before sending more.

By strictly adhering to architectural separation and a mathematical warming schedule, your self-hosted infrastructure will achieve inbox placement parity with any enterprise SaaS platform.
