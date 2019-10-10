#!/usr/bin/env sh

set -ex

STACK_NAME=blog-kennyballou
REGION=us-east-1

function deploy() {
    aws cloudformation \
        --region ${REGION} \
        create-stack \
        --stack-name ${STACK_NAME} \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://$(pwd)/_build/${REGION}/stacks/blog.template
}

function undeploy() {
    aws cloudformation \
        --region ${REGION} \
        delete-stack \
        --stack-name ${STACK_NAME}
}

function changeset() {
    aws cloudformation \
        --region ${REGION} \
        create-change-set \
        --stack-name ${STACK_NAME} \
        --change-set-name ${STACK_NAME}-$(uuidgen) \
        --capabilities CAPABILITY_NAMED_IAM \
        --template-body file://$(pwd)/_build/${REGION}/stacks/blog.template
}

case $1 in
    deploy)
        deploy
        ;;
    changeset)
        changeset
        ;;
    undeploy)
        undeploy
        ;;
    *)
        echo "Available commands are DEPLOY | CHANGESET | UNDEPLOY";
        exit 1;
        ;;
esac
