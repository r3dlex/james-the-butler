"""GitHub API client wrapper."""

from __future__ import annotations

import os

from github import Auth, Github


def get_client() -> Github:
    """Create an authenticated GitHub client from environment."""
    token = os.environ.get("GITHUB_TOKEN", "")
    auth = Auth.Token(token)
    return Github(auth=auth)
