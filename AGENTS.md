# AGENTS.md

## Purpose

This repository is still in the planning/spec phase. Agents should treat documentation alignment and design consistency as first-class work, not assume implementation has started.

## Source Of Truth

Read these files first, in this order:

1. `requirements.md`
2. `docs/UI_guid_user_journey.md`
3. `docs/architecture.md`
4. `docs/api-design.md`
5. `docs/technical-design.md`
6. `docs/prompts/*.md`

If two docs conflict, prefer:

1. `requirements.md`
2. `docs/UI_guid_user_journey.md`
3. the remaining design docs

Do not silently invent product behavior when the docs disagree. Either align the docs or report the gap explicitly.

## Current Confirmed Product Decisions

- Development has not started yet. Repo work may still be spec-heavy.
- S-002 `テキストハビットチェック` and S-003 `リレーションチェック` images are mocks, not final UI.
- Gemini-related request surfaces are currently split into 4 call types:
  - text habit analysis
  - vision-based chat context extraction
  - ask-user question generation
  - reply generation
- Stage behavior for MVP:
  - AI outputs multiple chips.
  - Tapping a chip inserts that chip into the LINE compose field.
  - Users then edit in the normal compose field before pressing the app's existing send button.
  - There is no dedicated drag-and-drop reorder UI in MVP.
  - Effective ordering is the order in which chips are tapped.
- `mote+AI` ask-user flow behavior for MVP:
  - switching to the `キーボード` tab cancels the ask-user flow
  - temporary question state is discarded
  - any in-flight task should be canceled
- `全文表示` is for confirmation and selection of long-form candidates, not a separate send surface.

## Git Commit Policy

- Agents may commit freely without asking the user for confirmation before each commit.
- Always include a meaningful commit message that describes the change.
- Use conventional commit prefixes: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, etc.
- Commit early and often — small, focused commits are preferred over large batches.
- Do not push to remote unless explicitly asked.
- One commit can cover a large, coherent chunk of work — don't artificially split small related changes.

## Constraints

- Keep iOS keyboard extension limitations in mind:
  - limited height
  - limited memory
  - avoid complex modal flows inside the keyboard
- Prefer reuse of azooKey patterns when they actually fit the confirmed UX.
- Do not reintroduce old labels like `ペルソナ学習`.
- Do not assume dedicated in-keyboard send controls unless the spec explicitly says so.

## What Agents Should Usually Work On

### Explorer Agents

Use for:

- tracing spec conflicts
- locating impacted files
- mapping existing architecture/state flows
- checking prompt/schema consistency

Expected output:

- exact files inspected
- concrete conflicts found
- recommended source-of-truth resolution

### Worker Agents

Use for:

- updating a bounded set of docs
- implementing one clearly scoped feature area
- aligning prompts and schemas
- adding tests for a specific module

Expected output:

- files changed
- behavior changed
- risks or follow-up items

## Parallel Work Split For This App

When implementation starts, split work by file ownership. Good parallel tracks:

1. Host app onboarding/setup
   - S-001 to S-004
   - text habit collection
   - relation setup
   - permissions/setup guidance

2. Keyboard runtime flow
   - `mote+AI` launch
   - ask-user flow
   - stage/full-text state transitions
   - bottom tab behavior

3. AI/prompt/schema pipeline
   - API request/response models
   - prompt files
   - parsing/validation
   - local storage schema

4. Broadcast/Vision pipeline
   - ReplayKit flow
   - latest frame persistence
   - keyboard-side retrieval
   - fallback handling

Do not assign overlapping write scopes to different worker agents.

## Prompt Templates For Other Chats / Agents

### 1. Repo Explorer

Use this when you want a read-only repo scan:

```text
Explore this repo and answer only these questions:
1. Which files define the source of truth for <topic>?
2. What conflicts exist between requirements.md and UI_guid_user_journey.md for <topic>?
3. Which files would need to change if we adopt <decision>?

Do not edit files. Give file paths, concrete findings, and a recommended resolution.
```

### 2. Doc Alignment Worker

Use this when you already know the decision and want the docs updated:

```text
Update the docs for <decision>.

Source of truth:
- requirements.md
- docs/UI_guid_user_journey.md

Rules:
- align all affected docs
- do not leave old terminology behind
- if a behavior is removed, remove stale references rather than adding comments everywhere

At the end, report:
- files changed
- exact behavior now defined
- remaining ambiguities
```

### 3. Keyboard Flow Worker

Use this when implementing keyboard behavior:

```text
You own the keyboard runtime flow only.

Files/modules in scope:
- keyboard state management
- ask-user flow
- stage/full-text behavior
- bottom tab switching

Confirmed product decisions:
- chip tap inserts into compose field
- no dedicated reorder UI in MVP
- switching to キーボード cancels mote+AI flow

Do not edit onboarding or prompt docs unless required for compile/runtime consistency.
Report changed files and any unresolved edge cases.
```

### 4. Prompt / Schema Worker

Use this when aligning prompts with runtime expectations:

