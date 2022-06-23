#!/bin/bash



######################################################################################################
#Global Variable Declarations

TS=$(date +%Y%m%d-%H%M)
if [ ! -d /opt/sdlplos/log/hc ]; then mkdir -p /opt/sdlplos/log/hc ; fi;
LOGFILE=/opt/sdlplos/log/hc/hc_${TS};
HOSTNAME=$(hostname)
CRIT=90
WARN=80
engdt=`ps -ef|grep dsrpcd|grep -v grep|awk {'print $5'}`;
engpt=/opt/IBM/InformationServer/Server/DSODB/bin
if [ -f /opt/IBM/InformationServer/Version.xml ]; then
nEngAlias=`grep isf.agent.host /opt/IBM/InformationServer/Version.xml | sed -e 's/.*value="//' -e 's/"..//' | cut -d. -f1`
nEng=`hostname | cut -d'.' -f1`
nSerAlias=`grep isf.server.host /opt/IBM/InformationServer/Version.xml | sed 's/.*value="//' | sed 's/"\/>//'`
nSer=`nslookup $nSerAlias | grep Name | awk '{print $2}' | cut -d'.' -f1`; fi



######################################################################################################
#My Custom Functions

fn_fmt_lines ()
{
echo "..................................... $@ ......................................................"
}

fn_fmt_break()
{
echo "######################################## $@ ####################################################"
}

######################################################################################################
#Declaring IIS Main Functions



#########################
#Defining HOSTTYPE
fn_hosttype()
{
if [ -d /opt/IBM/InformationServer/Server/DSEngine/ ] && [ -d /opt/IBM/InformationServer/ASBNode ]; then HOSTTYPE=EngineTier;
elif [ -d /opt/IBM/WebSphere/AppServer/ ] && [ -d /opt/IBM/InformationServer/ASBServer/ ]; then HOSTTYPE=ServiceTier;
elif [ -d /opt/IBM/InformationServer/ ] && [ ! -d /data/xfb ] && [ -d /etc/docker ] ; then HOSTTYPE=MicroServices;
elif [ ! -d /opt/IBM/InformationServer/ ] && [ -d /data/xfb ]; then HOSTTYPE=LandingZone; fi;
}


#########################
fn_iis_ET()
{
nRepoAlias=` sudo $engpt/DSAppWatcher.sh -test|grep ServiceName|awk -F= {'print $2'};`
nRepo=`nslookup $nRepoAlias | grep Name | awk '{print $2}' | cut -d'.' -f1`
fn_fmt_break IIS Engine Tier Checks
#Validating Engine Tier Services
if [ `ps -ef|grep dsrpcd|grep -v grep | wc -l` -eq 1 ]; then echo "Datastage Engine Process: OK: RUNNING since : ${engdt}"; else "NOK: Datastage Engine Process DOWN"; fi;
echo "Number of Client Sessions: `ps -ef|grep dsapi_slave|grep -v grep|wc -l`";

#Validating Service Tier Services
curl --connect-timeout 30 --max-time 60 https://${nSer}.ic.ing.net:9445/ibm/iis/ds/console/ -k -s -f -o /dev/null && echo "WAS Application Server: OK: UP & RUNNING" || echo "WAS Application Server: NOK: DOWN";

#Validating IIS Agents
fn_fmt_lines Status of IIS Engine Agents
if [ `ps -ef|grep DSWLM|grep -v grep | wc -l` -eq 1 ]; then echo "WLM Server:RUNNING";else echo "WLM Server DOWN"; fi;
if [ `ps -ef|grep AgentImpl|grep -v grep | wc -l` -eq 1 ]; then echo "ASB Agent:RUNNING";else echo "ASB Agent DOWN"; fi;
if [ `ps -ef|grep JobMonApp|grep -v grep | wc -l` -eq 1 ]; then echo "JobMonApp:RUNNING";else echo "JobMonApp DOWN"; fi;
sudo $engpt/DSAppWatcher.sh -status; echo " ";
}

fn_iis_ST ()
{
fn_fmt_break WAS URL Check
echo "" | tee -a ${LOGFILE};
curl --connect-timeout 30 --max-time 60 https://${nSer}.ic.ing.net:9445/ibm/iis/ds/console/ -k -s -f -o /dev/null && echo "WAS Application Server: OK: UP & RUNNING" || echo "WAS Application Server: NOK: DOWN";
echo "" | tee -a ${LOGFILE};
fn_fmt_lines ISFServer Status | tee -a ${LOGFILE};
echo "" | tee -a ${LOGFILE};
/bin/systemctl status ISFServer | tee -a ${LOGFILE};
}

