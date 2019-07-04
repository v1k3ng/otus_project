#!/bin/bash


SCRIPT_PATH=`dirname $0`
cd $SCRIPT_PATH
SCRIPT_PATH=$PWD

destroy_cluster()
{
    echo -e "\nDestroing existing cluster\n-------------------------"
    cd $SCRIPT_PATH/terraform/
    terraform destroy --auto-approve=true
}

create_cluster()
{
    echo -e "\nInstalling new cluster k8s-1\n----------------------------"
    cd $SCRIPT_PATH/terraform/
    tfstate=`terraform state list`
    if [[ "$tfstate" != "" ]]
    then
        echo "You already have cluster k8s-1"
        exit 1
    else
        terraform apply --auto-approve=true
    fi
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

deploy_namespaces()
{
    echo -e "\nDeploing PROD namespace\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -f deploy_app/namespace-prod.yml
    kubectl apply -f k8s/namespace-monitoring.yml
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

deploy_prometheus()
{
    echo -e "\nDeploing PROMETHEUS\n-------------"
    cd $SCRIPT_PATH
    kubectl apply -n monitoring \
        -f k8s/prometheus-clusterrole.yml \
        -f k8s/prometheus-config-map.yml \
        -f k8s/prometheus-deployment.yml
}


case "$1" in
create)
create_cluster
remove_kube_konfig
get_cred_for_cluster
deploy_namespaces
deploy_rabbit_mongo
deploy_helm
deploy_prometheus
;;

recreate)
destroy_cluster
create_cluster
remove_kube_konfig
get_cred_for_cluster
deploy_namespaces
deploy_rabbit_mongo
deploy_helm
deploy_prometheus
;;

destroy)
destroy_cluster
;;

*)
echo -e "\ncreate - to create new cluster"
echo -e "recreate - to destroy and create cluster"
echo -e "destroy - to destroy existing cluster\n"
 ;;
esac