```text
You own prompt and schema consistency only.

Check:
- prompt inputs vs stored data models
- question-generation schema
- reply-generation schema
- fallback assumptions

Do not change UI flow unless a schema conflict makes it necessary.
List every prompt/schema mismatch before editing.
```

### 5. Review Agent

Use this after a worker returns:

```text
Review these changes for product-spec regressions.

Focus on:
- mismatch with requirements.md
- mismatch with docs/UI_guid_user_journey.md
- stale terminology
- state transitions that no longer match the confirmed UX

Findings first. Keep summary brief.
```

## Recommended Agent Sequence For This Repo

Use this order unless the task is very small:

1. Explorer
   - identify source-of-truth docs for the topic
   - list spec conflicts
   - propose the minimum file set to update
2. Doc or feature worker
   - own one bounded write scope
   - update only the files needed for that scope
3. Review agent
   - check for regressions against `requirements.md` and `docs/UI_guid_user_journey.md`

For this app, practical work splits are:

1. Docs/spec alignment
   - `requirements.md`
   - `docs/UI_guid_user_journey.md`
   - `docs/architecture.md`
   - `docs/api-design.md`
2. Prompt/schema alignment
   - `docs/prompts/*.md`
   - request/response schema docs
   - storage field definitions
3. Keyboard runtime implementation
   - keyboard state
   - `mote+AI` flow
   - stage/full-text transitions
4. Host app setup implementation
   - onboarding
   - text habit setup
   - relation setup
   - ReplayKit guidance

Do not run two worker agents on the same write scope at the same time.

## Ready-To-Paste Requests

Use these as-is in other chats or when instructing Codex subagents.

### A. Repo Explorer

```text
Spawn a subagent to explore this repo.

Focus only on the keyboard runtime flow for mote+AI.
Check:
- source-of-truth files
- current state-machine definitions
- conflicts between requirements.md and docs/UI_guid_user_journey.md
- files that would need edits for implementation

Do not edit files.
Return:
1. files inspected
2. confirmed behavior
3. conflicts
4. recommended next edit targets
```

### B. Doc Alignment Worker

```text
Spawn a worker to align the docs for the confirmed product decisions.

Confirmed decisions:
- S-002 is テキストハビットチェック
- S-002/S-003 images are mocks, not final UI
- chip tap inserts into the LINE compose field
- users edit in the compose field before send
- no dedicated reorder UI in MVP
- chip order equals tap order
- switching to キーボード cancels the mote+AI question flow

Ownership:
- requirements.md
- docs/UI_guid_user_journey.md
- docs/architecture.md
- docs/api-design.md
- docs/azookey-reference.md

Do not touch prompt files unless a doc conflict requires it.
End with:
1. Changed files
2. What changed
3. Open risks
4. Suggested next step
```

### C. Prompt/Schema Worker

```text
Spawn a worker to verify prompt/schema consistency only.

Check:
- docs/prompts/prompt_text_habit_analyze.md
- docs/prompts/prompt_question_choice_generate.md
- docs/prompts/prompt_stage_message_generate.md
- any schema or API design docs they depend on

Focus on:
- input fields required by prompts
- whether relation/text-habit data is sufficient
- response schema mismatches
- fallback handling

Do not edit UI docs unless a schema mismatch forces a spec change.
Report mismatches first, then fixes.
```

### D. Review Agent

```text
Spawn a subagent to review the latest changes for product-spec regressions.

Focus on:
- mismatch with requirements.md
- mismatch with docs/UI_guid_user_journey.md
- stale terminology such as ペルソナ学習
- any UI flow that still assumes dedicated in-keyboard send or reorder controls

Findings first.
For each finding, include:
- severity
- file path
- why it is a problem
```

## Subagent Usage Guidance

- Spawn explorers first when the next implementation step is unclear.
- Spawn workers only after file ownership is clear.
- Reuse one explorer for follow-up questions on the same topic instead of spawning duplicates.
- If the work is tightly coupled and blocked on one answer, do it in the main thread instead of delegating.
- After a worker finishes, run one focused review pass rather than asking multiple agents to review the same diff.

## Required Reporting Format From Agents

Ask subagents to end with:

1. `Changed files`
2. `What changed`
3. `Open risks`
4. `Suggested next step`

This keeps multi-agent integration manageable.

## Worktree / Parallel Agent Completion Protocol

Each agent runs in its own git worktree and has no visibility into other agents' progress. Because of this:

- **Do not wait for or check on other agents.** You cannot see their status.
- **When your assigned scope is fully done, you are done.** Commit all changes, write the reporting format above, and finish.
- **Leave a completion summary as the final commit message body.** Include:
  - what was accomplished
  - any open risks or unresolved items
  - suggested follow-up work (if any)
- **Do not assume other agents have finished or will finish.** Your work must be self-contained and mergeable on its own.
- **Prefer larger, meaningful units of work per session.** It is better to complete an entire feature area or doc alignment pass in one go than to stop early and hand off fragments. Take on as much as you can within your assigned scope.
