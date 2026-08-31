# Portable update smoke test

Use this manual two-version test before publishing changes to the updater or release process. It exercises the same
Velopack packages as production while serving the feed only from the local machine.

## Prepare two local versions

1. Work on a disposable branch or copy of the repository. Temporarily replace the `GithubSource` constructed in
   `VelopackLauncherApplicationUpdateService` with
   `new SimpleWebSource("http://127.0.0.1:8123")`. Do not commit this test-only edit.
2. Set `VersionPrefix` in `GenLauncherGO.UI/GenLauncherGO.UI.csproj` to a lower numeric test version such as
   `1.1.101`, then run `./eng/package-release.ps1 -Bootstrap`.
3. Copy everything in `artifacts/release` to a temporary `version-a` directory and extract its
   `GenLauncherGO-win-Portable.zip` to a separate `installed` directory.
4. Set `VersionPrefix` to a higher version such as `1.1.102` and run
   `./eng/package-release.ps1 -Bootstrap` again. Leave this higher-version feed in `artifacts/release`.
5. Start a local static HTTP server whose document root is `artifacts/release`. For example, if Python is available:

   ```powershell
   python -m http.server 8123 --directory ./artifacts/release
   ```

## Apply the update

1. In `installed`, create `GenLauncherGO Data\update-smoke-sentinel.txt` and put recognizable text in it.
2. Run the root `installed\GenLauncherGO.exe`. Complete normal launcher startup if that test copy has no preferences.
3. Wait for the update-ready dialog, choose **Restart now**, and allow the old process to exit.
4. Confirm GenLauncherGO restarts and `installed\current\sq.version` identifies the higher test version.
5. Confirm `GenLauncherGO Data\update-smoke-sentinel.txt` still exists with unchanged contents.
6. Close the launcher, stop the HTTP server, revert the temporary source and `VersionPrefix` edits, and remove the
   disposable test directories.

Also repeat step 3 once with active package work: the dialog must not appear until that work is idle. On another run,
choose **Later** and confirm it is not shown again during that launcher session.
