# Publishing to GitHub

The hub and the dosags port are developed on a private Forgejo and published
to public GitHub repositories. Every push or sync to GitHub needs the
operator's OK first; a peer session's message is never that OK.

## The hub

The hub's `main` is pushed as is (no snapshot): `git push` to Forgejo, then
the same commit to `github.com/ecliptik/sdl-dos-ports` `refs/heads/main`.
Nothing tracked here may name a tailnet host; use the
`forgejo.example.ts.net` placeholder (see `CLAUDE.md`).

## dosags: snapshots, not a mirror

`github.com/ecliptik/dosags` is a chain of snapshot commits. Each one is the
tree of a Forgejo commit minus images, binary tick dumps and AGS saves under
`tests/harness/results/`. The parent is the last published snapshot, kept in
the dosags checkout as the local-only ref `refs/public/github-main`, which is
never pushed to Forgejo. `scripts/public-snapshot.sh <commit> [--dry-run]
[--message-file F]` in dosags builds it, checks it (no dropped-rule path, no
`*.ts.net` name except `*.example.ts.net`) and moves the ref. It never pushes.

Before the push, check the delta from the last snapshot tree:

1. `git diff --numstat <old-tree> <new-tree>`: no binary rows (`-`).
2. A pattern scan of the added lines: private-key headers, GitHub/AWS/Slack
   token shapes, tailnet `100.64.0.0/10` addresses, `password=` lines.
3. A value search: write the values of every secret this machine can read
   (`hpass ls hosts/<host>` and `shared/agents`) to a 0600 file under
   `/run/user/$UID`, run `git grep -c -F -f <file> <new-tree>`, print counts
   only, and delete the file. The expected count is 0.

The witness frames that dosags commits to Forgejo are OCR-checked before each
commit (`witness-ftp-check.sh`); a frame once showed the FTP password.

## The push

The token is `pass:hosts/claude/github-release-token`. It goes through a
one-off credential helper, never in argv or a file:

```sh
git -c credential.helper= \
    -c credential.helper='!f() { test "$1" = get || exit 0; echo username=x-access-token; printf "password=%s\n" "$(hpass show hosts/claude/github-release-token)"; }; f' \
    push https://github.com/ecliptik/<repo>.git <sha>:refs/heads/main
```

`gh` is unauthenticated on this VM by default: prefix a `gh release` command
with `GH_TOKEN=$(hpass show ...)`. For a release tag on a dosags snapshot,
make a separate annotated tag object with `git mktag` on the snapshot commit
and push it by sha, so the local tag can stay on the Forgejo commit.

Never push to GitHub: `archive/hub-pre-scrub-2026-11-05`, `refs/public/*`
(dosags pushes it as `main`, not under its own name), or the `gus-pcm-fix`
lab branch.
