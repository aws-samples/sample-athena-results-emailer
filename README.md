# Athena Query Lambda Solution - CloudFormation

This CloudFormation solution converts the original Terraform-based Athena query automation into AWS CloudFormation templates. The solution automatically runs scheduled Athena queries against your billing data and sends the results via email.

## Architecture Overview

The solution consists of:

1. **Lambda Function**: Executes Athena queries and processes results
2. **CloudWatch Events Rule**: Triggers the Lambda on a schedule
3. **S3 Bucket**: Stores Athena query results
4. **IAM Roles & Policies**: Provides necessary permissions
5. **CloudWatch Alarms**: Monitors Lambda function health
6. **SES Integration**: Sends email notifications with CSV attachments

## Files Structure

```
cloudformation_templates/
├── athena-query-solution-simple.yaml      # Simplified all-in-one template
├── parameters.json                         # Parameter values
├── deploy.sh                              # Deployment script
├── sql_queries/
│   └── account_monthly_bill.sql           # Sample SQL query
└── README.md                              # This file
```

## Prerequisites

1. **AWS CLI** installed and configured
2. **SES Email Verification**: Both sender and receiver emails must be verified in SES
3. **Athena Database**: Your billing database should already exist
4. **S3 Permissions**: Ensure your account has access to create S3 buckets

## Quick Start

### 1. Configure Parameters

Edit `parameters.json` with your specific values:

```json
[
  {
    "ParameterKey": "SenderEmail",
    "ParameterValue": "your-sender@example.com"
  },
  {
    "ParameterKey": "ReceiverEmail", 
    "ParameterValue": "your-receiver@example.com"
  },
  {
    "ParameterKey": "AthenaDatabase",
    "ParameterValue": "your_athena_database"
  },
  {
    "ParameterKey": "AthenaTable",
    "ParameterValue": "your_billing_table"
  }
]
```

### 2. Deploy the Stack

```bash
# Basic deployment
./deploy.sh my-athena-stack us-east-1 prod

# Or manually with AWS CLI
aws cloudformation create-stack \
  --stack-name athena-query-solution \
  --template-body file://athena-query-solution-simple.yaml \
  --parameters file://parameters.json \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

### 3. Verify Email Addresses

Ensure both sender and receiver email addresses are verified in SES:

```bash
# Verify email addresses in SES
aws ses verify-email-identity --email-address your-sender@example.com
aws ses verify-email-identity --email-address your-receiver@example.com
```

## Configuration Options

### Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `Environment` | Environment suffix for resources | `""` |
| `SenderEmail` | Email address for sending notifications | `example@email.com` |
| `ReceiverEmail` | Email address for receiving notifications | `example@email.com` |
| `BucketName` | Base name for S3 bucket | `buisnesspennybucket` |
| `AthenaDatabase` | Athena database name | `athenacurcfn_mybillingreport` |
| `AthenaTable` | Athena table name | `mybillingreport` |
| `ScheduleExpression` | CloudWatch Events cron expression | `cron(07 1 * ? * *)` |
| `QueryName` | Name for the query execution | `account_monthly_bill` |
| `QueryType` | Type of query (`finops_bill` or `finops_report`) | `finops_bill` |

### Schedule Expressions

The solution uses CloudWatch Events cron expressions:

- `cron(07 1 * ? * *)` - Daily at 1:07 AM
- `cron(0 10 1 * ? *)` - Monthly on the 1st at 10:00 AM
- `cron(0 9 ? * MON *)` - Weekly on Mondays at 9:00 AM

## Customization

### Adding New Queries

1. Update the CloudWatch Events target input with your new SQL query
2. Modify the `QueryName` parameter
3. Redeploy the stack

### Modifying the Lambda Function

1. Edit the inline code in the CloudFormation template
2. Update the stack to deploy changes

### Email Format

The Lambda function sends results as CSV attachments with filename format `{query_name}_{date}.csv`. If no results are found, it sends an email explaining that no results were returned.

## Monitoring

The solution includes CloudWatch alarms for:

1. **Lambda Errors**: Triggers when the function fails
2. **Lambda Duration**: Triggers when execution time is high

View logs in CloudWatch Logs under `/aws/lambda/athena_query{Environment}`

## Troubleshooting

### Common Issues

1. **SES Email Not Verified**
   ```
   Solution: Verify both sender and receiver emails in SES console
   ```

2. **Athena Query Fails**
   ```
   Check: Database and table names in parameters
   Check: IAM permissions for Athena and Glue
   ```

3. **S3 Access Denied**
   ```
   Check: S3 bucket policy and IAM role permissions
   Check: Bucket name uniqueness (account ID is appended)
   ```

4. **Lambda Timeout**
   ```
   Solution: Increase timeout value in template (current: 300 seconds)
   ```

### Debugging Steps

1. Check CloudWatch Logs for the Lambda function
2. Verify Athena query execution in Athena console
3. Check S3 bucket for query results
4. Verify SES sending statistics

## Security Considerations

1. **IAM Permissions**: The solution uses least-privilege access
2. **S3 Encryption**: Results are encrypted with SSE-S3
3. **VPC**: Consider deploying Lambda in VPC for additional security
4. **Secrets**: Use AWS Secrets Manager for sensitive configuration

## Cost Optimization

1. **Lambda Memory**: Adjust based on actual usage (current: 512MB)
2. **S3 Lifecycle**: Configure lifecycle policies for old query results
3. **Athena Optimization**: Use partitioning and compression for cost savings
4. **CloudWatch Logs**: Set retention periods appropriately

## Migration from Terraform

Key differences from the original Terraform solution:

1. **Simplified Code**: Inline Lambda function with minimal dependencies
2. **Email Format**: Plain text results instead of CSV attachments
3. **No External Dependencies**: All code is embedded in the CloudFormation template
4. **Reduced Complexity**: Single template file with streamlined functionality

## Support

For issues or questions:

1. Check CloudWatch Logs first
2. Verify all prerequisites are met
3. Review AWS service limits
4. Check IAM permissions

## Security

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.