######################################################################################################
#Declaring Linux Main Functions

########################## Load Average #########################
fn_lin_load () {
fn_fmt_break LINUX CHECKS | tee -a ${LOGFILE}
fn_fmt_lines CPU Load Average >> ${LOGFILE}
uptime >> ${LOGFILE}; echo "" >> ${LOGFILE}
uptime | sed 's/.*users,//' | sed 's/  load average/Load Average/'
}

########################## CPU Utilizaion #########################
fn_lin_cpu () {
fn_fmt_lines CPU Utilization >> ${LOGFILE}
echo "`sar 1 2`" >> $LOGFILE; echo "" >> $LOGFILE
IDEAL=`sar 1 2 | grep -i average | awk '{print $8}' | awk -F. '{print $1}'`
if [ "$IDEAL"  -le 10 ]; then
echo "CPU Utilization: NOK - Status: CRIT - `expr 100 - ${IDEAL}`% utilized"; sar 1 2;
elif [ "$IDEAL" -le 20 ]; then echo "CPU Utilization: NOK - Status: WARN - `expr 100 - ${IDEAL}`% utilized"; sar 1 2;
else echo "CPU Utilization: OK : `expr 100 - ${IDEAL}`% utilized"; fi; echo "" >> $LOGFILE
}

########################## Disk Usage #########################
fn_lin_disk () {
#Declaring Local Variables
DUMP=/tmp/hc_lin_disk_out.tmp; rm -f ${DUMP} 2>/dev/null;
fn_fmt_lines Linux File System Check >> ${LOGFILE}
echo "`df -h`" >> ${LOGFILE}; echo "" >> ${LOGFILE}
df -Ph | awk '+$5>=79 {print}' | awk '{print $5 echo " " $6}'> ${DUMP}
if [ -s ${DUMP} ]; then echo "Disk Utilization : NOK"; echo ""; cat ${DUMP}; echo ""; else echo "Disk Utilizaion: OK"; fi;
}

############################# Memory Usage ######################

fn_lin_mem () {
fn_fmt_lines MEMORY USAGE CHECK >> ${LOGFILE}
echo "`free -h | grep -iE "total|mem"`" >> ${LOGFILE}; echo "" >> $LOGFILE
memory=`free | grep -i mem | awk '{print $3/$2 * 100}' | awk -F. '{print $1}'`;
if [ $memory -ge $CRIT ]; then echo "Memory Utilizaion : NOK - Status: CRIT - ${memory} utilized"; echo ""; free -h; echo "";
elif [ $memory -ge $WARN ]; then echo "Memory Utilizaion : NOK - Status: WARN - ${memory} utilized"; echo ""; free -h; echo "";
else echo "Memory Utilization: OK - ${memory}% utilized"; fi
}

############################## Swap Space Usage ##########################

fn_lin_swap () {
fn_fmt_lines SWAP USAGE CHECK >> ${LOGFILE}
echo "`free -h | grep -iE "total|swap"`" >> ${LOGFILE}; echo "" >> $LOGFILE
zeroChk=`free | grep -i swap | awk '{print $3}'`;
if [ $zeroChk == 0 ]; then echo "Swap Utilization: NA - No Swap Allocated on this server" | tee -a ${LOGFILE};
else swap=`free | grep -i swap | awk '{print $3/$2 * 100}' | awk -F. '{print $1}'`
if [ ${swap} -ge ${CRIT} ]; then echo "Swap Utilizaion : NOK - Status : CRIT - ${swap}% utilized"; echo ""; free -h | grep -iE "total|swap"; echo "":
elif [ ${swap} -ge ${WARN} ]; then echo "Swap Utilizaion : NOK - Status : WARN - ${swap}% utilized"; echo ""; free -h | grep -iE "total|swap"; echo "":
else echo "Swap Utilizaion : OK - ${swap}% utilized"; fi; fi;
}

############################### Checking Pods Status in MicroService Tire ########################

fn_lin_podstatus () {
fn_fmt_lines PODS STATUS CHECK
echo " ";
if [ -d /opt/IBM/InformationServer/ ] && [ ! -d /data/xfb ] && [ -d /etc/docker ]
then
 kubectl get pods | sed 1d | awk '{print $3}' | grep -vE "Completed|Running" &>/dev/null
if [ $? -eq 1 ]
then
 echo "Micro service tire pods status  = OK"
else
 echo "Micro service tire pods status  = NOK"; echo " ";
 kubectl get pods | grep -vE "Completed|Running" | tee ${LOGFILE}
fi
else
echo "This is Not MicroService Tire = pods status not found"
fi
}


