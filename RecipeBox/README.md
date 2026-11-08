# Recipe Box (iPhone & iPad app)

A native SwiftUI + SwiftData cookbook for iOS 17+. Recipes are stored on-device. Optional AI features use Claude with **your own** API key (stored in the iOS Keychain).

## Getting the .ipa
GitHub Actions builds it on a Mac (`.github/workflows/build-recipebox-ipa.yml`), runs the unit tests in the iOS Simulator, and takes screenshots.
Repo → **Actions** → **Build RecipeBox IPA** → latest run → **Artifacts → RecipeBox-ipa**.

Install with **Sideloadly** or **AltStore** (the IPA is unsigned; free Apple IDs must re-sign every 7 days).
Updating over an older version keeps your data (same bundle id `com.recipebox.app`); the database migrates automatically. Back up first via Settings → Data if you want to be safe.

## AI setup (optional)
1. Create an API key at console.anthropic.com → API Keys (usage is billed to your Anthropic account).
2. In the app: **Settings → AI Assistant → paste key → Save Key → Test Connection**.
3. Choose a model (default Claude Opus 5.5; Sonnet 5.5 / Haiku 5.5 are cheaper).

The key never appears in source code; it's saved in the Keychain and sent only to `api.anthropic.com`.
Requests opt into Anthropic's server-side refusal fallback (`fallbacks: "default"`) on Opus/Sonnet.
Without a key the app still works fully; AI-only features (assistant, create, AI extraction, web search, dish identification) explain that a key is needed.

## Feature status

| Area | Status | Notes |
|---|---|---|
| Dashboard (Home) | ✅ | Greeting, search, quick actions, continue cooking, today's plan, recently viewed / favourites / imported, "worth making again", grocery summary, shortcuts |
| Settings | ✅ | Theme, accent colour, grid/list, compact, default servings, measurement system, default sort, custom categories, cooking-mode prefs, timer alerts, import prefs, AI key/model/test, backup/restore/PDF, clear history. All persisted (UserDefaults / Keychain) |
| Universal importer | ✅ | See below |
| Recipe preview Accept / Edit / Reject | ✅ | Nothing saved until Accept; per-field confirmed / estimated / not-found markers; choose cover image |
| No-recipe fallback | ✅ | Explanation, partial info, add screenshots / video file / text, TheMealDB similar recipes, AI web search (verified URLs only), dish identification from photo, browser search, manual entry. Alternatives are always labelled as a different source |
| Import history | ✅ | Platform, date, status, accepted/rejected, errors, retry, open saved recipe; duplicate-link detection |
| Collections, tags, custom categories | ✅ | |
| Search & sort & filter | ✅ | Name, ingredient, category, cuisine, tag; recent-search suggestions; 7 sort orders |
| Ratings, personal notes & modifications, own photos, times made | ✅ | |
| Serving calculator & conversions | ✅ | Any serving count, ×½/×2/×3; metric/imperial; °F↔°C in steps; converter tool (weight, volume, temperature, cups↔grams, gas mark) |
| Cooking mode | ✅ | One step at a time, large adjustable text, progress, step ingredients, checklist, multiple timers (keep running app-wide, notifications), saved/resumable progress, exit confirmation |
| Grocery list | ✅ | Select ingredients, safe combining (200 g + 300 g = 500 g; never mixes grams with "2 breasts"), aisles incl. Household, edit qty/aisle, custom items, clear completed, undo, share |
| Meal planner | ✅ | Week view, 4 meal slots, drag & drop from tray and between slots, replace/copy/move/remove, daily & weekly times, saved plans (templates), week → groceries |
| Nutrition | ✅ (estimate) | Built-in table of ~90 common foods (USDA averages). Per serving / whole recipe. Shows numbers only if ≥70% of ingredients have measurable amounts; lists what's excluded |
| Discover | ✅ | Real recipes from TheMealDB (random picks, categories, cuisines, main-ingredient filter, search). Time/difficulty/diet/calorie filters are offered only through clearly labelled AI suggestions, because TheMealDB has no such data |
| What's in My Kitchen? | ✅ | Ready / almost (1–2 missing) / more; missing items → groceries; TheMealDB ideas |
| Cooking assistant | ✅ (needs key) | Streaming chat, recipe-aware, food-safety guidance from USDA/FSIS values, save answers to notes. Tab + button on every recipe |
| Create with AI | ✅ (needs key) | Prompt + servings → preview → edit/save; labelled AI-generated everywhere |
| Sharing & export | ✅ | Text, copy, PDF (cookbook-style pages), print, Recipe Box file, whole-cookbook PDF/JSON; import Recipe Box or schema.org JSON files |
| Quality of life | ✅ | Confirmations for destructive actions, undo (recipes, groceries, plan), empty states, skeleton loaders, toasts, autosaved edit drafts, keyboard shortcuts (iPad), accessibility labels, iPad layouts |

### Video importer — what it really reads

| Platform | Public data used | Limitations |
|---|---|---|
| YouTube / Shorts | oEmbed title & creator, page description, public caption track (when YouTube serves it), thumbnail + 3 auto-generated stills | Some caption tracks can't be downloaded without YouTube's own player; the app then says so |
| TikTok | Official oEmbed API: full caption, creator, cover image | No public transcript API — spoken-only recipes need the video file, screenshots or pasted text |
| Instagram / Facebook / X | Public page preview (Open Graph) caption + image | Often blocked by login walls; the app explains and offers the alternatives |
| Pinterest | Pin preview + linked recipe page | |
| Reddit | Public post JSON incl. the original poster's comments | |
| Vimeo | Official oEmbed incl. description | |
| Recipe websites | schema.org Recipe data | Most major sites supported |

In all cases the app also: follows recipe links found in the description (often the creator's own blog), runs on-device OCR (Apple Vision) on thumbnails/frames/screenshots, and — if you pick the video file from Photos — samples frames for on-screen text and transcribes the audio on device (Apple Speech).
Then Claude combines all of it (or built-in text rules if AI is off) and marks every field as from-source / estimated / not found.

**Not done, deliberately:** downloading videos from platforms that don't offer it, or bypassing logins — that would break the platforms' terms. Using the video file you saved yourself is supported instead.

## Known limitations / remaining work
- Nutrition values are estimates from a built-in table, not a full food database (no brand data).
- TheMealDB has no servings or times; those fields show as "not found" until you edit them.
- iCloud sync between devices isn't implemented (backups via Files/iCloud Drive work).
- "Share via link" isn't possible without a server; recipes are shared as text, PDF or a Recipe Box file instead.
- The app hasn't been run on a physical device by the developer; CI verifies it compiles, runs unit tests in the simulator, and launches each main screen.

## Building locally (Mac)
```sh
brew install xcodegen
cd RecipeBox && xcodegen generate && open RecipeBox.xcodeproj
```

## Tests
`RecipeBoxTests` covers ingredient scaling/parsing, unit & temperature conversion, timer detection, grocery combining rules, platform detection & URL normalisation, caption parsing, social caption extraction, JSON-LD parsing, embedded-JSON extraction, AI-result mapping (missing amounts stay marked), and nutrition coverage rules.
