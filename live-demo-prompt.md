# Live Demo Prompt: Enhanced CUR + COH Cost Optimization Emailer

## Context
I have an existing Lambda function that emails CUR (Cost and Usage Report) data from Athena queries. I want to enhance it by adding Cost Optimization Hub (COH) data to create a fun, engaging cost optimization report perfect for live streaming demos.

## Requirements
Create a new CloudFormation template that:

1. **Combines two data sources:**
   - CUR data from Athena (current spending by service)
   - COH recommendations (potential savings opportunities)

2. **Generates fun metrics for live demos:**
   - Coffee cups worth of savings ($5 per cup)
   - Pizza parties potential ($50 per party)
   - Efficiency score and optimization grade (A+ to C)
   - Total potential monthly savings

3. **Creates an engaging HTML email with:**
   - Rich visual formatting with CSS styling
   - Color-coded sections and gradients
   - Side-by-side comparison of spend vs savings
   - Top cost drivers table from CUR
   - Top optimization opportunities from COH
   - Emojis and fun presentation elements

4. **Technical requirements:**
   - Python 3.11 Lambda function
   - Enhanced IAM permissions for COH access
   - Scheduled execution via CloudWatch Events
   - Error monitoring and alarms
   - S3 bucket for Athena results

## Expected Output
- Complete CloudFormation template with inline Lambda code
- HTML email template with dashboard-style layout
- Test event JSON for console testing
- Fun, engaging presentation suitable for live streaming

## Demo Focus
This should be entertaining and educational, showing real cost optimization potential while being visually appealing for a live audience. The email should tell a story about AWS spending and savings opportunities.