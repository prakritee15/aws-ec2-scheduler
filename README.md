# aws-ec2-scheduler
An AWS account with permission to create IAM, Lambda, CloudWatch Events, EC2 read/start/stop, SNS

aws-ec2-scheduler/
├─ lambda/
│  ├─ app.py
│  └─ requirements.txt          # (optional; AWS provides boto3 by default)
├─ terraform/
│  ├─ main.tf
│  ├─ variables.tf
│  ├─ outputs.tf
│  └─ versions.tf
└─ .github/
   └─ workflows/
      └─ ci.yml
