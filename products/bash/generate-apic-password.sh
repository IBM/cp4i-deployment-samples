#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

function maxRepeatingChars() {
  PASSWORD=${1}

  previousCharacter=${PASSWORD:0:1}
  repeatCount=1
  maxRepeatCount=1

  for (( i=1; i<${#PASSWORD}; i++ )); do
    character=${PASSWORD:$i:1}
    if [[ "$character" == "${previousCharacter}" ]]; then
      ((repeatCount=repeatCount+1))
      if [ "$repeatCount" -gt "$maxRepeatCount" ]; then
        maxRepeatCount=$repeatCount
      fi
    else
      repeatCount=1
    fi
    previousCharacter=$character
  done

  echo "$maxRepeatCount"
}

function validateAPICPassword() {
  PASSWORD=${1}
  if [ "${#PASSWORD}" -lt "8" ]; then
    echo "false: Too short"
    return
  fi
  characterTypeCount=0
  if [[ "$PASSWORD" =~ [[:lower:]] ]]; then
    ((characterTypeCount=characterTypeCount+1))
  fi
  if [[ "$PASSWORD" =~ [[:upper:]] ]]; then
    ((characterTypeCount=characterTypeCount+1))
  fi
  if [[ "$PASSWORD" =~ [0-9] ]]; then
    ((characterTypeCount=characterTypeCount+1))
  fi
  if [ "$characterTypeCount" -lt "2" ]; then
    echo "false: Not enough character types"
    return
  fi
  if [ "$(maxRepeatingChars $PASSWORD)" -ge "3" ]; then
    echo "false: Too many repeating characters"
    return
  fi

  echo "true"
}

function generateAPICPassword() {
  valid="false"
  until [ "$valid" == "true" ]; do
    APIC_PASSWORD=$(
      LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
      echo
    )
    valid=$(validateAPICPassword $APIC_PASSWORD)
  done
  echo $APIC_PASSWORD
}
