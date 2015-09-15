#!/bin/bash
#export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
#set -x

# Change Log
# 28th May: Changes made for using networking-cisco as base repo instead of
#           neutron

NET_CISCO_REPO=networking-cisco
DEST=/opt/stack
TOP_DIR=/home/stack/devstack
echo "Devstack dir is:"$TOP_DIR


function pause(){
   read -p "Press [Enter] to continue ......"
}

source ${TOP_DIR}/functions-common
source ${TOP_DIR}/localrc
source ${TOP_DIR}/stackrc
source ${TOP_DIR}/functions
source ${TOP_DIR}/lib/tls
source ${TOP_DIR}/lib/nova
source ${TOP_DIR}/lib/neutron-legacy

function start_n_cpu(){
	echo "[Debug]NOVA_BIN_DIR:${NOVA_BIN_DIR}"
	local compute_cell_conf=$NOVA_CONF
	echo "[Debug]config file:${compute_cell_conf}"
	echo "[Debug]Libvirt_group:${LIBVIRT_GROUP}"
	echo "[Debug]Command: run_process n-cpu ${NOVA_BIN_DIR}/nova-compute --config-file ${compute_cell_conf} ${LIBVIRT_GROUP}"
	run_process n-cpu "${NOVA_BIN_DIR}/nova-compute --config-file ${compute_cell_conf}" ${LIBVIRT_GROUP}

}

function start_q_svc(){
	echo "[Debug]NEUTRON_BIN_DIR:${NEUTRON_BIN_DIR}"
	if [[ "$Q_PLUGIN" = 'ml2' ]]; then
		local cfg_file_options="--config-file /etc/neutron/neutron.conf --config-file /etc/neutron/plugins/ml2/ml2_conf.ini --config-file ${DEST}/${NET_CISCO_REPO}/etc/neutron/plugins/cisco/cisco_router_plugin.ini"
	else
		echo "Q_PLUGIN is not ML2. You should run this script only with ML2 plugin"
		exit
	fi
	echo "[Debug]cfg_file_options:${cfg_file_options}"
	echo "[Debug]Command: #run_process q-svc python $NEUTRON_BIN_DIR/neutron-server $cfg_file_options"
	run_process q-svc "python $NEUTRON_BIN_DIR/neutron-server $cfg_file_options"

}

function start_q_cfg(){
	local cfg_options="--config-file /etc/neutron/neutron.conf --config-file ${DEST}/${NET_CISCO_REPO}/etc/neutron/plugins/cisco/cisco_cfg_agent.ini"
	echo "[Debug]Command: #run_process q-cfg-agent python $NEUTRON_BIN_DIR/neutron-cisco-cfg-agent ${cfg_options}"
	screen_process q-cfg-agent "python $NEUTRON_BIN_DIR/neutron-cisco-cfg-agent ${cfg_options}"
}

function get_git_current_branch(){
	br_name="$(git symbolic-ref HEAD 2>/dev/null)" || br_name="(unnamed branch)"     # detached HEAD
	local branch_name=${br_name##refs/heads/}
	echo ${branch_name}
}

function is_remote_set(){
	local remote=$(git remote -v | grep "https://github.com/CiscoSystems/neutron.git")
	if [[ -z $remote ]]; then
		echo "remote is not set!"
		return 1
	fi
	return 0
}

function is_local_branch_present(){
	local branch_name=$1
	local res=$(git show-ref --verify --quiet refs/heads/harp/${branch_name})
	echo $res
}

function set_and_update_neutron_branch(){
	local target_br_name=$1
	cd $DEST/neutron
	local branch_name=$(get_git_current_branch)
	#echo "[Debug]Current branch is ${branch_name}"
	if [[ "$branch_name" = "master" ]]; then
		if is_remote_set; then
			git fetch cisco ${target_br_name}
			if is_local_branch_present ${target_br_name}; then
				echo "[Debug] Deleting local branch:${target_br_name}"
				git branch -D ${target_br_name}
			fi
			echo "[Debug] Checking out updated branch:${target_br_name}"
			git checkout ${target_br_name}
		else
			echo "Remote cisco is not set!"
		fi
	else
		echo "You didn't reclone. Update the hotplug branch manually before proceeding"
	fi
	cd -
}

function remove_neutron_router(){
	source $TOP_DIR/openrc demo demo
	neutron router-interface-delete router1 private-subnet
        neutron router-interface-delete router1 ipv6-private-subnet
	neutron router-delete router1
}

function edit_config_files(){
	echo "Changing Neutron service plugin settings........"
	if is_service_enabled q-fwaas; then
		echo "Firewall plugin is enabled"
		ed -i "s/^service_plugins = neutron.services.l3_router.l3_router_plugin.L3RouterPlugin,neutron_fwaas.services.firewall.fwaas_plugin.FirewallPlugin/service_plugins = neutron.plugins.cisco.service_plugins.cisco_router_plugin.CiscoRouterPlugin/" /etc/neutron/neutron.conf
	else
		echo "Only router plugin is enabled"
		sed -i "s/^service_plugins = neutron.services.l3_router.l3_router_plugin.L3RouterPlugin/service_plugins = networking_cisco.plugins.cisco.service_plugins.cisco_router_plugin.CiscoRouterPlugin/" /etc/neutron/neutron.conf
	fi
		echo "[Post Config] Configured service plugins are:"
		grep service_plugins /etc/neutron/neutron.conf -m 1
	echo "Changing Nova vif settings"
	sed -i "s/^vif_plugging_is_fatal = True/vif_plugging_is_fatal = False/" /etc/nova/nova.conf
	sed -i "s/^vif_plugging_timeout = 300/vif_plugging_timeout = 3/" /etc/nova/nova.conf
	echo "[Post Config] VIF plugging configs in Nova.conf:"
	grep vif_plugging /etc/nova/nova.conf
}

function stop_screen_process(){
	screen_names=(n-cpu q-svc q-l3)
	# Change names neutron-cisco-cfg-agent to neutron-l3-agent
	process_names=(nova-compute neutron-server neutron-l3-agent)
	for (( i=0; i<${#screen_names[@]}; i++ )); do
		echo -n "Check service ${screen_names[$i]} is enabled:"
		if is_service_enabled ${screen_names[$i]}; then
        	echo "yes"
        	echo -n " - Check process ${process_names[$i]} is running:"
			if is_running ${process_names[$i]}; then
        		echo "yes"
        		echo "Terminating screen process ${screen_names[$i]}"
        		screen_stop_service "${screen_names[$i]}"
			else
				echo "No!"
			fi
		else
			echo "No!"
		fi
	done
}

function start_screen_process(){
	start_n_cpu
	start_q_svc
	start_q_cfg
}

########## Main process ###########

echo "Removing namespace router elements"
remove_neutron_router
pause
echo "Stage 1: Stop relevant screen process"
stop_screen_process
pause
echo "Stage 2: Editing config files"
edit_config_files
pause
echo "Stage 3: Start relevant screen process"
start_screen_process

echo " "
echo "-------Almost done---------"
echo "Complete the installation process by running the following:"
echo "./csr1kv_install_all.sh neutron ovs /home/stack/devstack/localrc root lab 10.0.100.2"
