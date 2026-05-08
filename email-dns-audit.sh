#!/bin/bash

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
  echo "❌ Usage: bash email-dns-audit.sh yourdomain.com"
  exit 1
fi

echo "======================================="
echo " DNS EMAIL AUDIT: $DOMAIN"
echo "======================================="
echo ""

RISK=0

########################################
# SPF CHECK
########################################
echo "🔎 SPF CHECK"

SPF_RECORDS=$(dig +short TXT $DOMAIN | grep "v=spf1")

if [ -z "$SPF_RECORDS" ]; then
  echo "❌ No SPF record found"
  echo ""
  echo "🛠️ FIX:"
  echo "v=spf1 include:spf.protection.outlook.com include:amazonses.com ~all"
  RISK=$((RISK+30))
else
  echo "$SPF_RECORDS" | nl

  COUNT=$(echo "$SPF_RECORDS" | wc -l)

  if [ "$COUNT" -gt 1 ]; then
    echo ""
    echo "❌ CRITICAL: Multiple SPF records detected (INVALID)"
    echo "🛠️ FIX: Merge into ONE record:"
    echo "v=spf1 include:spf.protection.outlook.com include:amazonses.com ~all"
    RISK=$((RISK+40))
  else
    echo "✔ Single SPF record OK"
  fi

  INCLUDES=$(echo "$SPF_RECORDS" | grep -o "include:" | wc -l)

  echo ""
  echo "📊 SPF includes count: $INCLUDES"

  if [ "$INCLUDES" -gt 8 ]; then
    echo "⚠️ SPF may exceed DNS lookup limit (10 max)"
    echo "🛠️ FIX: Reduce includes or flatten SPF"
    RISK=$((RISK+10))
  fi
fi

echo ""
########################################
# DKIM CHECK
########################################
echo "🔎 DKIM CHECK"

DKIM_MS1=$(dig +short TXT selector1._domainkey.$DOMAIN)
DKIM_MS2=$(dig +short TXT selector2._domainkey.$DOMAIN)
DKIM_RESEND=$(dig +short TXT resend._domainkey.$DOMAIN)

if [[ -n "$DKIM_MS1" || -n "$DKIM_MS2" ]]; then
  echo "✔ Microsoft 365 DKIM detected"
else
  echo "⚠️ Microsoft 365 DKIM missing"
  echo "🛠️ FIX: Enable DKIM in Microsoft 365 admin center"
fi

if [[ -n "$DKIM_RESEND" ]]; then
  echo "✔ Resend DKIM detected"
else
  echo "⚠️ Resend DKIM missing"
  echo "🛠️ FIX: Add DKIM from Resend dashboard"
fi

echo ""
########################################
# DMARC CHECK
########################################
echo "🔎 DMARC CHECK"

DMARC=$(dig +short TXT _dmarc.$DOMAIN)

if [ -z "$DMARC" ]; then
  echo "❌ No DMARC record found"
  echo ""
  echo "🛠️ FIX (start safe):"
  echo "v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN"
  RISK=$((RISK+30))
else
  echo "$DMARC"

  if echo "$DMARC" | grep -q "p=none"; then
    echo ""
    echo "⚠️ DMARC is in monitoring mode (weak protection)"
    echo "🛠️ FIX PATH:"
    echo "Step 1: v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN"
    echo "Step 2: v=DMARC1; p=reject; rua=mailto:dmarc@$DOMAIN"
    RISK=$((RISK+20))
  fi

  if ! echo "$DMARC" | grep -q "rua="; then
    echo ""
    echo "⚠️ Missing DMARC reporting (rua)"
    echo "🛠️ FIX: Add rua=mailto:dmarc@$DOMAIN"
    RISK=$((RISK+10))
  fi
fi

echo ""
########################################
# RISK SCORE
########################################
echo "📊 DELIVERY RISK SCORE"

echo "Score: $RISK / 100"

if [ "$RISK" -lt 20 ]; then
  echo "🟢 Excellent deliverability (Gmail/Outlook trusted)"
elif [ "$RISK" -lt 50 ]; then
  echo "🟡 Medium risk (some spam filtering possible)"
else
  echo "🔴 High risk (likely spam/junk issues)"
fi

echo ""
echo "======================================="
echo " DONE"
echo "======================================="
