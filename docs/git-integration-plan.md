# Git integration plan — bringing iOS into `main`

This explains how to land the Ring Knot iOS work onto `main`. It is written for
the repo owner; nothing here is executed automatically and no PRs are merged or
closed by tooling.

## Current state

History is **fully linear** off `main`:

```
main (fe0991b)
  └─ a6aef05  Phase 1  core game
       └─ 698e205  Phase 2  generated assets + polish     (branch ios-phase-2-assets-polish)
            └─ 3d6d516  Phase 3  onboarding + ship-readiness (branch ios-phase-3-gameplay-readiness)
                 └─ 3ce06e6  Phase 4A rotatable rings         (branch ios-phase-4a-rotatable-rings)
                      └─ (4B)  rotation release candidate      (branch ios-phase-4b-rotation-rc)
```

`git merge-base main ios-phase-4a-rotatable-rings` is exactly `main`'s HEAD, so
each phase branch is a direct descendant of the last, with no divergence.

### Open PR stack

| PR | Head | Base |
| --- | --- | --- |
| #1 | `ios-phase-2-assets-polish` | `main` |
| #2 | `ios-phase-3-gameplay-readiness` | `ios-phase-2-assets-polish` |
| #3 | `ios-phase-4a-rotatable-rings` | `ios-phase-3-gameplay-readiness` |
| #4 (4B) | `ios-phase-4b-rotation-rc` | `main` |

The Phase 4B RC PR is opened against **`main`** (not stacked), because the RC
branch already contains the complete linear history of every phase. A single
merge of the RC PR therefore brings the **entire iOS app** onto `main`.

## Recommended merge strategy

**Option A — one clean PR to `main` (recommended).** Review and merge only the
Phase 4B RC PR (`ios-phase-4b-rotation-rc` → `main`). Because history is linear,
a standard merge (or a fast-forward) lands Phases 1–4A + 4B in order. Then close
PRs #1/#2/#3 as *superseded by the RC PR* (they contain the same commits). This is
the least error-prone path and makes `main` the real source of truth in one step.

- Prefer a **merge commit** (`--no-ff`) or **rebase/fast-forward**; avoid
  **squash**, which would collapse the four phase commits into one and lose the
  per-phase history. If you want exactly one commit on `main`, squash is fine, but
  the phase boundaries are useful and worth keeping.

**Option B — drain the stack in order.** Merge #1 → then #2 → then #3 → then the
RC PR. Equivalent result, but four times the review/merge surface and each merge
re-points the next PR's base. Only worth it if you want to review each phase as
its own PR.

## Exact commands (only if manual intervention is needed)

Fast-forward `main` to the RC branch locally (cleanest if `main` has no other
commits):

```bash
git fetch origin
git checkout main
git merge --ff-only origin/ios-phase-4b-rotation-rc
git push origin main
```

If you prefer a merge commit that records the integration:

```bash
git fetch origin
git checkout main
git merge --no-ff origin/ios-phase-4b-rotation-rc -m "Merge iOS Phases 1–4B"
git push origin main
```

Then close the superseded PRs (web UI, or):

```bash
gh pr close 1 --comment "Superseded by the Phase 4B RC PR which contains this history."
gh pr close 2 --comment "Superseded by the Phase 4B RC PR which contains this history."
gh pr close 3 --comment "Superseded by the Phase 4B RC PR which contains this history."
```

Do **not** force-push the `ios-phase-1/2/3/4a` branches — leave them as the
historical record. They can be deleted after `main` is updated if desired.

## After integration

- `main` becomes the source of truth; future work branches from it.
- The shared level pack and tools are unchanged by the merge.
- Re-run `bash tools/ci_local.sh` on `main` once to confirm the integrated tree is
  green before tagging a build.
