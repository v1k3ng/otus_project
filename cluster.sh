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
    echo -e "\n${CYAN}Deploing namespaces PROD, LOGGING, MONITORING${NONE}\n-----------------------"
    cd $SCRIPT_PATH
    kubectl apply -f deploy_app/namespace-prod.yml \
                    -f k8s/namespace-monitoring.yml \
                    -f k8s/namespace-logging.yml \
                    --wait
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
        # helm upgrade --namespace prod mr mongodbrabbitmq -f mongodbrabbitmq/values.yaml --wait --install

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
        # helm upgrade --namespace prod crawlerengine crawlerengine/ -f crawlerengine/values.yaml --wait --install
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
            --set-string alertmanagerFiles."alertmanager\.yml".global.slack_api_url=${SLACKAPIURL} \
            --set-string alertmanagerFiles."alertmanager\.yml".receivers[0].slack_configs[0].channel=${SLACKCHANNEL} \
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

deploy_fluentd()
{
    echo -e "\n${CYAN}Deploing FLUENTD${NONE}\n-------------"
    cd $SCRIPT_PATH
    helm upgrade --namespace logging fluentd charts/fluentd \
        -f charts/fluentd/values.yaml \
        --install --wait 
}

deploy_elasticsearch()
{
    echo -e "\n${CYAN}Deploing ELASTICSEARCH${NONE}\n-------------"
    cd $SCRIPT_PATH
    helm upgrade --namespace logging elasticsearch charts/elasticsearch \
        -f charts/elasticsearch/values.yaml \
        --install --wait 
}

deploy_kibana()
{
    echo -e "\n${CYAN}Deploing KIBANA${NONE}\n-------------"
    cd $SCRIPT_PATH
    helm upgrade --namespace logging kibana charts/kibana \
        -f charts/kibana/values.yaml \
        --install --wait 
}

output_values()
{
    echo -e "\n${CYAN}Output values${NONE}\n-------------"
    kubectl get svc -n prod ui
    POD_GRAFANA=`kubectl get pods -n monitoring -l "app=grafana" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    POD_PROMETHEUS=`kubectl get pods -n monitoring -l "app=prometheus,component=server" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    POD_ALERTMANAGER=`kubectl get pods -n monitoring -l "app=prometheus,component=alertmanager" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    POD_ELASTICSEARCH=`kubectl get pods -n logging -l "app=elasticsearch,component=client,release=elasticsearch" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    POD_KIBANA=`kubectl get pods --namespace logging -l "app=kibana,release=kibana" -o go-template --template '{{range .items}}{{.metadata.name}}{{"\n"}}{{end}}'`
    echo -e "\n\nkubectl --namespace monitoring port-forward ${POD_GRAFANA} 3000"
    echo -e "kubectl --namespace monitoring port-forward ${POD_PROMETHEUS} 9090"
    echo -e "kubectl --namespace monitoring port-forward ${POD_ALERTMANAGER} 9093"
    echo -e "kubectl --namespace logging port-forward ${POD_ELASTICSEARCH} 9200"
    echo -e "kubectl --namespace logging port-forward ${POD_KIBANA} 5601\n\n"
}


case "$1" in
create)
    if [[ -v SLACKAPIURL && -v SLACKCHANNEL ]]
    then
        create_cluster
        remove_kube_konfig
        get_cred_for_cluster
        deploy_helm
        deploy_namespaces
        deploy_elasticsearch
        deploy_fluentd
        deploy_rabbit_mongo
        deploy_base_app
        deploy_prometheus
        deploy_grafana
        deploy_kibana
        output_values
    else
        echo -e "\nVariables ${RED}SLACKAPIURL${NONE} and ${RED}SLACKCHANNEL${NONE} not found!\n"
        exit 1
    fi
;;

recreate)
    if [[ -v SLACKAPIURL && -v SLACKCHANNEL ]]
    then
        destroy_cluster
        create_cluster
        remove_kube_konfig
        get_cred_for_cluster
        deploy_helm
        deploy_namespaces
        deploy_elasticsearch
        deploy_fluentd
        deploy_rabbit_mongo
        deploy_base_app
        deploy_prometheus
        deploy_grafana
        deploy_kibana
        output_values
    else
        echo -e "\nVariables ${RED}SLACKAPIURL${NONE} and ${RED}SLACKCHANNEL${NONE} not found!\n"
        exit 1
    fi
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
