# Prompt pack

Prompts you can paste into **any** coding agent — Claude Code, Codex, Cursor, Aider,
OpenCode, or a plain chat window with a capable model.

They are written to be **self-contained**. You paste one, the agent has everything it
needs: the device facts, the protocol rules, the failure taxonomy, and the exact
commands that worked.

---

## How to use them

### Step 1 — Set the context once

Start every session by pasting [`agent-brief.md`](agent-brief.md).

That file carries the things an agent **cannot** infer:

- The device facts (partition map, USB IDs, key combos).
- The protocol rules that are not in any documentation (one session per download-mode
  entry; `--no-reboot`; never pipe to `head`).
- The two independent gates, so the agent does not treat `FAIL! Auth` as a broken
  cable.
- The hard safety rules — never boot stock, never do an irreversible step without a
  human go-ahead.

If you only use one file from this pack, use that one.

### Step 2 — Pick your task

| Your situation | Use |
|---|---|
| Starting from scratch, phone on stock Android | [`01-flash-from-scratch.md`](01-flash-from-scratch.md) |
| Something failed and you do not know why | [`02-when-stuck.md`](02-when-stuck.md) |
| LineageOS is installed; you want Google apps, FRP cleared, or a recovery | [`03-post-install.md`](03-post-install.md) |

### Step 3 — Read the physical screen

**The single most important instruction in this pack:** the agent cannot see the phone.

Every prompt below contains explicit checkpoints where the agent must **stop and ask
you for a physical observation** — a photo of the Odin screen, a description of what
is on the phone, the output of a command you run. Do not let the agent guess past
those points. Every one of them exists because guessing past it cost hours in the
original session.

---

## A note on how these were written

They are not generic "be careful" prompts. They encode specific, hard-won facts:

- *"The bootloader loads BOOT, not RECOVERY"* — so the agent never repeats the mistake
  that made two perfect flashes do nothing.
- *"Samsung grants one protocol session per download-mode entry"* — so the agent never
  burns a session with a detection command.
- *"A backdated clock breaks TLS; the certificate's notBefore is the floor"* — so the
  agent probes instead of guessing a date.
- *"The LineageOS recovery cannot clear the boot request"* — so the agent checks pstore
  before blaming the ROM.

That is what makes the difference between an agent that helps and an agent that
confidently walks your phone into a brick.

---

## Customising

These prompts assume macOS on Apple Silicon and `samloader`. If you are on Windows,
`samloader` has official Windows builds and **does not need Odin** (the default USB
backend is VCOM, so no Zadig driver swap) — say so in the prompt and the agent will
adjust.

If you are on Linux, the same applies.

If you are working on a **different device**, say which one and discard the
device-specific sections. The *structure* of the prompts — diagnose before acting,
verify before proceeding, stop before irreversible steps — is what transfers.
