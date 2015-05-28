The easy way to do everything in one go:
./csr1kv_install_all.sh neutron ovs <full_devstack_dir_path/localrc> <mysql_user> <mysql_password> <mgmt ip address of CfgAgent>

That's it!


You can run the scripts manually in the following order:
Note that the keystone script must always be run once before
the other scripts can be used.

$ source [path to devstack directory]/openrc admin demo
$ ./setup_keystone_for_csr1kv_l3.sh neutron
$ source [path to devstack directory]/openrc quantum L3AdminTenant
$ ./setup_nova_and_glance_for_csrk1v.sh neutron ovs <full_devstack_dir_path/localrc> <mysql_user> <mysql_password>
$ ./setup_neutron_for_csr1kv.sh neutron ovs <full_devstack_dir_path/localrc>
$ sudo -E ./setup_l3cfgagent_networking.sh neutron ovs <full_devstack_dir_path/localrc> <mgmt ip of Cfg Agent>
