#!/usr/bin/env bash
# Script to manage GCP secrets

printf "This script will walk you through managing GCP secrets.\n\n"

# Choose replicate or delete functions
if [ -z "$1" ]; then
    printf "Missing arguement. Please use create or delete with caution.\n\n"
    exit
fi


if [ "$1" == delete ]; then
    printf "Enter your target project: "
    read -r TARGET
    echo

    printf "Enter your filter pattern: "
    read -r FILTER
    echo

    SECRET_LIST=$(gcloud secrets list --project $TARGET --filter="$FILTER" --format=json \
        | jq -r '.[].name' \
        | cut -d"/" -f4 \
        | head -10)

    printf "Warning!! you are about to delete secrets from $TARGET:\n\n"
    printf "$SECRET_LIST\n\n"
    printf "Confirm: (YES/NO)? "
    read -r APPROVE
    echo

    if [[ -z $APPROVE || $APPROVE != "YES" ]]; then
        exit
    elif [[ $APPROVE == "YES" ]]; then   
        declare -a SECRET_ARRAY=($SECRET_LIST)
        for i in "${SECRET_ARRAY[@]}"
        do
            SECRET_NAME="${i}"
            $(gcloud secrets $1 ${SECRET_NAME} --project $TARGET)
        done
    else
        exit
    fi
fi


if [ "$1" == create ]; then
    # Choose source and destination for migration
    printf "Enter your source project: "
    read -r SOURCE
    echo

    printf "Enter your target project: "
    read -r TARGET
    echo

    printf "Enter your filter pattern: "
    read -r FILTER
    echo

    printf "You are about to replicate secrets from "$SOURCE" to "$TARGET".\n\n"

    SECRET_LIST=$(gcloud --project $SOURCE secrets list --project $SOURCE --filter="$FILTER" --format=json \
        | jq -r '.[].name' \
        | cut -d"/" -f4 \
        | head -10)

    printf "\n\n $SECRET_LIST \n\n"
    printf "Confirm: (YES/NO)? "
    read -r APPROVE
    echo

    if [[ -z $APPROVE || $APPROVE != "YES" ]]; then
        exit
    elif [[ $APPROVE == "YES" ]]; then
    
        declare -a SECRET_ARRAY=($SECRET_LIST)

        for i in "${SECRET_ARRAY[@]}"
        do
            SECRET_NAME="${i}"
            SECRET_VALUE=$(gcloud secrets versions access "latest" --secret=${SECRET_NAME})
            echo $SECRET_VALUE > secret_migrate_file
            $(gcloud secrets $1 ${SECRET_NAME} --project $TARGET --data-file=secret_migrate_file)
        done
            if [ -f secret_migrate_file ]; then
            rm secret_migrate_file
            fi
    else
        exit
    fi
fi
