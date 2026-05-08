# 📅 Mailu Calendar & Contacts Sync Guide

WebDAV (CalDAV for Calendars and CardDAV for Contacts) is enabled on your Mailu server. This allows you to sync your calendar and address book across multiple devices and webmail clients.

---

## 🚀 1. Accessing via Webmail

### **Roundcube**
*   **URL**: [https://mail.ravact.com/webmail/](https://mail.ravact.com/webmail/)
*   **Calendar**: Use the **Calendar** icon in the sidebar to manage your events.
*   **Contacts**: The "Address Book" automatically syncs with your CardDAV collection.

### **SnappyMail**
*   **URL**: [https://mail.ravact.com/snappymail/](https://mail.ravact.com/snappymail/)
*   SnappyMail has built-in support for remote address books and calendars.
*   Go to **Settings** -> **Contacts** or **Calendar** to add your Mailu Dav endpoints if they aren't auto-detected.

---

## 📧 2. Connecting Microsoft Outlook

Outlook **does not natively support** CalDAV/CardDAV for standard IMAP accounts. You must use a plugin.

### **Recommended Plugin**
We recommend the free and open-source **[Outlook CalDAV Synchronizer](https://caldavsynchronizer.org/)**.

### **Setup Steps:**
1.  **Install** the plugin and restart Outlook.
2.  Go to the new **CalDAV Synchronizer** tab in Outlook.
3.  Click **Synchronization Profiles** -> **Add New**.
4.  Select **Generic CalDAV/CardDAV**.
5.  **Settings**:
    *   **Name**: Mailu Calendar (or Contacts)
    *   **Outlook Folder**: Select your Outlook Calendar (or Contacts) folder.
    *   **DAV URL**: `https://mail.ravact.com/dav/`
    *   **Username**: `your-email@yourdomain.com`
    *   **Password**: Your email password (or [Authentication Token](https://mail.ravact.com/admin/token/list))
    *   **Email Address**: `your-email@yourdomain.com`
6.  Click **Test or discover settings** to automatically find your collections.

---

## 📱 3. Connecting Mobile Devices

### **iPhone / iOS (Native Support)**
1.  Go to **Settings** -> **Mail** -> **Accounts** -> **Add Account** -> **Other**.
2.  Select **Add CalDAV Account** (for Calendar) or **Add CardDAV Account** (for Contacts).
3.  **Server**: `mail.ravact.com`
4.  **User Name**: Your full email address.
5.  **Password**: Your email password.
6.  **URL (Advanced)**: `https://mail.ravact.com/dav/`

### **Android**
Android requires an app like **DAVx⁵** (available on Play Store or F-Droid) to sync CalDAV/CardDAV to the native calendar/contacts apps.

---

## 🛠️ Management
The Calendar and Contacts features are managed via the `./manage-mailu-features.sh` script on the server. Toggling "WebDAV / Calendar" will automatically:
1. Enable/Disable the Radicale backend container.
2. Enable/Disable the Roundcube UI plugins.
