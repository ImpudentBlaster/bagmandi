# BagMandi Admin Panel

React + Vite + TypeScript admin console for the BagMandi Firebase project.

## Setup

1. Firebase Console → Project **bagmandi** → Add a **Web** app
2. Enable **Phone** authentication
3. Add authorized domain `localhost`
4. Copy web config into `.env` (see `.env.example`)
5. In Firestore `users/{uid}`, set `role: "admin"` for your phone-auth user

```bash
cd admin
npm install
npm run dev
```

## Features

- Phone OTP login (admin role only)
- Dashboard stats + PP rate update
- Users / Manufacturers verify & enable-disable
- Enquiries status management
- Dead Stock & Market (marketplace + PP rates)
- Products category overview
- Banners CRUD (`banners` collection)
- Settings

## Collections used

`users`, `enquiries`, `quotes`, `orders`, `marketplace`, `pp_rates`, `banners`
