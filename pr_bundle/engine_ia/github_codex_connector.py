#!/usr/bin/env python3
"""
github_codex_connector.py

Fetch changed files from a GitHub Pull Request, send each file to the local
`/llm/codex` endpoint for review, and post a summarized PR review comment.

Usage (from project root):
  export GITHUB_TOKEN="ghp_..."
  python engine_ia/github_codex_connector.py --repo owner/repo --pr 123

Notes:
- Requires network access and a valid GitHub token with repo:pull_requests scope.
- The script posts a single PR review with a consolidated summary. For inline
  comments you'd need to compute patch positions; this script keeps things
  simple and posts a readable summary instead.
"""

import os
import sys
import argparse
import json
from utils.http import get, post
from pathlib import Path

GITHUB_API = "https://api.github.com"
LOCAL_LLM = os.environ.get("LOCAL_LLM_URL", "http://127.0.0.1:8123/llm/codex")
WHITELIST = {".py", ".cs", ".xaml", ".ps1", ".yaml", ".yml", ".csproj", ".json"}


def gh_headers(token: str):
    return {"Authorization": f"token {token}", "Accept": "application/vnd.github+json"}


def fetch_pr_files(repo: str, pr: int, token: str):
    url = f"{GITHUB_API}/repos/{repo}/pulls/{pr}/files"
    files = []
    page = 1
    while True:
        r = get(
            url,
            headers=gh_headers(token),
            params={"page": page, "per_page": 100},
            timeout=30,
        )
        batch = r.json()
        if not batch:
            break
        files.extend(batch)
        page += 1
    return files


def fetch_pr_info(repo: str, pr: int, token: str):
    url = f"{GITHUB_API}/repos/{repo}/pulls/{pr}"
    r = get(url, headers=gh_headers(token), timeout=30)
    return r.json()


def fetch_file_raw(raw_url: str, token: str):
    # raw_url may be githubusercontent raw URL which doesn't need auth, but use token to be safe
    headers = gh_headers(token)
    r = get(raw_url, headers=headers, timeout=30)
    return r.text


def call_local_codex(prompt: str):
    payload = {"prompt": prompt, "max_tokens": 512, "model": "code-davinci-002"}
    r = post(LOCAL_LLM, json=payload, timeout=60)
    return r.json()


def first_added_position_from_patch(patch: str):
    """Return the diff position for the first added line '+' in the patch.

    GitHub expects the 'position' field to be the 1-based index of the line within the
    unified diff payload where the comment should be placed. We implement a pragmatic
    approach: walk the patch lines after the first hunk header and increment a position
    counter for each diff line (context, +, -). When we find the first added line
    (starting with '+', but not '+++'), return the current position.
    """
    if not patch:
        return None
    pos = 0
    in_hunk = False
    for ln in patch.splitlines():
        if ln.startswith("@@"):
            in_hunk = True
            # hunk header itself is not counted as a patch line
            continue
        if not in_hunk:
            continue
        # count only actual diff lines (context, add, remove)
        if ln.startswith("+") or ln.startswith("-") or ln.startswith(" "):
            pos += 1
            # skip the '+++' file header lines by guard: those are outside hunks
            if ln.startswith("+++"):
                continue
            if ln.startswith("+") and not ln.startswith("+++"):
                return pos
        else:
            # treat any other line as non-diff (be conservative)
            continue
    return None


def make_prompt(filename: str, content: str):
    header = (
        f"Revisa este archivo ({filename}) para problemas de seguridad, bugs, anti-patrones y recomendaciones concisas. "
        "Devuelve un JSON con: issues (lista corta), severity (low/medium/high), recommendation (texto corto).\n---\n"
    )
    if len(content) > 64 * 1024:
        content = content[: 64 * 1024] + "\n\n/* TRUNCATED */"
    return header + content


