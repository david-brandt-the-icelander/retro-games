---
name: knowledge-driven-development
description: Plan, implement, review and document changes under knowledge-driven development, where the documents describing the system are the backlog and every statement carries a mark saying whether it is true yet.
---

# Knowledge-driven development

Use this skill when a repository's agent instructions say it follows knowledge-driven development, when a document carries the line `> Status marks: [knowledge-driven development](...)` at its top, when asked to plan a feature "using knowledge-driven development", and whenever a change alters behavior a reader of the documentation can see. The convention is defined once, in its own repository, and nothing restates it: read it there and link to it, never copy it into the repository you are working in.

- Convention: <https://github.com/david-brandt-the-icelander/knowledge-driven-development> (`git@github.com:david-brandt-the-icelander/knowledge-driven-development.git`). Read `README.md` first, then `02-annotation-convention.md` before writing or moving any mark, and `03-workflow.md` before planning or reviewing. `templates/` has a starting file per document kind and the lines for a repository's agent instructions.
- Reasoning and experience: the series on icelander.net, starting with [There is no TODO](https://icelander.net/v1/processes/there-is-no-todo) and continuing with [The plan is where the work lives](https://icelander.net/v1/processes/the-plan-is-where-the-work-lives). The whole Processes train is at <https://icelander.net/v1/processes>.

## The marks

| Mark | Means | What you must write |
| --- | --- | --- |
| ✅ | Implemented and verified | Only after you have read the code and seen its tests pass. A plan, a merged pull request or another agent's report of success does not count. |
| ⚠️ | Not implemented | The intended behavior, in the present tense, in enough detail that an agent can build from it without asking much. Never the words "not implemented". |
| ❌ | Implemented but broken | The correct behavior, stated as it should be. Not the wrong behavior, not how it was found. |
| ⛔ | Blocked | Straight after the ⚠️ or ❌ it qualifies (`⚠️⛔`), never alone, always saying what would unblock it. |

The mark is the whole commentary: write the sentence as the system should be, mark it, stop. Marks go in documentation only, never in source comments and never in a string a user reads. Put the mark on the smallest statement that is wholly true or wholly false; never mark a heading and its contents both. A page links to the convention in one line at the top and never restates the legend, because the greps `grep -rn '⚠️' documentation/` and `grep -rn '❌' documentation/` are the backlog and only work if every glyph is a claim. Do not mark facts that are not capabilities, goals or rules, non-goals, historical records (changelogs, decision records, change logs), or anything a test can assert instead.

## Planning

When asked to plan a feature, do not produce a list of steps. Edit the documents that already describe the system, or create the ones that should exist from `templates/`, and describe the feature in them in the present tense as the system will be once it exists: the feature document gets the capability statement by statement, the journeys get their new steps, the subsystem documents get the new ways things fail and what an operator does, the contract gets the new operations and shapes. Every new statement is ⚠️. Anything that cannot be built from here is ⚠️⛔ with what would unblock it. A fact belongs in exactly one document; the more specific one holds it and the others link. That set of marked documents is the plan and the sprint, and it never expires.

## Implementing

Before changing anything, read the documents that describe it; they are your primary guidance, ahead of the prompt, the chat history or any ticket. Find the ⚠️ marks and build from them. The one rule you must follow: the mark moves in the same commit as the code that changes its truth. Write ✅ only after reading the code and seeing the tests pass. When a fix has to wait, record the defect as a ❌ in the document that owns the behavior, carrying its severity if it had one. Never write `TODO`, `FIXME`, `HACK` or `XXX`, and never create a folder of deferred work; write a ⚠️ or ❌ in the owning document instead. Write a change log for every prompt that changes the code: what was asked, how you interpreted it, and what the change needs (testing, data migration, compatibility). When a document has no ⚠️ and no ❌ left, graduate it: delete every ✅ in its body and replace the status line with `> ✅ This component is fully implemented, tested and free of known defects.`

## Reviewing

Start with the delta to the knowledge documents and the change logs, not the code. Every mark that moved is a claim naming a behavior. A pull request that changes behavior and moves no mark is the first question to ask. Then check the claims as an agent that did not write the change: read the code behind every ✅ that moved and run its tests. Re-read ⛔ marks in the area, since they can become false without anyone touching the code. When asked to review documents for staleness, check each marked statement against the code, on request or on a schedule; there is no mechanical fix worth having.

## Adopting

Add the block from `templates/agent-instructions.md` to the repository's `AGENTS.md` or `CLAUDE.md`, linking to the convention rather than copying it. Move every `TODO/` item and every `TODO`, `FIXME`, `HACK` or `XXX` comment into the document that owns the capability as a ⚠️ or ❌, delete the folder, and add the gate that fails the build if either returns (`06-enforcement.md`). Have an agent reverse-engineer missing documents of the right kind (`04-document-taxonomy.md`) for whatever the next feature touches, and have a human review them. Convert other documents when they are next substantively edited, by meaning and statement by statement, never by find-and-replace over glyphs. Never annotate the changelog, decision records or change logs.
