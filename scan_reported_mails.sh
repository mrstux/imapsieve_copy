#!/bin/bash
# Modified by Stuart Espey, for mailcow usage
# Original Author: Zhang Huangbin <zhb@iredmail.org> - https://docs.iredmail.org/dovecot.imapsieve.html
# Purpose: Copy spam/ham to another directory and call sa-learn to learn.

# ensure script only runs exclusively, additional invocations return immediately
[ "${FLOCKER}" != "$0" ] && exec env FLOCKER="$0" flock -en "$0" "$0" "$@" || :

OWNER="vmail"
GROUP="vmail"

# Logging to syslog with 'logger' command.
LOG='logger -p mail.info -t dovecot scan_reported_mails: '

# tools that we pipe spam/ham thru
LEARN_SPAM_TOOL="/usr/lib/dovecot/sieve/rspamd-pipe-spam"
LEARN_HAM_TOOL="/usr/lib/dovecot/sieve/rspamd-pipe-ham"


# Spool directory.
# Must be owned by vmail:vmail.
SPOOL_DIR='/var/vmail/imapsieve_copy'

# Directories which store spam and ham emails.
# These 2 should be created while setup Dovecot antispam plugin.
SPOOL_SPAM_DIR="${SPOOL_DIR}/spam"
SPOOL_HAM_DIR="${SPOOL_DIR}/ham"

# Directory used to store emails we're going to process.
# We will copy new spam/ham messages to these directories, scan them, then
# remove them.
SPOOL_LEARN_DIR="${SPOOL_DIR}/processing"
SPOOL_LEARN_SPAM_DIR="${SPOOL_LEARN_DIR}/spam"
SPOOL_LEARN_HAM_DIR="${SPOOL_LEARN_DIR}/ham"

HAM_COUNT=0
SPAM_COUNT=0


# create learn dirs if they don't exist
for dir in "${SPOOL_DIR}" "${SPOOL_LEARN_DIR}" "${SPOOL_LEARN_SPAM_DIR}" "${SPOOL_LEARN_HAM_DIR}"; do
    if [[ ! -d ${dir} ]]; then
        mkdir -p ${dir}
    fi

    chown ${OWNER}:${GROUP} ${dir}
    chmod 0700 ${dir}
done

# move any fresh spam/ham to correct learn dirs

[[ -d ${SPOOL_SPAM_DIR} ]] && find ${SPOOL_SPAM_DIR} -name '*.eml' -exec mv -t ${SPOOL_LEARN_SPAM_DIR}/ {} +
[[ -d ${SPOOL_HAM_DIR} ]]  && find ${SPOOL_HAM_DIR}  -name '*.eml' -exec mv -t ${SPOOL_LEARN_HAM_DIR}/  {} +


# Try to delete empty directory, if failed, that means we have some messages to scan.

rmdir ${SPOOL_LEARN_SPAM_DIR} &>/dev/null
if [[ X"$?" != X'0' ]]; then
    # for every file in the learn spam dir, pipe thru the learn spam tool, and log output
    for i in $(find ${SPOOL_LEARN_SPAM_DIR} -name '*.eml'); do
        ((++SPAM_COUNT))
        EML_NAME=$(basename ${i})
        echo "spam: ${EML_NAME}"
        output="$(cat ${i} | ${LEARN_SPAM_TOOL})"
        ${LOG} '[SPAM]' ${EML_NAME} ${output}
    done

    rm -rf ${SPOOL_LEARN_SPAM_DIR} &>/dev/null
fi

rmdir ${SPOOL_LEARN_HAM_DIR} &>/dev/null
if [[ X"$?" != X'0' ]]; then
    # for every file in the learn ham dir, pipe thru the learn ham tool, and log output
    for i in $(find ${SPOOL_LEARN_HAM_DIR} -name '*.eml'); do
        ((++HAM_COUNT))
        EML_NAME=$(basename ${i})
        echo "ham: ${EML_NAME}"
        output="$(cat ${i} | ${LEARN_HAM_TOOL})"
        ${LOG} '[HAM]' ${EML_NAME} ${output}
    done

    rm -rf ${SPOOL_LEARN_HAM_DIR} &>/dev/null
fi

# cleanup processing dir, if empty
rmdir ${SPOOL_LEARN_DIR} &>/dev/null

TOTAL_COUNT=$(($SPAM_COUNT + $HAM_COUNT))

# log to dovecot log and jobrunner log
if [[ $TOTAL_COUNT -gt 0 ]]; then
    OUTPUT="learned ${TOTAL_COUNT} mails: ${SPAM_COUNT} spam, ${HAM_COUNT} ham"
    echo ${OUTPUT}
    ${LOG} ${OUTPUT}
fi
