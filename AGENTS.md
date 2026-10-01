# Repository instructions

## Product and implementation

- Read `README.md`, `DEVELOPMENT.md`, `SOURCE_NOTES.md` and the relevant implementation before changing architecture.
- Preserve the generic, frame-agnostic resolver/property/enforcement model. Blizzard frames are integration cases, not a reason to add named-frame exceptions or reset maps.
- Keep mandatory native permission/access and secret-value checks intact, with explicit representation limits. Ordinary panel/shared-layout involvement and Edit Mode ancestry are scoped advisory evidence, not geometry vetoes. Exclude only a supported same-object/property Edit Mode control by explicit product policy; assess position and size separately. Unknown optional management metadata must not become a mandatory permission failure. Never add named-frame exceptions or invoke layout/reset methods to inspect ownership. Offline mocks are not proof of native WoW behavior; report what still needs client testing.
- Preserve saved-data compatibility and update documentation to describe the implementation actually delivered.

## Complete and publish work

The repository owner explicitly requests that completed changes be pushed to GitHub and merged into `main`. This is standing authorization for normal commits, branch pushes, pull requests and merges for the requested work. Do not stop at local edits or ask again for routine push/merge confirmation.

For each task that changes repository files, unless the user explicitly requests a different delivery state:

1. Inspect Git status and fetch the configured remote. Preserve unrelated or unfinished user changes.
2. Work on a descriptive `codex/` branch based on the current `main`, or continue the branch already associated with the task. Carry authorized uncommitted work into that branch safely.
3. Finish the implementation, relevant validation and documentation. For addon changes, run the commands below and package the build when applicable. Documentation-only changes need a diff/whitespace review, not an unnecessary full test rerun.
4. Review the diff and commit all files belonging to the completed task, including required new files/assets. Keep `.reference/`, `.tools/`, `dist/`, secrets and local client/account data out of Git. Packaging alone does not publish the source changes.
5. Push the task branch to GitHub. Create or update a pull request targeting `main`, describing the final behavior, validation and material native-testing limits. Attach the PR to the current Codex chat when that tool is available.
6. Check the PR and any required GitHub checks/reviews. Once mergeable and validation passes, merge it into `main` through the normal GitHub merge workflow. Do not treat a pushed branch or an open PR as completed delivery.
7. Synchronize local `main` with the merged remote branch using a safe fast-forward, and verify that the intended changes are present on `origin/main`. Report the merged PR and any remaining limitations.

Do not bypass branch protections, required reviews or failing checks. Do not force-push or discard unrelated work to complete this workflow. If authentication, permissions, checks, conflicts or an external requirement genuinely prevents completion, make safe progress and report the precise blocker and what remains unmerged. Read-only questions/reviews do not require a commit or merge.

## Validation commands

From the repository root in PowerShell, use the existing development environment:

```powershell
& .tools/venv/Scripts/python.exe scripts/check.py
& .tools/venv/Scripts/python.exe scripts/check_reference.py --zip 'D:/Games/World of Warcraft/_classic_beta_/BlizzardInterfaceCode.zip'
& .tools/venv/Scripts/python.exe scripts/package.py
& ./scripts/test-deploy.ps1
git diff --check
```

`package.py` reruns `check.py`; avoid redundant reruns once unchanged code has passed. Run the source audit when changing native/API assumptions, and deployment tests when changing packaging/deployment behavior. If the supplied source ZIP is unavailable, report the unexecuted audit; never substitute another client branch or claim native verification.

Publishing source to GitHub does not imply deployment to the user's game installation. Deploy to a real client only when requested with an explicit destination.
