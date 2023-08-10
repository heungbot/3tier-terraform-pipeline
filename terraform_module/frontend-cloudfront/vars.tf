variable "DOMAIN_NAME" {
  type        = string
  description = "The domain name for the website."
}

variable "BUCKET_NAME" {}

variable "FRONTEND_DIR_PATH" {}

# variable "MAIN_INDEX_HTML_PATH" {}

variable "BUCKET_ORIGIN_GROUP_ID" {
  type    = string
  default = "heungbot-origin-group-id"
}

variable "FRONTEND_TAG" {
  type = map(string)
  default = {
    Name = "Frontend"
    env  = "prod"
  }
}