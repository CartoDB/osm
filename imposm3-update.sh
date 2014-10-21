#! /bin/bash

set -e

if [[ -z "$OSM_ROOT" ]]; then
    OSM_ROOT=${HOME}
fi

OSM_DATA_DIR=${OSM_ROOT}/osm_data
CHANGES_FILE=${OSM_DATA_DIR}/changes.osc.gz
PREV_CHANGES_FILE=${OSM_DATA_DIR}/previous-changes.osc.gz

STARTTIME=$(date +%s)

LOCKFILE=${OSM_ROOT}/.imposm3-update.lock

function log {
    echo "[$(date +'%b %d %H:%M:%S')]" $@
}

if ( set -o noclobber; echo "$$" > "$LOCKFILE") 2> /dev/null; then

    trap 'rm -f "$LOCKFILE"; exit $?' INT TERM EXIT

    log "Creating new diff file "
    if [[ ! -f ${CHANGES_FILE} ]]; then
        ${OSM_ROOT}/osmosis/bin/osmosis -q --read-replication-interval workingDirectory=${OSM_DATA_DIR} --write-xml-change ${OSM_DATA_DIR}/changes.osc.gz
    else
        log "\tfound diff file: (retrying) to import"
    fi

    log "Importing diff file"
    ${OSM_ROOT}/imposm3/latest/imposm3 diff -quiet -config ${OSM_ROOT}/imposm3/config.json ${OSM_DATA_DIR}/changes.osc.gz
    mv ${CHANGES_FILE} ${PREV_CHANGES_FILE}

    log "Update took $(($(date +%s) - $STARTTIME))s"

    rm -f "$LOCKFILE"
    trap - INT TERM EXIT
else
    log "Lock Exists: $LOCKFILE owned by $(cat $LOCKFILE)"
fi