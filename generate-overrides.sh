#!/bin/bash

set -eu

BASEDIR=$(dirname $(realpath ${BASH_SOURCE[0]}))
RELEASE=${BASEDIR}/release

logsearch_boshrelease_dir=$1
logsearch_for_cloudfoundry_dir=$2
shift

logsearch_boshrelease_dir=$(realpath ${logsearch_boshrelease_dir})
logsearch_for_cloudfoundry_dir=$(realpath ${logsearch_for_cloudfoundry_dir})

#### COPY THE INGESTOR_SYSLOG JOB ####
# We want this to be as similar to the standard logsearch ingestor_syslog job 
# as possible, so we will only make the customizations that are absolutely necessary

# Step 1: Copy the job from the original logsearch-boshrelease repo
cp -Rvf ${logsearch_boshrelease_dir}/jobs/ingestor_syslog ${RELEASE}/jobs/

# Step 2: Add extra templates and properties to the job spec
bosh interpolate ${logsearch_boshrelease_dir}/jobs/ingestor_syslog/spec \
    -o ${BASEDIR}/overrides/job-override.yml > ${RELEASE}/jobs/ingestor_syslog/spec

# Step 3: Copy all the new templates to the job
cp -Rvf ${BASEDIR}/overrides/templates/jobs/ingestor_syslog/* ${RELEASE}/jobs/ingestor_syslog/templates/

# Step 4: Inject the use of the new templates to the start script
mv ${RELEASE}/jobs/ingestor_syslog/templates/bin/ingestor_syslog ${BASEDIR}/ingestor_syslog.tmp

# Make sure that the temp file created just above is deleted when the script exits (successfully or on error or break)
trap "rm ${BASEDIR}/ingestor_syslog.tmp" EXIT

line=$(grep -ne '^/var/vcap/packages/logstash/bin/logstash' ${BASEDIR}/ingestor_syslog.tmp | cut -d ':' -f1)
head -n+$(( line - 1 )) ${BASEDIR}/ingestor_syslog.tmp > ${RELEASE}/jobs/ingestor_syslog/templates/bin/ingestor_syslog
cat >> ${RELEASE}/jobs/ingestor_syslog/templates/bin/ingestor_syslog <<'EOF'

cat ${JOB_DIR}/config/override-defaults.conf >> ${JOB_DIR}/config/logstash.conf

EOF
tail -n+${line} ${BASEDIR}/ingestor_syslog.tmp >> ${RELEASE}/jobs/ingestor_syslog/templates/bin/ingestor_syslog

### COPY THE KIBANA-AUTH-PLUGIN JOB
cp -Rvf ${logsearch_for_cloudfoundry_dir}/jobs/kibana-auth-plugin ${RELEASE}/jobs/

### COPY THE LOGSEARCH-CONFIG PACKAGE 
cp -Rvf ${logsearch_boshrelease_dir}/packages/logsearch-config ${RELEASE}/packages/
cp -Rvf ${logsearch_boshrelease_dir}/src/logsearch-config ${RELEASE}/src/
cp -Rvf ${BASEDIR}/overrides/templates/src/logsearch-config/* ${RELEASE}/src/logsearch-config/

### COPY THE KIBANA-AUTH-PLUGIN PACKAGE 
cp -Rvf ${logsearch_for_cloudfoundry_dir}/packages/kibana-auth-plugin ${RELEASE}/packages/
cp -Rvf ${logsearch_for_cloudfoundry_dir}/src/kibana-cf_authentication ${RELEASE}/src/
cp -Rvf ${BASEDIR}/overrides/templates/src/kibana-cf_authentication/* ${RELEASE}/src/kibana-cf_authentication/

### VENDOR ALL OTHER NECESSARY PACKAGES
pushd ${RELEASE}
    for package in $(bosh int jobs/ingestor_syslog/spec --path /packages | awk '{print $2}' | grep -v logsearch-config); do
        bosh vendor-package ${package} ${logsearch_boshrelease_dir}
    done

    for package in $(bosh int packages/logsearch-config/spec --path /dependencies | awk '{print $2}' | grep -v logsearch-config); do
        bosh vendor-package ${package} ${logsearch_boshrelease_dir}
    done
popd

### UPLOAD ALL BLOBS
${BASEDIR}/add-blobs.sh