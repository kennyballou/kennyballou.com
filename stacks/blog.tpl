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
                        "MinimumProtocolVersion": "TLSv1.1_2016",
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
                "Runtime": "nodejs6.10",
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
                                        "logs:CreateLogGroup",
                                        "logs:CreateLogStream",
                                        "logs:PutLogEvents"
                                    ],
                                    "Resource": [
                                        "arn:aws:logs:*:*:*"
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
                "FunctionName": {"Ref": "URIRewriteLambdaFunction"},
                "Description": "Lambda Function performing URI rewriting"
            }
        }
    }
}
