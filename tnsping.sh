#!/bin/bash
#================Script to know the DBaaS Status===================

#Defining variable
command=`grep  -e ^SDL /opt/oracle/product/19.3.0/client/network/admin/tnsnames.ora | grep =$ | cut -f1 -d =`

#Main script
for i in ${command}
do
rm -rf /tmp/dblog${i}
tnsping ${i}|grep OK > /tmp/dblog${i}
if [ -s /tmp/dblog${i} ]; then echo "${i}: DBaaS is reachable"; else echo "${i}: DBaaS is not reachable";fi
done
