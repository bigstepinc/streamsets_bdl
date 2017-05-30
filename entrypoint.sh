#!/bin/bash
set -e

# We translate environment variables to sdc.properties and rewrite them.
set_conf() {
  if [ $# -ne 2 ]; then
    echo "set_conf requires two arguments: <key> <value>"
    exit 1
  fi

  if [ -z "$SDC_CONF" ]; then
    echo "SDC_CONF is not set."
    exit 1
  fi

  sed -i 's|^#\?\('"$1"'=\).*|\1'"$2"'|' "${SDC_CONF}/sdc.properties"
}

# In some environments such as Marathon $HOST and $PORT0 can be used to
# determine the correct external URL to reach SDC.
if [ ! -z "$HOST" ] && [ ! -z "$PORT0" ] && [ -z "$SDC_CONF_SDC_BASE_HTTP_URL" ]; then
  export SDC_CONF_SDC_BASE_HTTP_URL="http://${HOST}:${PORT0}"
fi

for e in $(env); do
  key=${e%=*}
  value=${e#*=}
  if [[ $key == SDC_CONF_* ]]; then
    lowercase=$(echo $key | tr '[:upper:]' '[:lower:]')
    key=$(echo ${lowercase#*sdc_conf_} | sed 's|_|.|g')
    set_conf $key $value
  fi
done

chmod -R 777 "${SDC_CONF}"

if [ "$ADMIN_PASSWORD" != "" ]; then
  pass=$(echo -n "$ADMIN_PASSWORD"| md5sum | cut -d ' ' -f 1)
  sed "s/admin:   MD5:.*,/admin:   MD5:$pass,/" "${SDC_CONF}/basic-realm.properties" >> "${SDC_CONF}/basic-realm.properties.tmp" && \
  mv "${SDC_CONF}/basic-realm.properties.tmp" "${SDC_CONF}/basic-realm.properties"
  
  sed "s/admin:   MD5:.*,/admin:   MD5:$pass,/" "${SDC_CONF}/digest-realm.properties" >> "${SDC_CONF}/digest-realm.properties.tmp" && \
  mv "${SDC_CONF}/digest-realm.properties.tmp" "${SDC_CONF}/digest-realm.properties"
  
  sed "s/admin:   MD5:.*,/admin:   MD5:$pass,/" "${SDC_CONF}/form-realm.properties" >> "${SDC_CONF}/form-realm.properties.tmp" && \
  mv "${SDC_CONF}/form-realm.properties.tmp" "${SDC_CONF}/form-realm.properties"
  
  sed "s/http.realm.file.permission.check=true/http.realm.file.permission.check=false/" "${SDC_CONF}/sdc.properties" >> "${SDC_CONF}/sdc.properties.tmp" && \
  mv "${SDC_CONF}/sdc.properties.tmp" "${SDC_CONF}/sdc.properties"
  
fi

${SDC_DIST}/bin/streamsets dc