###################################### Finding Zombie Process Status #######################################

fn_lin_zombieprocess () {
fn_fmt_lines PS COMMAND OUTPUT >> ${LOGFILE}
ps -elf >> ${LOGFILE}
ps -elf | sed 1d | awk '{ print $2 }' | grep "Z" &>/dev/null
if [ $? -eq 1 ]
then
  echo "Zombie Process status : OK"
else
  echo "Zombie Process status : NOK"
fi
}

########################################### Inode Utilization ##########################################

fn_lin_inode () {
#Declaring Local Variables
DUMP=/tmp/hc_lin_disk_out.tmp; rm -f ${DUMP} 2>/dev/null;
fn_fmt_lines Linux File System Inode Check >> ${LOGFILE}
echo "`df -ih`" >> ${LOGFILE}; echo "" >> ${LOGFILE}
df -ih | sed 1d | grep -v tmpfs | awk 'BEGIN{OFS=":"} {gsub(/\%/, " ", $5)} 1' | awk -v u=79 'BEGIN {FS=":";OFS="\t"} {if($5>u)print $6,$5}' > ${DUMP}
if [ -s ${DUMP} ]; then echo "Inode Utilization : NOK"; echo ""; cat ${DUMP}; echo ""; else echo "Inode Utilizaion: OK"; fi;
}


############################################# kafkaconnector status #################################

fn_lin_kafa () {

`rm -f /tmp/kafka_log`
for i in TE XD CAS
do
/opt/Features/${i}_Collection/F0055/v00003/bin/manageworker.sh status| grep -E "error|not" >> /tmp/kafka_log
done
if [ -s /tmp/lzlog ]; then echo "Kafka connector status: NOK"; else echo "Kafka connector status: OK";fi

}

fn_lin_all()
{
echo "";
fn_lin_load
fn_lin_cpu
fn_lin_mem
fn_lin_swap
fn_lin_disk
#fn_lin_zombieprocess
fn_lin_inode
echo "";
}


######################################################################################################
#Declaring DB Main Functions

fn_db_repo ()
{
nRepoAlias=` sudo $engpt/DSAppWatcher.sh -test|grep ServiceName|awk -F= {'print $2'};`;
nRepo=`nslookup $nRepoAlias | grep Name | awk '{print $2}' | cut -d'.' -f1`;
#Validating Repo Tier Services
fn_fmt_break REPO TIER Status
echo ""; if [ ` sudo $engpt/DSAppWatcher.sh -test|grep "Successfully connected" |wc -l` -eq 1 ]; then echo "XMeta/DSODB DB: OK: UP & RUNNING"; else "XMeta/DSODB DB: NOK: DOWN"; fi; echo "";
}

fn_db_dwh_tnscheck ()
{
fn_fmt_break DWH TNS Status | tee -a ${LOGFILE};
echo ""; awk -F"[=]" '/DESCRIPTION/ { print X }{ X=$1 }' /opt/oracle/product/19.3.0/client/network/admin/tnsnames.ora | grep -v ^# | grep SDL | egrep "DEV|TEST|ACC|PROD" | while read NAME; do OUT=`/opt/oracle/product/19.3.0/client/bin/tnsping $NAME |tail -1`; echo "TNSPING status of ${NAME} is : ${OUT}"; done; echo "";
}


############################################
# Declaring Main Functions
fn_main()
{
fn_hosttype;
echo ""; fn_fmt_break;
echo ""; echo "This script on \"${HOSTNAME}\" and it is identified as \"${HOSTTYPE}\""; echo "";
fn_lin_all
case ${HOSTTYPE} in
EngineTier) fn_iis_ET | tee -a ${LOGFILE}; fn_db_repo | tee -a ${LOGFILE}; fn_db_dwh_tnscheck | tee -a ${LOGFILE};;
ServiceTier) fn_iis_ST;;
MicroServices) fn_lin_podstatus;;
#LandingZone) echo "No functions are defined for Landing Zone" >> ${LOGFILE};;
LandingZone) fn_lin_kafa;;
esac;
echo ""; fn_fmt_break; echo ""; echo "Logs are saved on ${LOGFILE}"; echo "";
}

#Script Execution
fn_main