def post_pr_review(repo: str, pr: int, body: str, token: str):
    url = f"{GITHUB_API}/repos/{repo}/pulls/{pr}/reviews"
    payload = {"body": body, "event": "COMMENT"}
    r = post(url, headers=gh_headers(token), json=payload, timeout=30)
    return r.json()


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repo", required=True, help="owner/repo")
    p.add_argument("--pr", required=True, type=int, help="PR number")
    p.add_argument("--token", help="GitHub token (or set GITHUB_TOKEN)")
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Do not post reviews; print what would be posted",
    )
    args = p.parse_args()

    token = args.token or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("Error: provide --token or set GITHUB_TOKEN env var", file=sys.stderr)
        sys.exit(2)

    print(f"Fetching PR files for {args.repo}#{args.pr}...")
    files = fetch_pr_files(args.repo, args.pr, token)
    review_sections = []
    inline_comments = []

    pr_info = fetch_pr_info(args.repo, args.pr, token)
    head_sha = pr_info.get("head", {}).get("sha")

    for f in files:
        filename = f.get("filename")
        raw_url = f.get("raw_url") or f.get("contents_url")
        ext = Path(filename).suffix.lower()
        if ext not in WHITELIST:
            print("Skipping", filename)
            continue
        try:
            if raw_url and raw_url.startswith("https://"):
                content = fetch_file_raw(raw_url, token)
            else:
                # fallback to contents API
                contents_api = f.get("contents_url")
                if contents_api:
                    rc = get(contents_api, headers=gh_headers(token), timeout=30)
                    j = rc.json()
                    import base64

                    content = base64.b64decode(j.get("content", "")).decode(
                        "utf-8", errors="replace"
                    )
                else:
                    content = ""

            prompt = make_prompt(filename, content)
            print("Calling local codex for", filename)
            resp = call_local_codex(prompt)
            # create short summary for the review body
            snippet = json.dumps(resp, ensure_ascii=False, indent=2)[:4000]
            summary = "### " + filename + "\n```\n" + snippet + "\n```\n"
            review_sections.append(summary)

            # If patch exists and we can compute a position, create an inline comment
            patch = f.get("patch")
            pos = first_added_position_from_patch(patch) if patch else None
            if pos:
                comment_body = ""
                # prefer LLM short recommendation if available
                if isinstance(resp, dict) and resp.get("completion"):
                    comment_body = resp.get("completion")
                else:
                    comment_body = snippet
                inline_comments.append(
                    {"path": filename, "position": pos, "body": comment_body}
                )
        except Exception as e:
            print("Error processing", filename, e)
            review_sections.append(f"### {filename}\nError: {e}\n")

    if not review_sections:
        body = "Codex review found no files to analyze."
    else:
        body = "# Codex automated review\n\n" + "\n\n".join(review_sections)

    # If dry-run, print the would-be submissions instead of posting
    if args.dry_run:
        print("\nDRY-RUN: Summary review body:\n")
        print(body[:10000])
        if inline_comments:
            print("\nDRY-RUN: Inline comments to post:")
            for c in inline_comments:
                print(
                    f"- path={c['path']} position={c['position']} body_snippet={str(c['body'])[:200]}"
                )
        else:
            print("\nDRY-RUN: No inline comments to post.")
        return

    # If we have inline comments prepared, post a review with comments array
    if inline_comments:
        review_payload = {
            "commit_id": head_sha,
            "body": "Codex automated inline review",
            "event": "COMMENT",
            "comments": inline_comments,
        }
        url = f"{GITHUB_API}/repos/{args.repo}/pulls/{args.pr}/reviews"
        r = post(url, headers=gh_headers(token), json=review_payload, timeout=30)
        posted = r.json()
        print("Posted inline review id:", posted.get("id"))
    else:
        print("Posting summary review... (length", len(body), "chars)")
        posted = post_pr_review(args.repo, args.pr, body, token)
        print("Posted summary review id:", posted.get("id"))


if __name__ == "__main__":
    main()
