#!/bin/bash
# TRAVIS_BRANCH:
#     for push builds, or builds not triggered by a pull request, this is the name of the branch.
#     for builds triggered by a pull request this is the name of the branch targeted by the pull request.
#     for builds triggered by a tag, this is the same as the name of the tag (TRAVIS_TAG).
# TRAVIS_EVENT_TYPE:
#     Indicates how the build was triggered. One of push, pull_request, api, cron.
# TRAVIS_PULL_REQUEST_BRANCH:
#     if the current job is a pull request, the name of the branch from which the PR originated.
#     if the current job is a push build, this variable is empty ("").
if [[ "$TRAVIS_BRANCH" == "master" ]]
then export TAG=latest
else export TAG=$TRAVIS_BRANCH
fi

docker login -u $docker_user -p $docker_password
docker build -t $docker_user/crawler-bot:$TAG search_engine_crawler
docker build -t $docker_user/crawler-ui:$TAG search_engine_ui
docker push $docker_user/crawler-bot:$TAG
docker push $docker_user/crawler-ui:$TAG
