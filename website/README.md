# T2Do marketing site

Static landing page for T2Do (https://t2do.app). No build step, no dependencies.

- `index.html` — page markup
- `privacy/index.html` — privacy policy at `/privacy/`, linked from the website footer and the app's Settings → About
- `privacy.css` — responsive policy typography; the policy needs no JavaScript
- `styles.css` — design + all CSS motion (aurora, word reveal, phone tilt, marquee, orbit, scroll reveals)
- `script.js` — interactions (scroll reveals, pointer tilt, hero task loop, overdue demo, timeline scrubber)
- `assets/` — app icon, current flat Settings screenshot, and retained older screenshots (not displayed)
- `CNAME` — custom domain for GitHub Pages

## Preview locally

```sh
cd website && python3 -m http.server 8000
```

Append `?static` to the URL to freeze every animation at its end state (useful for screenshots and QA).

## Deploy

Any static host works: GitHub Pages (publish the `website/` folder), Netlify, Cloudflare Pages, or Vercel.
Point `t2do.app` at the host. The page currently states that the app is in testing. Once approved, replace the coming-soon messaging and contact CTA with the app's actual App Store listing.

The calendar section describes the device-calendar implementation: optional EventKit access, explicit calendar selection, no separate provider sign-in, and no event editing. The Settings image is from the updated iPhone Simulator build, not a physical-device App Review recording.

## Privacy policy release check

The policy reflects the device-calendar version, not the older Google OAuth TestFlight build. Operator and contact: Kadeem Jeffery, kadeem.jeffery@mail.lavalabs.ai. The operator confirmed Google Workspace for support email, Netlify hosting, no website analytics or visitor tracking, a US audience, and that the app is not directed to children under 13. No public business mailing address was supplied.

Approved retention: delete support correspondence 24 months after the last message; delete controlled copies of beta feedback 12 months after receipt or on related issue closure, whichever is later, subject to legal exceptions. These are operational commitments, not automated by this website change. Configure or maintain a deletion review process before publishing. Apple's independently controlled records follow Apple's retention rules.

Verify US-only availability in App Store Connect separately; policy wording does not change storefront settings. Privacy manifest declarations and App Privacy answers still require a separate release check.

Before submission, deploy the site, verify `https://t2do.app/privacy/` is publicly accessible without login, and enter that URL in App Store Connect's Privacy Policy URL field. Include the in-app Settings link in the submitted build. Review App Privacy answers separately; this page does not set those answers or establish legal compliance. Review the stated support/diagnostic retention practice and actual hosting/email provider practices before publishing, and keep the policy aligned with any future service changes.
