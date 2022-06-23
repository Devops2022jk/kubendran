#!/bin/bash
CRITICAL=80
FATAL=90
DUMP=/tmp/diskquota_cas; rm -f ${DUMP} 2>/dev/null

for USER in dsusr_cas
do
repquota -vug /data/Projects | grep ${USER} | sed -n '1p' | awk '{print $3/$5 * 100}' | cut -f 1 -d . > ${DUMP}

for quota in $(<"$DUMP"); do

    if [ "$quota" -ge 90 ]
      then
         echo "Disk Quota Utilization is above 95% [FATAL] for ${USER} status-NOK"
    elif [ "$quota" -ge 80 ]
      then
         echo "Disk Quota Utilization is above 80% [CRITICAL] for ${USER} status-NOK"
    elif [ "$quota" -lt 80 ]
      then
         echo "Disk Quota Utilization is nominal for ${USER} status-OK"

    fi
done

done
