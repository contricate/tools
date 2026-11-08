# Repository guide for Claude Code

Two independent iOS apps live here, each built into an IPA by GitHub Actions:

| App | Folder | Workflow | Notes |
|---|---|---|---|
| Recipe Box | `RecipeBox/` | `.github/workflows/build-recipebox-ipa.yml` | SwiftUI + SwiftData, iOS 17+ |
| Aura (customisation) | `Customizer/` | `.github/workflows/build-aura-ipa.yml` | App + WidgetKit extension + tests, iOS 18+ |

There's no Mac in the cloud sandbox: verify changes by pushing and reading the workflow results (build, unit tests, simulator launch checks).

## Model & effort routing

Claude Code can't switch the model of the conversation it's running in, but it can hand work to subagents that run on a different model and effort. Route work like this:

| Task | Agent | Model / effort |
|---|---|---|
| Architecture, iOS capability research, entitlements/signing, security, data-model changes | `architect` | Opus · high |
| Implementing features, refactors, fixing CI compile/test failures | `ios-implementer` | Sonnet · medium |
| Docs, guides, copy edits, renames, summarising logs | `quick-helper` | Haiku · low |

Use the main conversation for coordination; delegate a self-contained task to the matching agent when it is large enough to be worth the hand-off. To change the main session's model manually, use `/model`.

## Rules
- Don't remove working features when adding new ones; don't duplicate systems.
- No placeholder buttons or settings that do nothing.
- Be explicit about iOS limits — never imply an app can do what iOS forbids.
