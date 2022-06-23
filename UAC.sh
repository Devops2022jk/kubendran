rm -rf /tmp/hc_uac_*
DATE=$(date +%Y%m%d-%H%M)
sh /opt/sdlplos/opsadmin/healthCheck.sh | egrep 'NOK|DOWN' > /tmp/hc_uac_${DATE}
if [ -s /tmp/hc_uac_${DATE} ]  ; then echo "UAC Monitoring - NOK Status"; sh /opt/sdlplos/opsadmin/healthCheck.sh; exit 99; else echo "UAC - HC Monitoring - OK"; fi
