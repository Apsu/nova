#
# Cookbook nova:volume
# Recipe:: default
#

include_recipe "nova::nova-common"
include_recipe "nova::api-os-volume"

platform_options = node["nova"]["platform"]

package "python-keystone" do
  action :upgrade
end

platform_options["nova_volume_packages"].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options["package_overrides"]
  end
end

service "nova-volume" do
  service_name platform_options["nova_volume_service"]
  supports :status => true, :restart => true
  action :disable
  subscribes :restart, resources(:template => "/etc/nova/nova.conf"), :delayed
end

ks_admin_endpoint = get_access_endpoint("keystone", "keystone", "admin-api")
ks_service_endpoint = get_access_endpoint("keystone", "keystone", "service-api")
keystone = get_settings_by_role("keystone","keystone")
volume_endpoint = get_access_endpoint("nova-volume", "nova", "volume")

# Register Volume Service
keystone_register "Register Volume Service" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_name "Volume Service"
  service_type "volume"
  service_description "Nova Volume Service"
  action :create_service
end

# Register Image Endpoint
keystone_register "Register Volume Endpoint" do
  auth_host ks_admin_endpoint["host"]
  auth_port ks_admin_endpoint["port"]
  auth_protocol ks_admin_endpoint["scheme"]
  api_ver ks_admin_endpoint["path"]
  auth_token keystone["admin_token"]
  service_type "volume"
  endpoint_region "RegionOne"
  endpoint_adminurl volume_endpoint["uri"]
  endpoint_internalurl volume_endpoint["uri"]
  endpoint_publicurl volume_endpoint["uri"]
  action :create_endpoint
end

# TODO(shep): this needs to be if blocked on env collectd toggle
# Include recipe(nova::volume-monitoring)
include_recipe "nova::volume-monitoring"
