# Manual AWS Console Setup Guide
## Athena Query Automation with Email Notifications

This guide walks through creating the Athena query automation solution manually in the AWS console, perfect for demonstrations and understanding each component.

---

## Overview
We'll build a system that:
1. Runs scheduled Athena queries against billing data
2. Sends results as CSV email attachments
3. Monitors for errors and failures

**Total Setup Time:** ~20-30 minutes

**PreRec**
CUR has been setup

---

## Step 1: Setup SES (Simple Email Service)

### 1.1 Verify Email Addresses
1. Navigate to **SES Console** → **Identities**
2. Click **Create identity**
3. Select **Email address**
4. Enter your sender email (e.g., `billing-reports@company.com`)
5. Click **Create identity**
6. Check your email and click the verification link
7. Repeat for receiver email address

**Demo Tip:** Mention that in production, you'd use domain verification instead of individual emails.

**Common Gotcha:** SES starts in sandbox mode - can only send to verified addresses. For production, request production access.

---

## Step 2: Create S3 Bucket for Athena Results

### 2.1 Create Results Bucket
1. Navigate to **S3 Console**
2. Click **Create bucket**
3. Bucket name: `athena-query-results-{your-account-id}` (must be globally unique)
4. Region: Choose your preferred region
5. **Block Public Access**: Keep all boxes checked (default)
6. **Versioning**: Enable
7. **Encryption**: Server-side encryption with S3 managed keys (default)
8. Click **Create bucket**
9. IMPU RULES

**Demo Tip:** Explain why bucket names need account ID suffix for uniqueness.

**Common Gotcha:** Bucket names must be globally unique across all AWS accounts.

---

## Step 3: Create IAM Role for Lambda

### 3.1 Create Lambda Execution Role
1. Navigate to **IAM Console** → **Roles**
2. Click **Create role**
3. **Trusted entity**: AWS service
4. **Service**: Lambda
5. Click **Next**

### 3.2 Attach Basic Lambda Policy
1. Search and select: `AWSLambdaBasicExecutionRole`
2. Click **Next**
3. Role name: `athena-query-lambda-role`
4. Click **Create role**

### 3.3 Add Custom Inline Policy
1. Click on the newly created role
2. **Permissions** tab → **Add permissions** → **Create inline policy**
3. **JSON** tab, paste this policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "athena:BatchGetQueryExecution",
                "athena:GetQueryExecution",
                "athena:GetQueryResults",
                "athena:StartQueryExecution",
                "athena:StopQueryExecution",
                "athena:ListQueryExecutions"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetBucketLocation",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:PutObject",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::athena-query-results-*",
                "arn:aws:s3:::athena-query-results-*/*",
                "arn:aws:s3:::your-cur-bucket-name",
                "arn:aws:s3:::your-cur-bucket-name/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "ses:SendEmail",
                "ses:SendRawEmail"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "glue:GetDatabase",
                "glue:GetTable",
                "glue:GetPartitions"
            ],
            "Resource": "*"
        }
    ]
}
```

4. Policy name: `AthenaQueryPolicy`
5. Click **Create policy**

**Demo Tip:** Explain principle of least privilege - only permissions needed for the task.

**Common Gotcha:** Replace `your-cur-bucket-name` with actual CUR bucket name.

---

## Step 4: Create Lambda Function

### 4.1 Create Function
1. Navigate to **Lambda Console**
2. Click **Create function**
3. **Author from scratch**
4. Function name: `athena_query`
5. Runtime: **Python 3.11**
6. **Execution role**: Use existing role → `athena-query-lambda-role`
7. Click **Create function**

### 4.2 Configure Function Settings
1. **Configuration** tab → **General configuration** → **Edit**
2. **Timeout**: 5 minutes (300 seconds)
3. **Memory**: 512 MB
4. Click **Save**

### 4.3 Add Environment Variables
1. **Configuration** tab → **Environment variables** → **Edit**
2. Add variables:
   - `SENDEREMAIL`: `your-sender@email.com`
   - `RECIVEREMAIL`: `your-receiver@email.com`
   - `REGION`: `us-east-1` (or your region)
3. Click **Save**

### 4.4 Add Function Code
1. **Code** tab
2. Replace the default code with:

```python
import boto3
import time
import json
import os
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
from email.mime.application import MIMEApplication

# AWS clients
athena = boto3.client('athena')
ses = boto3.client('ses')

def lambda_handler(event, context):
    query = event['Query']
    database = event['Database']
    query_name = event['Query_Name']
    bucket = event['Bucket']
    
    # Start query
    response = athena.start_query_execution(
        QueryString=query,
        QueryExecutionContext={'Database': database},
        ResultConfiguration={'OutputLocation': f's3://{bucket}/athena/{query_name}'}
    )
    query_id = response['QueryExecutionId']
    
    # Wait for completion
    while True:
        result = athena.get_query_execution(QueryExecutionId=query_id)
        status = result['QueryExecution']['Status']['State']
        if status in ['SUCCEEDED', 'FAILED', 'CANCELLED']:
            break
        time.sleep(5)
    
    if status != 'SUCCEEDED':
        raise Exception(f'Query failed: {status}')
    
    # Get results
    results = athena.get_query_results(QueryExecutionId=query_id)
    rows = results['ResultSet']['Rows']
    
    # Create email
    msg = MIMEMultipart()
    msg['Subject'] = f'Athena Results: {query_name}'
    msg['From'] = os.environ['SENDEREMAIL']
    msg['To'] = os.environ['RECIVEREMAIL']
    
    if len(rows) > 1:  # Has data (first row is headers)
        # Create CSV content
        csv_lines = []
        for row in rows:
            line = [col.get('VarCharValue', '') for col in row['Data']]
            csv_lines.append(','.join(f'"{cell}"' for cell in line))
        csv_content = '\n'.join(csv_lines)
        
        # Add body
        msg.attach(MIMEText('Please find attached the query results.'))
        
        # Add CSV attachment
        filename = f"{query_name}_{datetime.now().strftime('%Y-%m-%d')}.csv"
        attachment = MIMEApplication(csv_content.encode('utf-8'))
        attachment.add_header('Content-Disposition', 'attachment', filename=filename)
        msg.attach(attachment)
    else:
        # No results
        msg.attach(MIMEText('Query completed but returned no results.'))
    
    # Send email
    ses.send_raw_email(
        Source=os.environ['SENDEREMAIL'],
        Destinations=[os.environ['RECIVEREMAIL']],
        RawMessage={'Data': msg.as_string()}
    )
    
    return {'statusCode': 200, 'body': f'Query {query_name} completed'}
