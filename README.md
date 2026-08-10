# SonarQube + GitHub Actions with skip tracking

A production-usable code-quality pipeline:

1. **In the IDE** — SonarQube for IDE (VS Code) flags issues as you type.
2. **On push / PR** — GitHub Actions runs a SonarQube scan and a Quality Gate.
3. **Skips are allowed but tracked** — a developer can bypass the scan for an
   urgent push with `[skip sonar]` in the commit message, but after **5 skips**
   the admin and the developer are **emailed**, and further skips are **refused**
   (the scan is forced) until a scan passes and resets their counter.

## How the skip policy behaves (threshold = 5)

| Skip # (`[skip sonar]`) | Scan runs? | Email sent? | Notes                         |
|-------------------------|------------|-------------|-------------------------------|
| 1–4                     | No         | No          | Silent skip                   |
| 5                       | No         | **Yes**     | Last free skip + warning mail |
| 6+                      | **Yes (forced)** | **Yes** | Skip flag ignored, scan runs  |
| Any push **without** the flag | Yes  | No          | A passing scan **resets** the user's counter to 0 |

Counters are **per developer** and stored in a repository variable
(`SONAR_SKIP_TRACKER`) as JSON, e.g. `{"alice":3,"bob":0}`.

```mermaid
flowchart TD
    A[Push / PR] --> B{Commit has<br/>[skip sonar]?}
    B -- No --> S[Run SonarQube scan + Quality Gate]
    B -- Yes --> C[Increment user's skip counter]
    C --> D{Count vs limit 5}
    D -- "< 5" --> SK[Skip scan silently]
    D -- "= 5" --> M5[Skip scan + email admin & developer]
    D -- "> 5" --> F[Ignore skip → force scan + email]
    S --> G{Quality Gate}
    F --> G
    G -- Pass --> R[Reset user's counter to 0 → merge]
    G -- Fail --> X[Fix & push again]
```

## One-time setup

### 1. Files
Copy into your repo, keeping paths:
```
.github/workflows/sonarqube.yml
.github/scripts/sonar-skip-tracker.sh   # chmod +x recommended
sonar-project.properties                # edit projectKey / organization
```

### 2. SonarQube project
Create the project in **SonarQube Cloud** (free up to 50k LOC) or self-hosted
**SonarQube Server**, then set `sonar.projectKey` (and `sonar.organization` for
Cloud) in `sonar-project.properties`.

### 3. Repository secrets
`Settings → Secrets and variables → Actions → Secrets`:

| Secret            | Purpose                                                        |
|-------------------|----------------------------------------------------------------|
| `SONAR_TOKEN`     | SonarQube analysis token                                       |
| `SONAR_HOST_URL`  | `https://sonarcloud.io` for Cloud, or your server URL          |
| `SONAR_SKIP_PAT`  | **PAT with `Variables: read and write`** (see note below)      |
| `SMTP_SERVER`     | e.g. `smtp.gmail.com`                                           |
| `SMTP_PORT`       | e.g. `465`                                                     |
| `SMTP_USERNAME`   | mailbox the notifications are sent from                         |
| `SMTP_PASSWORD`   | SMTP / app password                                            |

> **Why a PAT?** The built-in `GITHUB_TOKEN` cannot create or update Actions
> **variables**, which is where the skip counter lives. Use a fine-grained PAT
> scoped to this repo with **Variables: Read and write** (or a GitHub App).
> If you'd rather avoid a PAT, see "No-PAT alternative" below.

### 4. Repository variable
`Settings → Secrets and variables → Actions → Variables`:

| Variable             | Value                                        |
|----------------------|----------------------------------------------|
| `SONAR_ADMIN_EMAIL`  | admin address that receives every alert      |

(`SONAR_SKIP_TRACKER` is created automatically on the first skip.)

### 5. Make the gate block merges
`Settings → Branches → Add branch protection rule` for `main`:
- ✅ *Require status checks to pass before merging*
- Select the **SonarQube Quality Gate** check.

This is what actually turns a failed gate into a blocked merge (rather than just
a red ✗). Admins can still bypass in a true emergency, which is your audited
escape hatch.

## Everyday use

```bash
# Normal change — scan runs, gate must pass:
git commit -m "add password reset flow"
git push

# Urgent hotfix — skip the scan (counts toward the 5-skip limit):
git commit -m "hotfix: fix broken checkout [skip sonar]"
git push
```

## Tuning
- **Change the limit:** edit `SKIP_THRESHOLD` in `sonarqube.yml`.
- **Warn a whole team:** add more addresses to `SONAR_ADMIN_EMAIL` (comma-separated).
- **Prefer a GitHub issue over email:** replace the mail step with a
  `gh issue create` step that `@`-mentions the admin and actor (GitHub then
  emails them via notifications) — removes the need for SMTP secrets.

## No-PAT alternative
Instead of a repository variable, store the counter in a committed file
(`.sonar-skip-tracker.json`) and have the workflow push it back using the
built-in `GITHUB_TOKEN` (`permissions: contents: write`). Add `[skip ci]` to
that automated commit to avoid a loop, and expect occasional merge conflicts on
the tracker file for very active teams. The repository-variable approach in this
setup avoids both problems, which is why it's the default.

## Notes / honest caveats
- The scan always analyses the **whole project**; the Quality Gate only judges
  your **new / changed code** — so it "feels" like it checks just your changes.
- Skipping scans on urgent fixes is exactly when bugs slip in. This setup makes
  skipping **deliberate and auditable** (a flag in the commit + an email trail)
  rather than silent. Let the normal scan run on `main` right after.
- The `[skip sonar]` detection reads the head commit message on `push` events.
  On pull-request events it falls back to the PR title.
