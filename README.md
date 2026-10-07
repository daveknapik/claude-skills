# claude-skills

Personal Claude Code skills, versioned here and installed by symlink.

## Install a skill

Each top-level directory is one self-contained skill. Link it into the personal skills directory:

```bash
ln -s ~/Development/claude-skills/review-loop ~/.claude/skills/review-loop
```

A skill resolves its own files relative to its `SKILL.md`, so the symlink is transparent. Start a new
Claude Code session to pick up a newly linked skill.

## Skills

| Skill | What it does |
| --- | --- |
| [`review-loop`](review-loop/README.md) | Fresh-context adversarial review of your own branch, run from the session that wrote it |

## What stays out of this repo

Anything tied to one employer or one codebase. `review-loop/profiles/<repo>.md` files are gitignored;
only the profile schema and a generic example are tracked. Run output lives under
`~/.claude/scratchpad/<repo>/`, never here.
