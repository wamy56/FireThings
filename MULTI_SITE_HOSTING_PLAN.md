# Multi-Site Firebase Hosting Architecture Plan

## Overview

This document outlines the plan to expand FireThings from a single dispatch portal to a multi-site architecture supporting:

| Site | Purpose | Subdomain | Tech Stack |
|------|---------|-----------|------------|
| Marketing | Public landing page, feature showcase, app downloads | www.firethings.co.uk | Static HTML/CSS or Next.js |
| Dispatch Portal | Dispatcher dashboard (existing) | app.firethings.co.uk | Flutter Web |
| Customer Portal | Future customer-facing features | customers.firethings.co.uk | TBD |

## Current State

- Single Flutter web app deployed to Firebase Hosting
- All requests rewrite to `index.html` (SPA pattern)
- Domain root shows login screen immediately
- No public-facing content

## Architecture

```
Firebase Project: firethings-51e00
│
├── Site: firethings-marketing (NEW)
│   ├── Domain: www.firethings.co.uk
│   ├── Purpose: Public marketing site
│   └── Source: /marketing-site/public/
│
├── Site: firethings-app (EXISTING - rename from default)
│   ├── Domain: app.firethings.co.uk
│   ├── Purpose: Dispatch portal
│   └── Source: build/web/
│
└── Site: firethings-customers (FUTURE)
    ├── Domain: customers.firethings.co.uk
    ├── Purpose: Customer portal
    └── Source: TBD
```

---

## Phase 1: Firebase Multi-Site Setup

### Step 1.1: Create Additional Hosting Sites

In Firebase Console:

1. Go to **Hosting** in the left sidebar
2. Click **Add another site**
3. Create site with ID: `firethings-marketing`
4. (Optional) Rename default site to `firethings-app` for clarity

Or via Firebase CLI:

```bash
firebase hosting:sites:create firethings-marketing
```

### Step 1.2: Update `.firebaserc`

Add the new site targets:

```json
{
  "projects": {
    "default": "firethings-51e00"
  },
  "targets": {
    "firethings-51e00": {
      "hosting": {
        "app": ["firethings-51e00"],
        "marketing": ["firethings-marketing"]
      }
    }
  }
}
```

### Step 1.3: Update `firebase.json`

Configure both sites with separate settings:

```json
{
  "hosting": [
    {
      "target": "app",
      "public": "build/web",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"],
      "rewrites": [
        {
          "source": "**",
          "destination": "/index.html"
        }
      ]
    },
    {
      "target": "marketing",
      "public": "marketing-site/public",
      "ignore": ["firebase.json", "**/.*", "**/node_modules/**"]
    }
  ],
  "firestore": {
    "rules": "firestore.rules",
    "indexes": "firestore.indexes.json"
  },
  "functions": {
    "source": "functions",
    "predeploy": ["npm --prefix functions run lint"]
  }
}
```

---

## Phase 2: Marketing Site Setup

### Step 2.1: Create Marketing Site Directory

```
test_app/
├── marketing-site/
│   ├── public/
│   │   ├── index.html
│   │   ├── css/
│   │   │   └── styles.css
│   │   ├── js/
│   │   │   └── main.js
│   │   ├── images/
│   │   │   ├── logo.png
│   │   │   ├── screenshots/
│   │   │   └── icons/
│   │   ├── about.html
│   │   ├── features.html
│   │   ├── pricing.html (if applicable)
│   │   └── contact.html
│   └── README.md
```

### Step 2.2: Marketing Site Content

Suggested pages:

| Page | Purpose |
|------|---------|
| Home (index.html) | Hero section, key features, CTA buttons |
| Features | Detailed feature breakdown with screenshots |
| About | Company/product story |
| Contact | Contact form, support email |
| Privacy Policy | Required for app stores |
| Terms of Service | Legal requirements |

### Step 2.3: Key Elements for Landing Page

```html
<!-- Example structure for index.html -->
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="FireThings - Professional fire alarm management for engineers">
    <title>FireThings - Fire Alarm Management App</title>
    <link rel="stylesheet" href="css/styles.css">
</head>
<body>
    <header>
        <nav>
            <a href="/" class="logo">FireThings</a>
            <ul>
                <li><a href="/features.html">Features</a></li>
                <li><a href="/about.html">About</a></li>
                <li><a href="/contact.html">Contact</a></li>
                <li><a href="https://app.firethings.co.uk" class="btn-primary">Dispatch Portal</a></li>
            </ul>
        </nav>
    </header>
    
    <main>
        <section class="hero">
            <h1>Fire Alarm Management Made Simple</h1>
            <p>Professional jobsheets, invoicing, and dispatch for fire alarm engineers</p>
            <div class="cta-buttons">
                <a href="#" class="btn-primary">Download on App Store</a>
                <a href="#" class="btn-secondary">Get on Google Play</a>
                <a href="https://app.firethings.co.uk" class="btn-outline">Dispatch Portal</a>
            </div>
        </section>
        
        <section class="features">
            <!-- Feature cards -->
        </section>
    </main>
    
    <footer>
        <a href="/privacy.html">Privacy Policy</a>
        <a href="/terms.html">Terms of Service</a>
    </footer>
</body>
</html>
```

---

## Phase 3: Domain Configuration

### Step 3.1: DNS Setup

Configure your domain DNS with these records:

