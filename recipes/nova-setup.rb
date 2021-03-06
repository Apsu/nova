#
# Cookbook Name:: nova
# Recipe:: nova-setup
#
# Copyright 2009, Rackspace Hosting, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)

# FIXME: we need a better identifier that we want to collect
# collectd/graphite info
if get_settings_by_role("collectd-server", "roles")
  include_recipe "nova::nova-setup-monitoring"
end

# Allow for using a well known db password
if node["developer_mode"]
  node.set_unless["nova"]["db"]["password"] = "nova"
else
  node.set_unless["nova"]["db"]["password"] = secure_password
end

include_recipe "nova::nova-common"
include_recipe "mysql::client"

if Chef::Config[:solo]
  Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
else
  # Lookup mysql ip address
  mysql_server = search(:node, "roles:mysql-master AND chef_environment:#{node.chef_environment}")
  if mysql_server.length > 0
    Chef::Log.info("nova::nova-common/mysql: using search")
    db_ip_address = mysql_server[0]['mysql']['bind_address']
    db_root_password = mysql_server[0]['mysql']['server_root_password']
  else
    Chef::Log.info("nova::nova-common/mysql: NOT using search")
    db_ip_address = node['mysql']['bind_address']
    db_root_password = node['mysql']['server_root_password']
  end
end

connection_info = {:host => db_ip_address, :username => "root", :password => db_root_password}
mysql_database "create nova database" do
  connection connection_info
  database_name node["nova"]["db"]["name"]
  action :create
end

mysql_database_user node["nova"]["db"]["username"] do
  connection connection_info
  password node["nova"]["db"]["password"]
  action :create
end

mysql_database_user node["nova"]["db"]["username"] do
  connection connection_info
  password node["nova"]["db"]["password"]
  database_name node["nova"]["db"]["name"]
  host '%'
  privileges ["all"]
  action :grant
end

execute "nova-manage db sync" do
  command "nova-manage db sync"
  action :run
  not_if "nova-manage db version && test $(nova-manage db version) -gt 0"
end

node["nova"]["networks"].each do |net|
    execute "nova-manage network create --label=#{net['label']}" do
        command "nova-manage network create --multi_host='T' --label=#{net['label']} --fixed_range_v4=#{net['ipv4_cidr']} --num_networks=#{net['num_networks']} --network_size=#{net['network_size']} --bridge=#{net['bridge']} --bridge_interface=#{net['bridge_dev']} --dns1=#{net['dns1']} --dns2=#{net['dns2']}"
        action :run
        not_if "nova-manage network list | grep #{net['ipv4_cidr']}"
    end
end

if node.has_key?(:floating) and node["nova"]["network"]["floating"].has_key?(:ipv4_cidr)
  execute "nova-manage floating create" do
    command "nova-manage floating create --ip_range=#{node["nova"]["network"]["floating"]["ipv4_cidr"]}"
    action :run
    not_if "nova-manage floating list"
  end
end
