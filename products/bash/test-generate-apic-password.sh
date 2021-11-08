#!/bin/bash
#******************************************************************************
# Licensed Materials - Property of IBM
# (c) Copyright IBM Corporation 2020. All Rights Reserved.
#
# Note to U.S. Government Users Restricted Rights:
# Use, duplication or disclosure restricted by GSA ADP Schedule
# Contract with IBM Corp.
#******************************************************************************

source $(dirname $0)/generate-apic-password.sh

testPasswords="Ug0k6662TjhRslLA abc ABC 0123 aB0123456789 aBCDEFGH a0123456789 B0123456789 Azzzzzzzzzz AAAAAAAz ABCDEFGHIJ"
for testPassword in $testPasswords
do
  echo "---"
  echo "testPassword: $testPassword"
  echo "Length: ${#testPassword}"
  echo "Max repeating characters: $(maxRepeatingChars $testPassword)"
  echo "Password valid: $(validateAPICPassword $testPassword)"
done

echo "---"
echo "Old password generation"
invalidCount=0
for i in $(seq 1 100000); do
  APIC_PASSWORD=$(
    LC_ALL=C tr -dc 'A-Za-z0-9' </dev/urandom | head -c 16
    echo
  )
  valid=$(validateAPICPassword $APIC_PASSWORD)
  if [ "$valid" != "true" ]; then
    ((invalidCount=invalidCount+1))
    echo "$i: Password: $APIC_PASSWORD, valid: $(validateAPICPassword $APIC_PASSWORD)"
  fi
done
echo "Invalid count: ${invalidCount}"

echo "---"
echo "New password generation"
invalidCount=0
for i in $(seq 1 100000); do
  APIC_PASSWORD=$(generateAPICPassword)
  valid=$(validateAPICPassword $APIC_PASSWORD)
  if [ "$valid" != "true" ]; then
    ((invalidCount=invalidCount+1))
    echo "$i: Password: $APIC_PASSWORD, valid: $(validateAPICPassword $APIC_PASSWORD)"
  fi
done
echo "Invalid count: ${invalidCount}"
