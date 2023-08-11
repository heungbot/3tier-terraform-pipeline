# 3TIER TERRAFORM PIPELINE

## [ 프로젝트 설명 ]

프로젝트 명 : 기간 한정 이벤트 쇼핑몰 서비스 구축

프로젝트 인원 : 1명

프로젝트 기간 : 2023.07 ~ 2023.08

프로젝트 소개 : 3일동안 이벤트성으로 운영되는 가상의 쇼핑몰 상황을 클라이언트로 설정하여k 이에 따른 요구사항을 정의하고 상황에 맞는 AWS Service(Cloudfront, S3, ALB, ECS, ElastiCache, Aurora)를 사용하였습니다.
또한 이들을 Terraform을 이용하여 저만의 모듈을 만들어 인프라를 코드로 정의하고 Jenkins Pipeline을 통해 Build부터 Deployment까지 자동화 하는 프로젝트 입니다

## [ 클라이언트 상황 ] 

* 이벤트 기간 동안 하루에 약 20,000명의 유저가 몰릴 것이라 예상 

* 동일 기간한정 이벤트를 주기적으로 서비스 예정

* 기존에 존재하는 물리서버들은 다른 서비스를 운영중이며 전사 데이터를 보관중

* 물리 서버의 한계를 구애받지 않고자 클라우드로 배포 결정


## [ 클라이언트 요구사항 ]

* 물리서버를 이용하지 않고, 모든 서비스를 클라우드 환경에 배포

* 안정적인 서비스를 위한 부하분산 및 고가용성 확보

* Iac를 통해 아키텍쳐 재사용성 확보 

* 하루마다 판매하는 물건의 종류가 바뀌므로, 이를 즉각 반영하는 CI/CD pipeline 구축

* DB의 고가용성 확보와 퍼포먼스 개선

* 이벤트 서비스의 관계자만 AWS Service 컨트롤 권한 부여

* 네트워크 보안 확보


## [ 구성 아키텍쳐 ]

<img width="1183" alt="3tier_pipeline_arch" src="https://github.com/heungbot/3tier-terraform-pipeline/assets/97264115/f3494ee8-e7ff-4a48-87d8-59eabc98f814">

## [ 파이프 라인 ]

<img width="1087" alt="3tier_pipeline_flow" src="https://github.com/heungbot/3tier-terraform-pipeline/assets/97264115/8e0c0018-1676-4b25-aa9c-c1d2bf0260c3">
