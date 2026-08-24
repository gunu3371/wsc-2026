output "workload_names" { value = sort(keys(local.input.additional_workloads)) }
output "routes" {
  value = { for name, workload in local.input.additional_workloads : name => workload.route_path }
}
