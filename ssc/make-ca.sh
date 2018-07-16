#!/bin/sh

# edit as appropriate
SUBJ="/C=US/ST=MA/O=EllardHome/CN=personal-ca"
CADIR="${HOME}/PersonalCA"

CAKEYDIR="$CADIR/keys"
CAKEYFILE="${CAKEYDIR}/CA.key"
CACERTFILE="${CAKEYDIR}/CA.pem"

# Note that this script is not portable across all Linux versions
# (or different UNIX/Posix-like operating systems) because it depends
# in each user being assigned their own unique group, and uses the
# non-standard (and non-portable) stat(1) utility.

if [ ! -d "${CAKEYDIR}" ]; then
    mkdir -p "${CAKEYDIR}"
    chmod 700 "${CAKEYDIR}"
    chown "$USER" "${CAKEYDIR}"
    chgrp "$USER" "${CAKEYDIR}"
elif [ -f "${CAKEYFILE}" ]; then
    echo "Error: $0: CAKEYFILE [$CAKEYFILE] already exists"
    exit 1
fi

if [ ! -d "${CAKEYDIR}" ]; then
    echo "Error: $0: CAKEYDIR [$CAKEYDIR] cannot be created"
    exit 1
fi

# secure it
chmod 700 "${CAKEYDIR}"

if [ $(stat -c %A "${CAKEYDIR}") != "drwx------" ]; then
    stat -c %A "${CAKEYDIR}"	    
    echo "Error: $0: CAKEYDIR [$CAKEYDIR] is not private"
    exit 1
elif [ $(stat -c %U "${CAKEYDIR}") != "${USER}" ]; then
    echo "Error: $0: CAKEYDIR [$CAKEYDIR] is not owned by user"
    exit 1
elif [ $(stat -c %G "${CAKEYDIR}") != "${USER}" ]; then
    echo "Error: $0: CAKEYDIR [$CAKEYDIR] is not owned by user group"
    exit 1
fi


openssl genrsa -out "${CAKEYFILE}" 2048
if [ $? -ne 0 ]; then
    echo "Error: $0: could not generate CA key [$CAKEYFILE]"
    exit 1
fi

openssl req -x509 -new -nodes -sha256 -days 1461 \
	-key "${CAKEYFILE}" -out "${CACERTFILE}" \
	-subj "${SUBJ}"
if [ $? -ne 0 ]; then
    echo "Error: $0: could not generate CA cert [$CACERTFILE]"
    exit 1
fi

chmod 400 "${CAKEYFILE}" "${CACERTFILE}"
if [ $? -ne 0 ]; then
    echo "Error: $0: could not make CA key or cert read-only"
    exit 1
fi

exit 0
