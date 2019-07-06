#!/bin/bash

NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'

SCRIPT_PATH=`dirname $0`
cd $SCRIPT_PATH
SCRIPT_PATH=$PWD

destroy_cluster()
{
    echo -e "\n${CYAN}Destroing existing cluster${NONE}\n-------------------------"
    cd $SCRIPT_PATH/terraform/
    terraform destroy --auto-approve=true
}

create_cluster()
{
    cd $SCRIPT_PATH/terraform/
    tfstate=`terraform state list`
    if [[ "$tfstate" != "" ]]
    then
        echo -e "\n${RED}You already have cluster k8s-1${NONE}\n"
        exit 1
    else
        echo -e "\n${CYAN}Installing new cluster k8s-1${NONE}\n----------------------------"
        terraform apply --auto-approve=true
    fi
}

remove_kube_konfig()
{
    echo -e "\n${CYAN}Remove ~/.kube/config${NONE}\n--------------------"
    rm -rf ~/.kube/config
}

get_cred_for_cluster()
{
    echo -e "\n${CYAN}Get gredentials from k8s-1 to kubectl${NONE}\n-------------------------------------"
    gcloud container clusters get-credentials k8s-1
}

deploy_namespaces()
{
    echo -e "\n${CYAN}Deploing PROD namespace${NONE}\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -f deploy_app/namespace-prod.yml --wait
    kubectl apply -f k8s/namespace-monitoring.yml --wait
}

deploy_rabbit_mongo()
{
    echo -e "\n${CYAN}Deploing RABBITMQ and MONGODB${NONE}\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -n prod -f deploy_app/deployment-mongodb.yml \
        -f deploy_app/deployment-rabbitmq.yml \
        -f deploy_app/service-mongodb.yml \
        -f deploy_app/service-rabbitmq.yml \
        -f deploy_app/deployment-mongodb-exporter.yml \
        -f deploy_app/service-mongodb-exporter.yml \
        -f deploy_app/deployment-rabbitmq-exporter.yml \
        -f deploy_app/service-rabbitmq-exporter.yml \
        --wait

}

deploy_base_app()
{
    echo -e "\n${CYAN}Deploing BOT and UI${NONE}\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -n prod \
        -f deploy_app/deployment-bot.yml \
        -f deploy_app/deployment-ui.yml \
        -f deploy_app/service-bot.yml \
        -f deploy_app/service-ui.yml \
        --wait
}

deploy_helm()
{
    echo -e "\n${CYAN}Deploing HELM${NONE}\n-------------"
    cd $SCRIPT_PATH
    kubectl apply -f k8s/tiller.yml --wait
    helm init --service-account tiller --wait
    helm list --all
}

deploy_prometheus()
{
    echo -e "\n${CYAN}Deploing PROMETHEUS${NONE}\n-------------"
    cd $SCRIPT_PATH
    # kubectl apply \
    #     -f k8s/prometheus-rbac.yml \
    #     -f k8s/prometheus-config-map.yml \
    #     -f k8s/prometheus-deployment.yml \
    #     -f k8s/prometheus-service.yml
    helm upgrade --namespace monitoring prometheus charts/prometheus \
            -f charts/prometheus/values.yaml \
            --install --wait
}

deploy_grafana()
{
    echo -e "\n${CYAN}Deploing GRAFANA${NONE}\n-------------"
    # cd $SCRIPT_PATH
    # kubectl apply \
    #     -f k8s/grafana-deployment.yml \
    #     -f k8s/grafana-daemonset-nodeexporter.yml \
    #     -f k8s/grafana-deployment-state-metrics.yml \
    #     -f k8s/grafana-rbac-state-metrics.yml 
    helm upgrade --namespace monitoring grafana charts/grafana/grafana \
        -f charts/grafana/grafana/values.yaml \
        --install \
        --set "adminPassword=admin" \
        --wait
}

output_values()
{
    echo -e "\n${CYAN}Output values${NONE}\n-------------"
    kubectl get svc -n prod
    POD_GRAFANA=`kubectl get pods -n monitoring -l "app=grafana" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    POD_PROMETHEUS=`kubectl get pods -n monitoring -l "app=prometheus,component=alertmanager" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    echo -e "\n\nkubectl --namespace monitoring port-forward ${POD_GRAFANA} 3000"
    echo -e "kubectl --namespace monitoring port-forward ${POD_PROMETHEUS} 9090\n\n"
}

case "$1" in
create)
    create_cluster
    remove_kube_konfig
    get_cred_for_cluster
    deploy_helm
    deploy_namespaces
    deploy_rabbit_mongo
    deploy_base_app
    deploy_prometheus
    deploy_grafana
    output_values
;;

recreate)
    destroy_cluster
    create_cluster
    remove_kube_konfig
    get_cred_for_cluster
    deploy_helm
    deploy_namespaces
    deploy_rabbit_mongo
    deploy_base_app
    deploy_prometheus
    deploy_grafana
    output_values
;;

destroy)
    destroy_cluster
;;

*)
    echo -e "\n${GREEN}create${NONE} - to create new cluster"
    echo -e "${GREEN}recreate${NONE} - to destroy and create cluster"
    echo -e "${GREEN}destroy${NONE} - to destroy existing cluster\n"
;;
esac
