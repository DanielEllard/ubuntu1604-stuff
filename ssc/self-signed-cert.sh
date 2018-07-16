#!/bin/sh

if [ $# -ne 1 ]; then
    echo "Error: $0: no SNI specified"
    exit 1
fi

HOSTSNI="${1}"

# Note that we're not checking that it's a valid SNI, or even plausible.
# In practice, an SNI should be a DNS name or a local host name, but in
# practice an SNI can be many other things.


# edit as appropriate
#
SUBJ="/C=US/ST=MA/O=EllardHome/CN=$HOSTSNI"
CADIR="${HOME}/PersonalCA"

CAKEYDIR="$CADIR/keys"
CAKEYFILE="${CAKEYDIR}/CA.key"
CACERTFILE="${CAKEYDIR}/CA.pem"
CASERIALFILE="${CAKEYDIR}/CA.srl"

CERTPREFIX="${CAKEYDIR}/host-${HOSTSNI}"

if [ ! -f "${CAKEYFILE}" ]; then
    echo "Error: $0: CAKEYFILE [$CAKEYFILE] does not exist"
    exit 1
fi

if [ ! -f "${CACERTFILE}" ]; then
    echo "Error: $0: CACERTFILE [$CACERTFILE] does not exist"
    exit 1
fi

# Check that the CA directory is secure against casual snooping
#
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

# Remove any previous cert for this SNI.  Be careful.
#
rm -f "${CERTPREFIX}".*

# Note that this script is not portable across all Linux versions
# (or different UNIX/Posix-like operating systems) because it depends
# in each user being assigned their own unique group, and uses the
# non-standard (and non-portable) stat(1) utility.

# Create the certificate request
#
openssl req \
	-nodes -newkey rsa:2048 -sha256 -days 1461 -subj "${SUBJ}" \
	-keyout "${CERTPREFIX}.key" \
	-out "${CERTPREFIX}.csr"

if [ $? -ne 0 ]; then
    echo "Error: $0: certificate request failed"
    rm -f "${CERTPREFIX}".*
    exit 1
fi

# There doesn't seem to be a way to add some of the extension
# fields, like the SNI (aka subjectAltName) directly to the request
# or the signing command, so we need to create a temporary file for this
# purpose.

cat << . > "${CERTPREFIX}.ext"
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage=dataEncipherment,digitalSignature,keyEncipherment,nonRepudiation
subjectAltName=@alt_names

[alt_names]
DNS.1 = $HOSTSNI
.

# Sign the request with the CA certificate and CA key
#
openssl x509 -req \
	-days 1461 -sha256 \
	-CAcreateserial -CAserial "${CASERIALFILE}" \
	-CA "${CACERTFILE}" \
	-CAkey "${CAKEYFILE}" \
	-extfile "${CERTPREFIX}.ext" \
	-in "${CERTPREFIX}.csr" \
	-out "${CERTPREFIX}.pem"

if [ $? -ne 0 ]; then
    echo "Error: $0: signing failed"
    rm -f "${CERTPREFIX}".*
    exit 1
fi

# Append the host key to the end of the certificate file, because
# some applications only know how to use a certificate that contains
# the key (instead of reading it from a separate file).
#
cat "${CERTPREFIX}.key" >> "${CERTPREFIX}.pem"

rm -f "${CERTPREFIX}.ext"

chmod 400 "${CERTPREFIX}".*

echo "New host cert in ${CERTPREFIX}.pem"

exit 0

