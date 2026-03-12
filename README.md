# What this scheduler does

Scans for EC2 instances with a tag (default: Schedule=office-hours).
Starts them at 09:00 IST (Mon–Fri) and stops them at 19:00 IST (Mon–Fri).

Times are configured as EventBridge (CloudWatch) cron in UTC and map to IST by default. You can change this easily.


Posts a short SNS notification after each run (start/stop summary).
Uses a least‑privilege IAM role and logs to CloudWatch.

# Sample tag usage

Add this tag to any non‑prod EC2 instance you want managed by the scheduler:

Key:   Schedule
Value: office-hours

# How it saves cost

Non‑prod environments are often idle at night and weekends. By stopping instances off‑hours, you can save a large portion of compute cost with zero daily effort. Just tag once—let the scheduler handle the rest.


# How it’s built (high level)

Lambda (Python/Boto3): finds instances by tag and calls StartInstances / StopInstances
EventBridge/CloudWatch rules: cron‑based schedules (UTC) that invoke Lambda
SNS: optional email alerts (subscribe your email once)
Terraform: one‑command provisioning of the above
GitHub Actions (OIDC): CI pipeline to zip Lambda and apply Terraform (no long‑lived AWS secrets)


# Deploy (CI in 1–2 lines)

Recommended: Push to main → GitHub Actions runs Terraform and deploys automatically using OIDC.
Minimal setup: create an AWS IAM role trusted for GitHub OIDC (pointed to your repo) and put its ARN in the workflow file at .github/workflows/ci.yml.

That’s it—commit and push. CI zips the Lambda, runs terraform init/plan/apply, and your scheduler is live.


# Tag instances & verify
Tag your instances
In the EC2 console, for each dev/test instance you want managed:
Key:   Schedule
Value: office-hours


# Watch the next run

Go to EventBridge › Rules and check the next scheduled time for:

ec2-scheduler-start-0930IST (approx 09:00 IST)
ec2-scheduler-stop-1930IST  (approx 19:00 IST)
Or trigger a quick test from the Lambda console (invoke handler manually).
Confirm actions

EC2 console → instance state changes to running/stopped after the schedule.
CloudWatch Logs → Lambda log group shows “Started instances: [...]” or “Stopped instances: [...]”.
SNS → if you provided an email in Terraform, confirm the subscription once; you’ll receive start/stop summaries.




# Configuration (common tweaks)

Region: change aws_region in terraform/variables.tf (default: ap-south-1).
Email alerts: set sns_email variable to receive notifications.
Tag key: default is Schedule. You can change it by editing the Lambda env (SCHEDULE_TAG) in Terraform.
Different hours: edit the cron expressions in terraform/main.tf for start_rule and stop_rule (they use UTC).


# Repository layout
aws-ec2-scheduler/
├─ lambda/
│  ├─ app.py                # Lambda handlers (start_office_hours / stop_office_hours)
│  └─ requirements.txt      # (optional; boto3 is available in AWS Lambda by default)
├─ terraform/
│  ├─ main.tf               # IAM, Lambda, EventBridge, SNS
│  ├─ variables.tf          # region, project name, sns_email
│  ├─ outputs.tf
│  └─ versions.tf
└─ .github/
   └─ workflows/ci.yml      # CI: zip Lambda + Terraform init/plan/apply via OIDC


# Local test (optional)
If you want to test outside CI:
#From repo root


cd lambda

zip -r ../lambda.zip app.py

cd ../terraform

terraform init

terraform plan -var="sns_email=you@example.com"

terraform apply -auto-approve



After apply:

Add Schedule=office-hours to a test EC2 instance.
(Optional) Temporarily change the cron to run in a minute to see it work immediately.


# Permissions (sane defaults)

Lambda role is granted:

CloudWatch Logs write
EC2 Describe/Start/Stop
SNS Publish (to the project’s topic)


# Safe cleanup
When you’re done testing (to avoid charges):

Via CI: comment out resources in Terraform and push → CI will destroy/modify accordingly (advanced).
Locally:
Shellcd terraformterraform destroy -auto-approveShow more lines

Manual check: ensure the SNS topic, Lambda functions, EventBridge rules, and the IAM role/policy created for this project are removed. Untag any instances if you added tags for testing.


# Roadmap (easy extensions)

Multiple schedules (e.g., Schedule=weekends, Schedule=nightly)
Parse windows from tags (e.g., Schedule=09:00-19:00@Mon-Fri)
Handle RDS or Auto Scaling groups
Slack/Teams notifications
Store action history in DynamoDB
Tighten IAM to least privilege for production

# FAQ
Q: Will this stop critical instances?
A: Only if you tag them. Use tags carefully and start with non‑prod/dev instances.
Q: Can I run it in another region?
A: Yes—set aws_region in Terraform and ensure your test instances are in that region.
Q: What if my hours aren’t IST?
A: Edit the cron (UTC) in EventBridge rules to your preferred schedule.
