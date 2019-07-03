#!/bin/bash
# TRAVIS_BRANCH:
#     for push builds, or builds not triggered by a pull request, this is the name of the branch.
#     for builds triggered by a pull request this is the name of the branch targeted by the pull request.
#     for builds triggered by a tag, this is the same as the name of the tag (TRAVIS_TAG).
# TRAVIS_EVENT_TYPE:
#     Indicates how the build was triggered. One of push, pull_request, api, cron.
# TRAVIS_PULL_REQUEST:
#     The pull request number if the current job is a pull request, “false” if it’s not a pull request.
# TRAVIS_PULL_REQUEST_BRANCH:
#     if the current job is a pull request, the name of the branch from which the PR originated.
#     if the current job is a push build, this variable is empty ("").
# TRAVIS_PULL_REQUEST_SHA:
#     if the current job is a pull request, the commit SHA of the HEAD commit of the PR.
#     if the current job is a push build, this variable is empty ("").
# TRAVIS_PULL_REQUEST_SLUG:
#     if the current job is a pull request, the slug (in the form owner_name/repo_name) of the repository from which the PR originated.
#     if the current job is a push build, this variable is empty ("").
