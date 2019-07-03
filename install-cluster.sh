#!/bin/bash


SCRIPT_PATH=`dirname $0`
cd $SCRIPT_PATH
SCRIPT_PATH=$PWD

destroy()
{
    echo -e "\nDestroing existing cluster\n-------------------------"
    cd $SCRIPT_PATH/terraform/
    terraform destroy --auto-approve=true
}

create()
{
    echo -e "\nInstalling new cluster k8s-1\n----------------------------"
    cd $SCRIPT_PATH/terraform/
    terraform apply --auto-approve=true
}

remove_kube_konfig()
{
    echo -e "\nRemove ~/.kube/config\n--------------------"
    rm -rf ~/.kube/config
}

get_cred_for_cluster()
{
    echo -e "\nGet gredentials from k8s-1 to kubectl\n-------------------------------------"
    gcloud container clusters get-credentials k8s-1
}

deploy_namespace()
{
    echo -e "\nDeploing PROD namespace\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -f deploy_app/namespace-prod.yml
}

deploy_rabbit_mongo()
{
    echo -e "\nDeploing PROD namespace\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -n prod -f deploy_app/deployment-mongodb.yml \
        -f deploy_app/deployment-rabbitmq.yml \
        -f deploy_app/service-mongodb.yml \
        -f deploy_app/service-rabbitmq.yml
}

deploy_helm()
{
    echo -e "\nDeploing HELM\n-------------"
    cd $SCRIPT_PATH
    kubectl apply -f k8s/tiller.yml
    helm init --service-account tiller
    helm list --all
}


case "$1" in
create)
create
remove_kube_konfig
get_cred_for_cluster
deploy_namespace
deploy_rabbit_mongo
deploy_helm
;;

recreate)
destroy
create
remove_kube_konfig
get_cred_for_cluster
deploy_namespace
deploy_rabbit_mongo
deploy_helm
;;

destroy)
destroy
;;

*)
echo -e "\ncreate - to create new cluster"
echo -e "recreate - to destroy and create cluster"
echo -e "destroy - to destroy existing cluster\n"
 ;;
esac
