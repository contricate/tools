# Recipe Box (iPhone app)

A native SwiftUI recipe keeper for iPhone (iOS 17+). Everything is stored on-device.

## Features
- Add, edit and delete recipes: photo, description, category, servings, prep/cook time, ingredients, steps, notes, source link
- Paste a whole ingredient list at once
- Search by name or ingredient, filter by category or favorites, sort by newest / A–Z / rating / quickest / most cooked
- Favorites, 5-star ratings, and "I Made This!" cook tracking
- Cooking mode: tap ingredients and steps to check them off, keep the screen on
- Shopping list: add a recipe's ingredients with one tap, check items off, share the list
- Share recipes as text; sample recipes to get started

## Getting the .ipa
The IPA is built by GitHub Actions on a Mac runner (`.github/workflows/build-recipebox-ipa.yml`).
Open the repo's **Actions** tab → **Build RecipeBox IPA** → latest run → download the **RecipeBox-ipa** artifact (a zip containing `RecipeBox.ipa`).

## Installing on your iPhone
The IPA is **unsigned**, so Apple requires it to be signed with your Apple ID when installing. Use a sideloading tool such as:
- **Sideloadly** (Windows/Mac) or **AltStore** — sign in with your Apple ID and drop in `RecipeBox.ipa`.
- On the iPhone: Settings → General → VPN & Device Management → trust your Apple ID, and enable Developer Mode if prompted.

With a free Apple ID the app must be re-signed every 7 days (AltStore can do this automatically).

## Building locally (Mac)
```sh
brew install xcodegen
cd RecipeBox && xcodegen generate && open RecipeBox.xcodeproj
```
Then pick your iPhone as the run destination and press Run.
