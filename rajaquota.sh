#!/bin/bash

#Custom made script to check the disk quota used by particular user. 
#This scipt is intended to be added in NagiosXI to capture the exit code and take action as per the exit code
#Exit states are OK (0), WARN (1) and CRIT (2)

TFILE=/tmp/val
USER=username
CHECK=`repquota -a | grep ${USER} | awk '{print $3/$5 * 100}' | awk '{printf("%d\n",$1 + 0.5)}'`

rm ${TFILE}

if (( ${CHECK} < 80 ));
then
echo "`quota ${USER} | sed -n '4p' | awk '{print $1}'` * 512 /1024/1024" | bc > ${TFILE}
echo -e "OK: \c"; echo -e "Current Utilization quota of ${USER}: `cat ${TFILE}` MB";
exit 0
elif (( ${CHECK} < 90 ));
#Line added
#erefsdd
then
echo "`quota ${USER} | sed -n '4p' | awk '{print $1}'` * 512 /1024/1024" | bc > ${TFILE}
echo -e "WARN: \c"; echo -e "Current Utilization quota of ${USER}: `cat ${TFILE}` MB";
exit 1
#Additionale LIne
else
echo "`quota ${USER} | sed -n '4p' | awk '{print $1}'` * 512 /1024/1024" | bc > ${TFILE}
echo -e "CRIT: \c"; echo -e "Current Utilization quota of ${USER}: `cat ${TFILE}` MB";
exit 2
fi
