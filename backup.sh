#!/bin/bash

# fail on error
set -e

# trace shell
set -x

# =============================================================================================
function retry() {
	local -r -i max_attempts="$1"; shift
	local -r -i sleep_time="$1"; shift
	local -i attempt_num=1
	until "$@"; do
		if (( attempt_num == max_attempts ))
	then
		echo "#$attempt_num failures!"
		exit 1
	else
		echo "#$(( attempt_num++ )): trying again in $sleep_time seconds ..."
		sleep $sleep_time
		fi
	done
}

# =============================================================================================
# check for env vars
set +x
if [[ -z "${PGHOST}" ]]; then
	echo "PGHOST is missing"
	exit 1
fi
if [[ -z "${PGPORT}" ]]; then
	echo "PGPORT is missing"
	exit 1
fi
if [[ -z "${PGUSER}" ]]; then
	echo "PGUSER is missing"
	exit 1
fi
if [[ -z "${PGPASSWORD}" ]]; then
	echo "PGPASSWORD is missing"
	exit 1
fi
if [[ -z "${PGDUMPPATH}" ]]; then
	echo "PGDUMPPATH is missing"
	exit 1
fi
if [[ -z "${FILE_RETENTION}" ]]; then
	echo "FILE_RETENTION is missing"
	exit 1
fi
if [[ -z "${S3_UPLOAD_ENABLED}" ]]; then
	echo "S3_UPLOAD_ENABLED is missing"
	exit 1
fi
if [[ "${S3_UPLOAD_ENABLED}" == "true" ]]; then
	if [[ -z "${S3_ACCESS_KEY}" ]]; then
		echo "S3_ACCESS_KEY is missing"
		exit 1
	fi
	if [[ -z "${S3_SECRET_KEY}" ]]; then
		echo "S3_SECRET_KEY is missing"
		exit 1
	fi
	if [[ -z "${S3_ENDPOINT}" ]]; then
		echo "S3_ENDPOINT is missing"
		exit 1
	fi
	if [[ -z "${S3_BUCKET}" ]]; then
		echo "S3_BUCKET is missing"
		exit 1
	fi
	if [[ -z "${S3_RETENTION}" ]]; then
		echo "S3_RETENTION is missing"
		exit 1
	fi
fi
set -x


# =============================================================================================
echo "waiting on postgres ..."
retry 7 7 psql -d postgres -c '\q'
echo "postgres is up!"

# =============================================================================================
# backup postgres cluster
mkdir -p "${PGDUMPPATH}" || true
TIMESTAMP=$(date "+%Y%m%d%H%M%S")
DUMPFILE="${PGDUMPPATH}/${TIMESTAMP}.sql"
DUMPFILE_GZ="${DUMPFILE}.gz"

# create dump
pg_dumpall --no-password --clean -f "${DUMPFILE}"
gzip "${DUMPFILE}"

# file retention policy
ls -dt ${PGDUMPPATH}/* | tail -n +${FILE_RETENTION} | xargs -d '\n' -r rm --

if [[ "${S3_UPLOAD_ENABLED}" == "true" ]]; then
	# upload to s3
	set +x
	mc alias set s3 "${S3_ENDPOINT}" "${S3_ACCESS_KEY}" "${S3_SECRET_KEY}" --api S3v4 || true
	set -x
	mc mb --ignore-existing "s3/${S3_BUCKET}"
	S3_FILENAME=$(basename "${DUMPFILE_GZ}")
	mc cp "${DUMPFILE_GZ}" "s3/${S3_BUCKET}/pgbackup/${S3_FILENAME}"

	# s3 retention policy
	mc rm --recursive --force --older-than "${S3_RETENTION}" "s3/${S3_BUCKET}/pgbackup/"
fi

exit 0
