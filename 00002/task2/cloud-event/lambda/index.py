import json, os, boto3
from datetime import datetime, timezone
ec2=boto3.client("ec2"); sns=boto3.client("sns")
def alert(kind, detail, action): sns.publish(TopicArn=os.environ["SNS_TOPIC_ARN"],Message=json.dumps({"event":kind,"timestamp":datetime.now(timezone.utc).isoformat(),"detail":detail,"action":action}))
def stop_handler(event,context):
    instance=event.get("detail",{}).get("instance-id",os.environ["INSTANCE_ID"]); ec2.start_instances(InstanceIds=[instance]); alert("EC2_STOPPED",f"Instance {instance} restarted","RESTORED")
def terminate_handler(event,context): alert("EC2_TERMINATED",json.dumps(event.get("detail",{})),"ALERT_ONLY")
def tag_handler(event,context): alert("TAG_NON_COMPLIANT",json.dumps(event.get("detail",{})),"ALERT_ONLY")
def sg_handler(event,context):
    p=event.get("detail",{}).get("requestParameters",{}); group=p.get("groupId",os.environ["SECURITY_GROUP_ID"]); perms=[]
    for item in p.get("ipPermissions",{}).get("items",[]):
        perm={"IpProtocol":item.get("ipProtocol","-1")}
        if item.get("fromPort") is not None: perm.update(FromPort=item["fromPort"],ToPort=item["toPort"])
        perm["IpRanges"]=[{"CidrIp":x["cidrIp"]} for x in item.get("ipRanges",{}).get("items",[])]
        perms.append(perm)
    if perms: ec2.revoke_security_group_ingress(GroupId=group,IpPermissions=perms)
    alert("SG_INBOUND_ADDED",f"Unauthorized inbound rule removed from {group}","RESTORED")
def role_handler(event,context):
    instance=os.environ["INSTANCE_ID"]; rows=ec2.describe_iam_instance_profile_associations(Filters=[{"Name":"instance-id","Values":[instance]}])["IamInstanceProfileAssociations"]
    if rows: ec2.replace_iam_instance_profile_association(AssociationId=rows[0]["AssociationId"],IamInstanceProfile={"Name":os.environ["ROLE_NAME"]})
    alert("ROLE_CHANGED",f"IAM role restored on {instance}","RESTORED")
def type_handler(event,context):
    instance=os.environ["INSTANCE_ID"]; ec2.stop_instances(InstanceIds=[instance]); ec2.get_waiter("instance_stopped").wait(InstanceIds=[instance]); ec2.modify_instance_attribute(InstanceId=instance,InstanceType={"Value":os.environ["INSTANCE_TYPE"]}); ec2.start_instances(InstanceIds=[instance]); alert("EC2_TYPE_CHANGED",f"Instance type restored on {instance}","RESTORED")

