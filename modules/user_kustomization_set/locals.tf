locals {
  source_folder       = trimspace(var.source_folder)
  source_folder_files = local.source_folder == "" ? toset([]) : try(fileset(local.source_folder, "**/*.tpl"), toset([]))
  kustomization_template_files = setintersection(local.source_folder_files, toset([
    "kustomization.yaml.tpl",
    "kustomization.yml.tpl",
    "Kustomization.tpl"
  ]))
  entry_label = var.entry_key != "" ? "user_kustomizations[\"${var.entry_key}\"]" : "user_kustomization_set"
  source_folder_validation_error = (
    local.source_folder == "" ? (var.allow_empty ? "" : "${local.entry_label}.source_folder must be set, or allow_empty = true must be used for an intentional empty set.") : (
      length(local.source_folder_files) == 0 ? (var.allow_empty ? "" : "${local.entry_label}.source_folder (${jsonencode(local.source_folder)}) does not exist, is not readable, or contains no *.tpl template files. Fix the path or set allow_empty = true only for an intentional empty set.") : (
        length(local.kustomization_template_files) == 0 ? "${local.entry_label}.source_folder (${jsonencode(local.source_folder)}) must contain kustomization.yaml.tpl, kustomization.yml.tpl, or Kustomization.tpl so kubectl apply -k has a rendered entrypoint." : ""
      )
    )
  )

  source_files_sha = join("", [
    for file_path in sort(tolist(local.source_folder_files)) :
    "${file_path}:${filesha1("${local.source_folder}/${file_path}")}"
  ])

  parameters_sha           = nonsensitive(sha256(jsonencode(var.template_parameters)))
  pre_commands_string_sha  = nonsensitive(sha256(var.pre_commands_string))
  post_commands_string_sha = nonsensitive(sha256(var.post_commands_string))
  apply_options_sha        = nonsensitive(sha256(jsonencode(var.apply_options)))
  apply_options_folder     = "${dirname(var.destination_folder)}/.kube-hetzner-apply-options"
  apply_options_file       = "${local.apply_options_folder}/${basename(var.destination_folder)}.sh"
}