```

3. Click **Deploy**

**Demo Tip:** Explain the code flow - query execution, waiting, results processing, email creation.

**Common Gotcha:** Make sure environment variables match exactly (case-sensitive).

---

## Step 5: Create CloudWatch Event Rule

### 5.1 Create Event Rule
1. Navigate to **EventBridge Console** → **Rules**
2. Click **Create rule**
3. Name: `finops_bill_account_monthly_bill`
4. Description: `Scheduled rule for Athena query execution`
5. **Event bus**: default
6. **Rule type**: Schedule
7. Click **Next**

### 5.2 Configure Schedule
1. **Schedule pattern**: Cron expression
2. **Cron expression**: `cron(07 1 * * ? *)`
   - This runs daily at 1:07 AM UTC
3. Click **Next**

### 5.3 Configure Target
1. **Target type**: AWS service
2. **Service**: Lambda
3. **Function**: `athena_query`
4. **Configure input**: Constant (JSON text)
5. **JSON**: 
```json
{
  "Query": "SELECT * FROM YOUR-DATABASE LIMIT 10",
  "Database": "YOUR-DATABASE",
  "Query_Name": "account_monthly_bill",
  "Bucket": "athena-query-results-111222333",
  "Env": "",
  "Query_Type": "finops_bill"
}
```
6. Click **Next**
7. Click **Create rule**

**Demo Tip:** Explain cron expressions and show how to modify for different schedules.
USE Q to improve logging?????
**Common Gotcha:** Update the bucket name and database name to match your actual values.

---

## Step 6: Add Lambda Permission for EventBridge

### 6.1 Add Resource-based Policy
1. Go back to **Lambda Console** → `athena_query` function
2. **Configuration** tab → **Permissions**
3. **Resource-based policy** → **Add permissions**
4. **Policy statement**:
   - **Statement ID**: `allow-eventbridge`
   - **Principal**: `events.amazonaws.com`
   - **Action**: `lambda:InvokeFunction`
   - **Source ARN**: `arn:aws:events:REGION:ACCOUNT:rule/finops_bill_account_monthly_bill`
5. Click **Save**

**Demo Tip:** Explain why Lambda needs explicit permission for EventBridge to invoke it.

**Common Gotcha:** Replace REGION and ACCOUNT with your actual values.

---

## Step 7: Create CloudWatch Alarm

### 7.1 Create Error Alarm
1. Navigate to **CloudWatch Console** → **Alarms**
2. Click **Create alarm**
3. **Select metric** → **Lambda** → **By Function Name**
4. Select your function → **Errors** metric
5. Click **Select metric**

### 7.2 Configure Alarm
1. **Statistic**: Sum
2. **Period**: 5 minutes
3. **Threshold**: Static
4. **Greater than**: 1
5. **Datapoints to alarm**: 1 out of 1
6. Click **Next**

### 7.3 Configure Actions (Optional)
1. **Alarm state trigger**: In alarm
2. **SNS topic**: Create new or select existing
3. Click **Next**
4. **Alarm name**: `athena_query_error_alarm`
5. Click **Create alarm**

**Demo Tip:** Explain how CloudWatch alarms help monitor system health.

---

## Step 8: Test the Setup

### 8.1 Manual Test
1. Go to **Lambda Console** → `athena_query` function
2. **Test** tab → **Create new test event**
3. **Event name**: `test-event`
4. **Event JSON**: Use the same JSON from Step 5.3
5. Click **Test**
6. Check execution results and logs

### 8.2 Verify Email
1. Check your receiver email for the CSV attachment
2. Verify the CSV contains query results

**Demo Tip:** Show the CloudWatch logs to demonstrate monitoring capabilities.

**Common Gotcha:** If test fails, check CloudWatch logs for detailed error messages.

---

## Demo Tips & Talking Points

### For Business Audience:
- **Cost Savings**: Automated reporting reduces manual effort
- **Reliability**: Scheduled execution ensures consistent reporting
- **Scalability**: Can easily add more queries and recipients

### For Technical Audience:
- **Security**: IAM roles follow least-privilege principle
- **Monitoring**: CloudWatch integration for operational visibility
- **Flexibility**: Easy to modify queries and schedules

### Common Demo Gotchas:
1. **Email delays**: SES can take 1-2 minutes to deliver
2. **Athena permissions**: Ensure Lambda can access your CUR data
3. **Region consistency**: All resources should be in same region
4. **Bucket naming**: S3 bucket names must be globally unique

---

## Cleanup (After Demo)

To avoid ongoing charges:
1. Delete CloudWatch Event Rule
2. Delete Lambda function
3. Delete IAM role
4. Delete S3 bucket (if not needed)
5. Keep SES verified emails (no charge)

---

## Next Steps

After manual setup, show how CloudFormation automates this entire process with a single template deployment.