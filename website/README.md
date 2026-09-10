# T2Do marketing site

Static landing page for T2Do (https://t2do.app). No build step, no dependencies.

- `index.html` — page markup
- `styles.css` — design + all CSS motion (aurora, word reveal, phone tilt, marquee, orbit, scroll reveals)
- `script.js` — interactions (scroll reveals, pointer tilt, hero task loop, overdue demo, timeline scrubber, light/dark compare)
- `assets/` — app icon and the two app screenshots
- `CNAME` — custom domain for GitHub Pages

## Preview locally

```sh
cd website && python3 -m http.server 8000
```

Append `?static` to the URL to freeze every animation at its end state (useful for screenshots and QA).

## Deploy

Any static host works: GitHub Pages (publish the `website/` folder), Netlify, Cloudflare Pages, or Vercel.
Point `t2do.app` at the host and update the App Store link (`#appStoreLink` in `index.html`) once the app is live.