| Type | Name | Value | Purpose |
|------|------|-------|---------|
| A | @ | Firebase IP | Root domain |
| CNAME | www | firethings-marketing.web.app | Marketing site |
| CNAME | app | firethings-51e00.web.app | Dispatch portal |
| CNAME | customers | firethings-customers.web.app | Future customer portal |

### Step 3.2: Connect Custom Domains in Firebase

For each site:

1. Go to Firebase Console > Hosting
2. Select the site
3. Click **Add custom domain**
4. Enter the subdomain (e.g., `app.firethings.co.uk`)
5. Follow verification steps
6. Wait for SSL provisioning (usually < 24 hours)

### Step 3.3: Redirect Root to WWW (Optional)

If you want `firethings.co.uk` to redirect to `www.firethings.co.uk`:

```json
// In firebase.json under marketing target
{
  "target": "marketing",
  "public": "marketing-site/public",
  "redirects": [
    {
      "source": "/",
      "destination": "https://www.firethings.co.uk",
      "type": 301
    }
  ]
}
```

---

## Phase 4: Deployment Workflow

### Step 4.1: Deploy Commands

```bash
# Deploy only the dispatch portal (Flutter app)
flutter build web --release
firebase deploy --only hosting:app

# Deploy only the marketing site
firebase deploy --only hosting:marketing

# Deploy both
firebase deploy --only hosting

# Deploy everything (hosting + functions + rules)
firebase deploy
```

### Step 4.2: CI/CD Integration (Codemagic)

Add to your Codemagic workflow:

```yaml
# For Flutter app deployment
scripts:
  - name: Build web
    script: flutter build web --release
  - name: Deploy to Firebase
    script: |
      firebase use firethings-51e00
      firebase deploy --only hosting:app --token "$FIREBASE_TOKEN"
```

For marketing site, consider a separate workflow or manual deployment.

### Step 4.3: Preview Channels (Optional)

Use Firebase preview channels for testing before production:

```bash
# Create a preview of marketing site changes
firebase hosting:channel:deploy preview-marketing --only marketing

# Creates URL like: firethings-marketing--preview-marketing-abc123.web.app
```

---

## Phase 5: Future Customer Portal

When ready to add a customer portal:

### Step 5.1: Create the Site

```bash
firebase hosting:sites:create firethings-customers
```

### Step 5.2: Update Configuration

Add to `.firebaserc`:
```json
"customers": ["firethings-customers"]
```

Add to `firebase.json`:
```json
{
  "target": "customers",
  "public": "customer-portal/build/web",
  "rewrites": [{ "source": "**", "destination": "/index.html" }]
}
```

### Step 5.3: Potential Customer Portal Features

- View service history for their sites
- Download compliance reports/certificates
- Request service visits
- View upcoming scheduled maintenance
- Pay invoices online
- Access documentation

---

## Implementation Checklist

### Firebase Setup
- [ ] Create `firethings-marketing` hosting site in Firebase Console
- [ ] Update `.firebaserc` with site targets
- [ ] Update `firebase.json` with multi-site configuration
- [ ] Test deployment to both sites

### Marketing Site
- [ ] Create `marketing-site/public/` directory structure
- [ ] Build landing page (index.html)
- [ ] Add features page
- [ ] Add privacy policy (required for app stores)
- [ ] Add terms of service
- [ ] Add contact page
- [ ] Optimize images and assets
- [ ] Test responsive design

### Domain Configuration
- [ ] Configure DNS records for subdomains
- [ ] Connect `www.firethings.co.uk` to marketing site
- [ ] Connect `app.firethings.co.uk` to dispatch portal
- [ ] Verify SSL certificates are active
- [ ] Test all URLs

### Go Live
- [ ] Deploy marketing site to production
- [ ] Update any hardcoded URLs in Flutter app
- [ ] Update app store listings with new website URL
- [ ] Set up analytics for marketing site (optional)

---

## Cost Considerations

Firebase Hosting is included in the free Spark plan with generous limits:
- 10 GB storage
- 360 MB/day data transfer
- Multiple sites supported

For most use cases, this should be sufficient. The Blaze plan (pay-as-you-go) is only needed if you exceed these limits.

---

## Alternative: Static Site Generators

If you want more features for the marketing site, consider:

| Tool | Pros | Cons |
|------|------|------|
| Plain HTML/CSS | Simple, no build step | Manual updates |
| Next.js | SEO, React components, ISR | Requires Node.js, more complex |
| Hugo | Fast, Markdown content | Learning curve |
| Astro | Modern, fast, component islands | Newer ecosystem |

For a simple marketing site, plain HTML/CSS is recommended to start. You can always migrate later.

---

## Questions to Consider

1. **Domain**: What domain will you use? (firethings.co.uk, firethingsapp.com, etc.)
2. **Branding**: Do you have logo assets, colour palette, and brand guidelines ready?
3. **Content**: Who will write the marketing copy?
4. **App Store Links**: Are the apps published yet, or will those be placeholder links?
5. **Analytics**: Do you want Google Analytics on the marketing site?
6. **Contact Form**: Email-based or integrate with a service like Formspree?

---

## Summary

This architecture cleanly separates concerns:
- **Marketing site**: Public, SEO-friendly, easy to update
- **Dispatch portal**: Authenticated, feature-rich Flutter app
- **Customer portal**: Future expansion path

The setup requires minimal changes to your existing dispatch portal code and uses Firebase's built-in multi-site hosting capability.
