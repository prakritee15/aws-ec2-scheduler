import os
import boto3
import datetime

EC2 = boto3.client("ec2")
SNS = boto3.client("sns")

# ENV from Lambda configuration
TAG_KEY = os.getenv("SCHEDULE_TAG", "Schedule")
SNS_TOPIC_ARN = os.getenv("SNS_TOPIC_ARN", "")

def _now_ist():
    # Adjust as needed; using Asia/Kolkata for your locale
    # Lambda UTC -> IST (+5:30)
    now_utc = datetime.datetime.utcnow()
    return now_utc + datetime.timedelta(hours=5, minutes=30)

def _filter_instances_by_tag(value):
    resp = EC2.describe_instances(
        Filters=[
            {"Name": f"tag:{TAG_KEY}", "Values": [value]},
            {"Name": "instance-state-name", "Values": ["stopped", "running"]}
        ]
    )
    ids = []
    for r in resp["Reservations"]:
        for i in r["Instances"]:
            ids.append(i["InstanceId"])
    return ids

def _publish(msg):
    if SNS_TOPIC_ARN:
        SNS.publish(TopicArn=SNS_TOPIC_ARN, Subject="EC2 Scheduler", Message=msg)

def start_office_hours(event=None, context=None):
    """
    Start instances tagged Schedule=office-hours at 09:00 IST Mon–Fri
    (You’ll configure the schedule in CloudWatch Events)
    """
    ids = _filter_instances_by_tag("office-hours")
    if not ids:
        _publish("No instances to start.")
        return {"ok": True, "count": 0}
    EC2.start_instances(InstanceIds=ids)
    _publish(f"Started instances: {ids}")
    return {"ok": True, "started": ids}

def stop_office_hours(event=None, context=None):
    """
    Stop instances tagged Schedule=office-hours at 19:00 IST Mon–Fri
    """
    ids = _filter_instances_by_tag("office-hours")
    if not ids:
        _publish("No instances to stop.")
        return {"ok": True, "count": 0}
    EC2.stop_instances(InstanceIds=ids)
    _publish(f"Stopped instances: {ids}")
    return {"ok": True, "stopped": ids}
