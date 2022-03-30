#!/bin/bash

log() {
    NOW=$(date +"%Y-%m-%d %H:%M:%S")
    echo "${NOW} [$1] $2"
}

log_info() {
    log "INFO" "$1"
}

log_warn() {
    log "WARN" "$1"
}

log_error() {
    log "ERROR" "$1"
}

title() {
    echo "====== $1 ======"
}

call_command() {
    command=$1
    
    shift
    log_info "Running command ${command}"
    if ! python manage.py "${command}" "$@"
    then
        status=$?
        log_warn "Command ${command} failed with status ${status}"
        return ${status}
    fi
    
    return 0
}

call_definition_command() {
    command=$1
    definition=$2
    shift 2
    
    # check definition exists
    if [ ! -f "${definition}" ]; then
        log_warn "Definition file ${definition} does not exist, skipped"
        return 0
    fi
    
    if ! call_command "${command}" -f "${definition}" "$@"
    then
        status=$?
        log_warn "Command ${command} failed with status ${status}"
        return ${status}
    fi
    
    return 0
}

must_call_definition_command() {
    command=$1
    definition=$2
    
    shift 2
    call_definition_command "${command}" "${definition}" "$@"
    
    status=$?
    case ${status} in
        0)
            return 0
        ;;
        *)
            log_error "Crash during command ${command}"
            exit ${status}
        ;;
    esac
}

title "begin to db migrate"
call_command migrate

title "syncing apigateway"
must_call_definition_command sync_apigw_config data/definition.yaml
must_call_definition_command sync_apigw_stage data/definition.yaml
must_call_definition_command sync_apigw_strategies data/definition.yaml
must_call_definition_command apply_apigw_permissions data/definition.yaml
must_call_definition_command grant_apigw_permissions data/definition.yaml
must_call_definition_command sync_apigw_resources data/resources.yaml --delete
must_call_definition_command sync_resource_docs_by_archive data/definition.yaml
must_call_definition_command create_version_and_release_apigw data/definition.yaml

title "fetch apigateway public key"
call_command fetch_apigw_public_key --print

title "fetch esb public key"
call_command fetch_esb_public_key --print

title "done"
