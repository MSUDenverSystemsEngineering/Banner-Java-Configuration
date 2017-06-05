#!/bin/bash

# This script will add servers to the Oracle Java Exception Site List.
# If the servers are already in the whitelist, it will note that in the log, then exit.
# More servers can be added to the sites array as needed.

# Get current user
CURRENTUSER=$(stat -f%Su /dev/console)

# Declare whitelist
sites=('http://prod-banner-forms.msudenver.edu:7779/forms/frmservlet?config=prod' 'http://tinb01.msudenver.edu:9001/forms/frmservlet?config=test' 'http://pwls01.msudenver.edu:37777/brm/index.jsp' 'http://vmwbxs02.msudenver.edu/appxtender/login.aspx' 'http://pjobsub.msudenver.edu:5050')

LOGGER=$(/usr/bin/which echo)
WHITELIST="/Library/Application Support/Oracle/Java/Deployment/exception.sites"
DEPLOYMENT="/Library/Application Support/Oracle/Java/Deployment/deployment.properties"
JAVASECURITY="/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Home/lib/security/java.security"

javaCheck() {
  if [[ -e "/Library/Internet Plug-Ins/JavaAppletPlugin.plugin/Contents/Info.plist" ]]; then
    ${LOGGER} "Oracle Java browser plug-in is installed."
    return 0
  else
    ${LOGGER} "Oracle Java browser plug-in is not installed."
    return 1
  fi
}

importUserExceptions() {
  if [[ -n ${CURRENTUSER} ]] && [[ ${CURRENTUSER} != 'root' ]]; then
    if [[ -n $HOME ]] && [[ -e $HOME"/Library/Application Support/Oracle/Java/Deployment/security/exception.sites" ]]; then
      ${LOGGER} "User exception site list detected. Adding user exceptions to the system exception site list."
      while read site; do
        sites+=("$site")
      done < <(/bin/cat $HOME"/Library/Application Support/Oracle/Java/Deployment/security/exception.sites" | /usr/bin/awk '{ print $1 }')
      /bin/rm -f $HOME"/Library/Application Support/Oracle/Java/Deployment/security/exception.sites"
    else
      ${LOGGER} "No user exception site list detected."
    fi
  else
    ${LOGGER} "No logged in users detected."
  fi
}

addExceptions() {
  importUserExceptions
  for i in "${sites[@]}"
  do
    if [[ $(grep -Fx "$i" /Library/Application\ Support/Oracle/Java/Deployment/exception.sites) ]]; then
      # Site settings are present
      ${LOGGER} "${i} is part of the Oracle Java exception site list. Nothing to do here."
    else
      # Add site to exception.sites file
      /bin/echo "${i}" >> "$WHITELIST"
      ${LOGGER} "${i} has been added to the Oracle Java exception site list."
    fi
  done
}

configureExceptionList() {
  ${LOGGER} "Setting permissions on the system exception site list to allow user entries."
  /bin/chmod 777 /Library/Application\ Support/Oracle/Java/Deployment/exception.sites
  ${LOGGER} "Setting the path to the user exception site list."
  if [[ $(grep -Fx "deployment.user.security.exception.sites=/Library/Application Support/Oracle/Java/Deployment/exception.sites" "$DEPLOYMENT") ]]; then
    ${LOGGER} "The exception site list has already been configured."
  else
    /bin/echo deployment.user.security.exception.sites=/Library/Application\ Support/Oracle/Java/Deployment/exception.sites >> "$DEPLOYMENT"
  fi
}

setSystemExceptions(){
  if [[ ! -f "$WHITELIST" ]]; then
    ${LOGGER} "Oracle Java exception site list not found. Creating it now."
    # Create exception.sites file
    touch  "$WHITELIST"
  else
    ${LOGGER} "Oracle Java exception site list found."
  fi
  # Add needed servers to exception.sites file
  addExceptions
  # Set exception.sites location and permissions
  configureExceptionList
}

setSecurity() {
  if [[ $(grep -F "jdk.jar.disabledAlgorithms=MD2, MD5" "$JAVASECURITY") ]]; then
    ${LOGGER} "Eliminating weak signature prompt."
    /usr/bin/sed -i.bak 's/jdk.jar.disabledAlgorithms=MD2, MD5/jdk.jar.disabledAlgorithms=MD2/' "$JAVASECURITY"
  else
    ${LOGGER} "Security settings for the Java plug-in are already configured."
  fi
}

if javaCheck; then
  setSystemExceptions
  setSecurity
fi

exit 0
