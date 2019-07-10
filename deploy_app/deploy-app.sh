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
PROD=prod

cd deploy_app/
case "$TRAVIS_EVENT_TYPE" in
push)
    if [[ "$TRAVIS_BRANCH" == "master" ]]; then
        # kubectl apply - $PROD -f deployment-mongodb.yml -f deployment-rabbitmq.yml -f service-mongodb.yml -f service-rabbitmq.yml
        # sleep 30
        kubectl delete -n $PROD deployments crawler-bot
        kubectl delete -n $PROD deployments crawler-ui
        kubectl apply -n $PROD -f deployment-bot.yml \
                                -f deployment-ui.yml \
                                -f service-bot.yml \
                                -f service-ui.yml \
                                --wait=true
        sleep 60
        kubectl get svc -n $PROD
    else
        kubectl create namespace $TRAVIS_BRANCH
        kubectl apply -n $TRAVIS_BRANCH -f deployment-mongodb.yml \
                                        -f deployment-rabbitmq.yml \
                                        -f service-mongodb.yml \
                                        -f service-rabbitmq.yml \
                                        -f deployment-mongodb-exporter.yml \
                                        -f service-mongodb-exporter.yml \
                                        -f deployment-rabbitmq-exporter.yml \
                                        -f service-rabbitmq-exporter.yml \
                                        --wait=true
        # sleep 30
        kubectl delete -n $TRAVIS_BRANCH deployments crawler-bot
        kubectl delete -n $TRAVIS_BRANCH deployments crawler-ui
        sed -i "s/crawler-bot:latest/crawler-bot:${TRAVIS_BRANCH}/" deployment-bot.yml
        sed -i "s/crawler-ui:latest/crawler-ui:${TRAVIS_BRANCH}/" deployment-ui.yml
        kubectl apply -n $TRAVIS_BRANCH -f deployment-bot.yml \
                                        -f deployment-ui.yml \
                                        -f service-bot.yml \
                                        -f service-ui.yml \
                                        --wait=true
        sleep 60
        kubectl get svc -n $TRAVIS_BRANCH
    fi
;;
pull_request)
    # kubectl delete namespace $TRAVIS_PULL_REQUEST_BRANCH
    # kubectl delete -n $PROD deployments crawler-bot
    # kubectl delete -n $PROD deployments crawler-ui
    # kubectl apply -n $PROD -f deployment-bot.yml -f deployment-ui.yml -f service-bot.yml -f service-ui.yml
    # sleep 60
    # kubectl get svc -n $PROD
    kubectl create namespace $TRAVIS_PULL_REQUEST_BRANCH
    kubectl apply -n $TRAVIS_PULL_REQUEST_BRANCH -f deployment-mongodb.yml \
                                                -f deployment-rabbitmq.yml \
                                                -f service-mongodb.yml \
                                                -f service-rabbitmq.yml \
                                                -f deployment-mongodb-exporter.yml \
                                                -f service-mongodb-exporter.yml \
                                                -f deployment-rabbitmq-exporter.yml \
                                                -f service-rabbitmq-exporter.yml \
                                                --wait=true
    # sleep 30
    kubectl delete -n $TRAVIS_PULL_REQUEST_BRANCH deployments crawler-bot
    kubectl delete -n $TRAVIS_PULL_REQUEST_BRANCH deployments crawler-ui
    sed -i "s/crawler-bot:latest/crawler-bot:${TRAVIS_PULL_REQUEST_BRANCH}/" deployment-bot.yml
    sed -i "s/crawler-ui:latest/crawler-ui:${TRAVIS_PULL_REQUEST_BRANCH}/" deployment-ui.yml
    kubectl apply -n $TRAVIS_PULL_REQUEST_BRANCH -f deployment-bot.yml \
                                                -f deployment-ui.yml \
                                                -f service-bot.yml \
                                                -f service-ui.yml \
                                                --wait=true
    sleep 60
    kubectl get svc -n $TRAVIS_PULL_REQUEST_BRANCH
;;
esac
