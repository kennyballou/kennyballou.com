[+ autogen5 template -*- mode: json -*- +]
{
    "AWSTemplateFormatVersion": "2010-09-09",
    "Description": "Blog of kennyballou.com",
    "Parameters": {
        "DomainName": {
            "Description": "Domain name of site",
            "Type": "String",
            "Default": "kennyballou.com"
        },
        "BlogBucketName": {
            "Description": "Name of S3 Bucket",
            "Type": "String",
            "Default": "blog.kennyballou.com"
        },
        "CloudFrontHostedZone": {
            "Description": "CloudFront Hosted Zone ID",
            "Type": "String",
            "Default": "Z2FDTNDATAQYW2"
        }
    },
    "Resources": {
        "HostedZone": {
            "Type": "AWS::Route53::HostedZone",
            "Properties": {
                "Name": {"Ref": "DomainName"}
            }
        },
        "BlogContentBucket": {
            "Type": "AWS::S3::Bucket",
            "Properties": {
                "AccessControl": "Private",
                "BucketName": {"Ref": "BlogBucketName"},
                "LifecycleConfiguration": {
                    "Rules": [
                        {
                            "NoncurrentVersionExpirationInDays": 90,
                            "Status": "Enabled"
                        }
                    ]
                },
                "VersioningConfiguration": {
                    "Status": "Enabled"
                },
                "WebsiteConfiguration": {
                    "IndexDocument": "index.html",
                    "ErrorDocument": "404.html"
                }
            }
        },
        "BlogContentBucketPolicy": {
            "Type": "AWS::S3::BucketPolicy",
            "Properties": {
                "Bucket": {"Ref": "BlogContentBucket"},
                "PolicyDocument": {
                    "Statement": [
                        {
                            "Action": ["s3:GetObject"],
                            "Effect": "Allow",
                            "Resource": [
                                {"Fn::Join": ["/", [
                                    {"Fn::GetAtt": [
                                        "BlogContentBucket", "Arn"]},
                                    "*"
                                ]]}
                            ],
                            "Principal": {
                                "CanonicalUser": {"Fn::GetAtt": [
                                    "OriginAccessId",
                                    "S3CanonicalUserId"]}
                            }
                        }
                    ]
                }
            }
        },
        "SSLCertificate": {
            "Type": "AWS::CertificateManager::Certificate",
            "Properties": {
                "DomainName": {"Ref": "DomainName"}
            }
        },
        "OriginAccessId": {
            "Type": "AWS::CloudFront::CloudFrontOriginAccessIdentity",
            "Properties": {
                "CloudFrontOriginAccessIdentityConfig": {
                    "Comment": "S3 Bucket Access"
                }
            }
        },
        "CFDistribution": {
            "Type": "AWS::CloudFront::Distribution",
            "Properties": {
                "DistributionConfig": {
                    "Aliases": [
                        {"Ref": "DomainName"}
                    ],
                    "DefaultRootObject": "index.html",
                    "Enabled": true,
                    "IPV6Enabled": true,
                    "HttpVersion": "http2",
                    "DefaultCacheBehavior": {
                        "TargetOriginId": {"Fn::Join": [".", [
                            "s3",
                            {"Ref": "BlogBucketName"}]]},
                        "ViewerProtocolPolicy": "redirect-to-https",
                        "MinTTL": 0,
                        "DefaultTTL": 3600,
                        "AllowedMethods": ["HEAD", "GET"],
                        "CachedMethods": ["HEAD", "GET"],
                        "ForwardedValues": {
                            "QueryString": true,
                            "Cookies": {
                                "Forward": "none"
                            }
                        },
                        "LambdaFunctionAssociations": [
                            {
                                "EventType": "origin-request",
                                "LambdaFunctionARN": {
                                    "Ref": "URIRewriteLambdaVersion"
                                }
                            }
                        ]
                    },
                    "Origins": [
                        {
                            "S3OriginConfig": {
                                "OriginAccessIdentity": {"Fn::Join": ["/", [
                                    "origin-access-identity/cloudfront",
                                    {"Ref": "OriginAccessId"}
                                ]]}
                            },
                            "DomainName": {"Fn::Join": [".", [
                                {"Ref": "BlogBucketName"},
                                "s3.amazonaws.com"]]},
                            "Id": {"Fn::Join": [".", [
                                "s3",
                                {"Ref": "BlogBucketName"}]]}
                        }
                    ],
                    "PriceClass": "PriceClass_100",
                    "Restrictions": {
                        "GeoRestriction": {
                            "RestrictionType": "none",
                            "Locations": []
                        }
                    },
                    "ViewerCertificate": {
                        "SslSupportMethod": "sni-only",
                        "MinimumProtocolVersion": "TLSv1.2_2018",
                        "AcmCertificateArn": {"Ref": "SSLCertificate"}
                    }
                }
            }
        },
        "BlogAliasRecord": {
            "Type": "AWS::Route53::RecordSet",
            "Properties": {
                "AliasTarget": {
                    "DNSName": {"Fn::GetAtt": ["CFDistribution", "DomainName"]},
                    "HostedZoneId": {"Ref": "CloudFrontHostedZone"}
                },
                "HostedZoneId": {"Ref": "HostedZone"},
                "Name": {"Ref": "DomainName"},
                "Type": "A"
            }
        },
        "URIRewriteLambdaLogGroup": {
            "Type": "AWS::Logs::LogGroup",
            "Properties": {
                "LogGroupName": "/aws/lambda/us-east-1.blog-kennyballou-URIRewriteLambdaFunction-5MXFF1KIA87D",
                "RetentionInDays": 90
            }
        },
        "URIRewriteLambdaFunction": {
            "Type": "AWS::Lambda::Function",
            "Properties": {
                "Description": "Lambda Function performing URI rewriting",
                "Code": {
                    "ZipFile": [+ INCLUDE "uri-rewrite.in" +]
                },
                "Handler": "index.handler",
                "MemorySize": 128,
                "Role": {"Fn::GetAtt": ["URIRewriteLambdaRole", "Arn"]},
                "Runtime": "python3.7",
                "Tags": [
                    {"Key": "Domain", "Value": {"Ref": "DomainName"}}
                ]
            }
        },
        "URIRewriteLambdaRole": {
            "Type": "AWS::IAM::Role",
            "Properties": {
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Action": "sts:AssumeRole",
                            "Principal": {
                                "Service": [
                                    "edgelambda.amazonaws.com",
                                    "lambda.amazonaws.com"
                                ]
                            }
                        }
                    ]
                },
                "Policies": [
                    {
                        "PolicyName": "GrantCloudwatchLogAccess",
                        "PolicyDocument": {
                            "Version": "2012-10-17",
                            "Statement": [
                                {
                                    "Effect": "Allow",
                                    "Action": [
                                        "logs:CreateLogStream",
                                        "logs:PutLogEvents"
                                    ],
                                    "Resource": [
                                        {"Fn::GetAtt": ["URIRewriteLambdaLogGroup", "Arn"]},
                                        {"Fn::Join": ["", [
                                            {"Fn::GetAtt": ["URIRewriteLambdaLogGroup", "Arn"]},
                                            "/*"]]}
                                    ]
                                }
                            ]
                        }
                    }
                ]
            }
        },
        "URIRewriteLambdaVersion": {
            "Type": "AWS::Lambda::Version",
            "Properties": {
                "FunctionName": {"Fn::GetAtt": [
                    "URIRewriteLambdaFunction", "Arn"]},
                "Description": "Lambda Function performing URI rewriting"
            }
        },
        "BlogContentRepository": {
            "Type": "AWS::CodeCommit::Repository",
            "Properties": {
                "RepositoryDescription": "Blog Content Repository",
                "RepositoryName": {"Ref": "BlogBucketName"},
                "Triggers": [
                    {
                        "Name": "Build and Deploy",
                        "Branches": ["master"],
                        "DestinationArn": {"Ref": "CodeCommitEventsSnsTopic"},
                        "Events": ["all"]
                    }
                ]
            }
        },
        "BlogCodeBuildLogGroup": {
            "Type": "AWS::Logs::LogGroup",
            "Properties": {
                "LogGroupName": {"Fn::Join": ["-", [
                    "/aws/codebuild/CodeBuild",
                    {"Ref": "BlogBucketName"}]]},
                "RetentionInDays": 14
            }
        },
        "BlogCodeBuild": {
            "Type": "AWS::CodeBuild::Project",
            "Properties": {
                "Name": "BlogCI",
                "Description": "Blog Build Project",
                "Artifacts": {
                    "Type": "NO_ARTIFACTS"
                },
                "Environment": {
                    "ComputeType": "BUILD_GENERAL1_SMALL",
                    "Image": "kennyballou/debian-pandoc:latest",
                    "Type": "LINUX_CONTAINER"
                },
                "LogsConfig": {
                    "CloudWatchLogs": {
                        "GroupName": {"Fn::Join": ["-", [
                            "/aws/codebuild/CodeBuild",
                            {"Ref": "BlogBucketName"}
                        ]]},
                        "Status": "ENABLED"
                    }
                },
                "ServiceRole": {"Ref": "CodeBuildIamServiceRole"},
                "Source": {
                    "Type": "CODECOMMIT",
                    "Location": {"Fn::GetAtt": ["BlogContentRepository",
                                                "CloneUrlHttp"]}
                }
            }
        },
        "CodeCommitEventsSnsTopic": {
            "Type": "AWS::SNS::Topic",
            "Properties": {
                "DisplayName": "CodeCommit Events",
                "TopicName": "codecommit-events"
            }
        },
        "CodeBuildIamManagedPolicy": {
            "Type": "AWS::IAM::ManagedPolicy",
            "Properties": {
                "Description": "CodeBuild Service Policy",
                "PolicyDocument": [+ INCLUDE "codebuild-service-role.json.in" +]
            }
        },
        "CodeBuildIamServiceRole": {
            "Type": "AWS::IAM::Role",
            "Properties": {
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Action": "sts:AssumeRole",
                            "Principal": {
                                "Service": "codebuild.amazonaws.com"
                            },
                            "Effect": "Allow"
                        }
                    ]
                },
                "ManagedPolicyArns": [
                    {"Ref": "CodeBuildIamManagedPolicy"}
                ]
            }
        },
        "LambdaCodeCommitBuildIamManagedPolicy": {
            "Type": "AWS::IAM::ManagedPolicy",
            "Properties": {
                "Description": "Lambda CodeCommit-Build Execution Policy",
                "PolicyDocument": [+ INCLUDE "codecommit-build-policy.json.in" +]
            }
        },
        "LambdaCodeCommitBuildIamServiceRole": {
            "Type": "AWS::IAM::Role",
            "Properties": {
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Action": "sts:AssumeRole",
                            "Principal": {
                                "Service": "lambda.amazonaws.com"
                            },
                            "Effect": "Allow"
                        }
                    ]
                },
                "ManagedPolicyArns": [
                    {"Ref": "LambdaCodeCommitBuildIamManagedPolicy"}
                ]
            }
        },
        "CodeCommitBuildLambdaPermission": {
            "Type": "AWS::Lambda::Permission",
            "Properties": {
                "FunctionName": {"Fn::GetAtt": [
                    "CodeCommitBuildLambdaFunction", "Arn"]},
                "Action": "lambda:InvokeFunction",
                "Principal": "sns.amazonaws.com",
                "SourceArn": {"Ref": "CodeCommitEventsSnsTopic"}
            }
        },
        "CodeCommitBuildLambdaFunction": {
            "Type": "AWS::Lambda::Function",
            "Properties": {
                "FunctionName": "codecommit-build-bae089e8-3871-4067-9a3d-bac114f08438",
                "Code": {
                    "ZipFile": [+ INCLUDE "codecommit-build.py.in" +]
                },
                "Description": "Start builds on commit events",
                "Handler": "index.handler",
                "MemorySize": 128,
                "Timeout": 3,
                "Role": {"Fn::GetAtt": [
                    "LambdaCodeCommitBuildIamServiceRole", "Arn"]},
                "Runtime": "python3.7"
            }
        },
        "CodeCommitBuildSnsSubscription": {
            "Type": "AWS::SNS::Subscription",
            "Properties": {
                "Protocol": "lambda",
                "Endpoint": {"Fn::GetAtt": [
                    "CodeCommitBuildLambdaFunction", "Arn"]},
                "TopicArn": {"Ref": "CodeCommitEventsSnsTopic"}
            }
        }
    }
}
