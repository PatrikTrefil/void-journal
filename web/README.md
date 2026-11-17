# Void Journal for the web

A dependency-free browser version of Void Journal. Run `npm run dev` from this directory and open http://127.0.0.1:4173. Any static host can serve `dist/` directly. Run `npm test` for engine checks.

On Vercel, connect the GitHub repository and set the project Root Directory to `web`. The tracked `vercel.json` selects static hosting from `dist/`, skips dependency installation, and runs the engine tests before deployment. Use Node.js 22. Production follows `main`; other branches and pull requests receive preview deployments.

Includes Dissolve and Void, System/Light/Dark appearance, four text sizes, a demonstrative introduction, full screen, IME and paste input, forward-only writing, and typing-sensitive release pacing. Ctrl/Command+Enter releases everything; Ctrl/Command plus, minus, and zero change text size. Escape skips the introduction. Reduced motion and high contrast are respected.

Controls are hidden by default. The quiet three-dot button in the upper right reveals the header and footer. Use it again, press Escape, or return to writing to hide them. Keyboard shortcuts work while controls are hidden.

Writing lives only in JavaScript memory and the transient input buffer. It is never sent to a server or stored. Leaving/reloading clears it. Only the explicit preference fields are stored in localStorage. Browser extensions, keyboards, and browser writing services remain outside the app’s control. There are no external assets, analytics, accounts, or application network requests.

The canvas uses platform font rendering; it does not provide the native apps’ exact glyph-outline particle breakup. Dissolve emits drifting particles as letters fade. Native mobile input and composition are captured by a textarea; the visual journal is a canvas, so full screen-reader access to the changing text is limited.
