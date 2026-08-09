variable "candidate_id" {
  description = "BIBUNHO used verbatim in skills-book-static-2026-<BIBUNHO>."
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.candidate_id))
    error_message = "candidate_id may contain letters, numbers and hyphens only."
  }
}
variable "origin_verify_secret" {
  type      = string
  sensitive = true
  validation {
    condition     = length(var.origin_verify_secret) >= 20
    error_message = "origin_verify_secret must be at least 20 characters."
  }
}
variable "image_uri" {
  description = "Optional immutable image URI. Null selects skills-book-ecr:latest."
  type        = string
  default     = null
}
variable "force_destroy" {
  type    = bool
  default = false
}
