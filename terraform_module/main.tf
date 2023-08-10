### 1 
# base = default network config like vpc
module "heungbot-base" {
  source                 = "./heungbot-base"
  BUILD_NUMBER           = var.BUILD_NUMBER
  JENKINS_WORKSPACE_PATH = var.JENKINS_WORKSPACE_PATH
  DB_PORT                = 3306
  CACHE_PORT             = 11211
}

module "heungbot-ecr" {
  source = "./heungbot-ecr"
}

module "heungbot-iam" {
  source = "./heungbot-iam"
}

### 2(FRONTEND and DB)
module "heungbot-frontend" {
  source = "./frontend-cloudfront"
  # depends_on               = [module.heungbot-base] # why?
  BUCKET_NAME       = var.BUCKET_NAME
  DOMAIN_NAME       = var.DOMAIN_NAME
  FRONTEND_DIR_PATH = var.FRONTEND_DIR_PATH
}
# s3 bucket + cloudfront 적용하는 아키택쳐임.
# 근데 OAC를 위해 terraform을 통해 apply 하면, cycle error가 발생함 -> oac에 대한 module 따로 작성하여 해결

# oac module = change bucket policy
module "heungbot-oac" {
  source              = "./frontend-oac"
  depends_on          = [module.heungbot-frontend]
  MAIN_BUCKET_ID      = module.heungbot-frontend.MAIN_BUCKET_ID
  MAIN_BUCKET_ARN     = module.heungbot-frontend.MAIN_BUCKET_ARN
  MAIN_CLOUDFRONT_ARN = module.heungbot-frontend.MAIN_DISTRIBUTION_ARN
}

module "heungbot-memcache" {
  source                     = "./heungbot-memcache"
  # depends_on                 = [module.heungbot-base]
  DB_SUBNET_GROUP_NAME       = module.heungbot-base.CACHE_SUBNET_GROUP_NAME
  AZ_MODE                    = "cross-az"
  CACHE_SG_IDS               = module.heungbot-base.CACHE_SG_IDS
  CACHE_PARAMETER_GROUP_NAME = "default.memcached1.6"
  CACHE_CLUSTER_ID           = "heungbot-cache"
  CACHE_PORT                 = var.CACHE_PORT
  CACHE_NODE_NUM             = 2
  CACHE_NODE_TYPE            = "cache.t2.micro"
}

module "heungbot-aurora" {
  source                 = "./heungbot-aurora"
  depends_on             = [module.heungbot-base]
  DB_PORT                = var.DB_PORT
  DB_SUBNET_GROUP_NAME   = module.heungbot-base.DB_SUBNET_GROUP_NAME
  DB_SG_IDS              = module.heungbot-base.DB_SG_IDS
  DB_SUBNET_IDS          = module.heungbot-base.DB_SUBNET_IDS
  MASTER_USERNAME        = var.MASTER_USERNAME
  MASTER_USER_PASSWORD   = var.MASTER_USER_PASSWORD
  PARAMETER_GROUP_FAMILY = "aurora-mysql5.7"
}


module "heungbot-backend-ecs" {
  source                    = "./backend-ecs"
  depends_on                = [module.heungbot-base, module.heungbot-ecr, module.heungbot-iam]
  BUILD_NUMBER              = var.BUILD_NUMBER
  BACKEND_IMAGE             = var.BACKEND_IMAGE
  BACKEND_CONTAINER_PORT    = var.BACKEND_CONTAINER_PORT
  BACKEND_HOST_PORT         = var.BACKEND_HOST_PORT
  PRIVATE_SUBNET_IDS        = module.heungbot-base.private_subnets_ids
  MAIN_TARGET_GROUP_ARN     = module.heungbot-base.main_target_group_arn
  BACKEND_ECS_SERVICE_SG_ID = module.heungbot-base.backend_ecs_service_sg_id
  ECR_REPOSITORY_URL        = module.heungbot-ecr.ECR_REPOSITORY_URL
  TASK_EXECUTION_ROLE_ARN   = module.heungbot-iam.TASK_EXECUTION_ROLE_ARN
  SERVICE_FILE_PATH         = var.SERVICE_FILE_PATH
}