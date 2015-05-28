#!/bin/bash
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

set -x
echo "Hi"
DEST=/opt/stack
TOP_DIR=$(cd $(dirname "$0") && cd .. && pwd)
echo "Devstack dir is:"$TOP_DIR

function pause(){
   read -p "Press [Enter] to continue ......"
}

source ~/devstack/stackrc
source ~/devstack/functions
source ~/devstack/functions-common

echo "$DEST"

service_name='q-l3'
process_name='neutron-l3-agent'


if is_running "$process_name"; then
        echo "yes"
else
	echo "No!"
fi

if is_service_enabled "$service_name"; then
        echo "yes"
else
	echo "No!"
fi

#stop_process "$service_name"	

#screen_stop_service "$service_name"

#NEUTRON_BIN_DIR='/usr/local/bin/'
#cfg_file_options='--config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini'

#run_process q-svc "python $NEUTRON_BIN_DIR/neutron-server $cfg_file_options"

run_process q-l3 "python /usr/local/bin/neutron-l3-agent --config-file /etc/neutron/neutron.conf --config-file=/etc/neutron/l3_agent.ini --config-file /etc/neutron/fwaas_driver.ini"


#CEILOMETER_API_LOG_DIR='/var/log/ceilometer-api'
#CEILOMETER_CONF='/etc/ceilometer/ceilometer.conf'

#run_process ceilometer-api "ceilometer-api -d -v --log-dir=$CEILOMETER_API_LOG_DIR --config-file $CEILOMETER_CONF"
