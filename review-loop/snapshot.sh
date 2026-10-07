#!/usr/bin/env bash
# Snapshot the working tree (tracked, modified and untracked files, minus ignored ones) as a git tree
# object, without touching the real index, HEAD, the working tree or any ref.
#
# Usage: snapshot.sh <base-ref>
# Prints:
#   tree=<sha>          the snapshot; read it with `git show <sha>:<path>`, diff it with `git diff <a> <sha>`
#   merge_base=<sha>    git merge-base <base-ref> HEAD
#   head=<sha>          HEAD at snapshot time
#   files=<n> added=<a> deleted=<d>
#   --- changed files
#   <one full path per line, from git diff --name-only <merge_base> <tree>>
# Exit 2: bad arguments or refs. Exit 3: no merge-base (shallow clone).
#
# Orchestrator only. Reviewers never run this.
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: snapshot.sh <base-ref>" >&2
  exit 2
fi
base_ref=$1

git rev-parse --verify --quiet HEAD >/dev/null || {
  echo "snapshot.sh: HEAD has no commit yet; commit something first" >&2
  exit 2
}
git rev-parse --verify --quiet "$base_ref^{commit}" >/dev/null || {
  echo "snapshot.sh: base ref '$base_ref' not found (fetch it, or pass the right base)" >&2
  exit 2
}

repo_root=$(git rev-parse --show-toplevel)
real_index=$(git rev-parse --path-format=absolute --git-path index)
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
tmp_index="$tmp_dir/index"

if [ -f "$real_index" ]; then
  cp "$real_index" "$tmp_index"
fi

(
  cd "$repo_root"
  GIT_INDEX_FILE="$tmp_index" git add -A
)
tree=$(GIT_INDEX_FILE="$tmp_index" git write-tree)
merge_base=$(git merge-base "$base_ref" HEAD) || {
  echo "snapshot.sh: no merge-base between '$base_ref' and HEAD (shallow clone? run: git fetch --unshallow)" >&2
  exit 3
}
head_sha=$(git rev-parse HEAD)

numstat=$(git diff --numstat "$merge_base" "$tree")
if [ -z "$numstat" ]; then
  files=0 added=0 deleted=0
else
  files=$(printf '%s\n' "$numstat" | wc -l | tr -d ' ')
  # Binary files show "-" in numstat; count them as 0 lines.
  added=$(printf '%s\n' "$numstat" | awk '{ if ($1 != "-") s += $1 } END { print s + 0 }')
  deleted=$(printf '%s\n' "$numstat" | awk '{ if ($2 != "-") s += $2 } END { print s + 0 }')
fi

echo "tree=$tree"
echo "merge_base=$merge_base"
echo "head=$head_sha"
echo "files=$files added=$added deleted=$deleted"
echo "--- changed files"
git diff --name-only "$merge_base" "$tree"
