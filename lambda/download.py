import json
import boto3
from datetime import datetime
import hashlib

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    try:
        short_code = event['pathParameters'].get('shortCode')
        provided_password = event.get('queryStringParameters', {}).get('password')

        table = dynamodb.Table(os.environ['TABLE_NAME'])

        # Query by shortCode (we'll add GSI later)
        response = table.query(
            IndexName="ShortCodeIndex",   # We'll add this in Terraform
            KeyConditionExpression="shortCode = :sc",
            ExpressionAttributeValues={':sc': short_code}
        )

        if not response['Items']:
            return {
                'statusCode': 404,
                'body': json.dumps({'error': 'Link not found or expired'})
            }

        file = response['Items'][0]

        # Check expiry
        if file['expiryDate'] < int(datetime.utcnow().timestamp()):
            return {
                'statusCode': 410,
                'body': json.dumps({'error': 'Link has expired'})
            }

        # Check password if set
        if file.get('passwordHash'):
            if not provided_password or hashlib.sha256(provided_password.encode()).hexdigest() != file['passwordHash']:
                return {
                    'statusCode': 403,
                    'body': json.dumps({'error': 'Incorrect password'})
                }

        # Generate presigned download URL (15 minutes)
        download_url = s3.generate_presigned_url(
            'get_object',
            Params={
                'Bucket': os.environ['BUCKET_NAME'],
                'Key': file['s3Key']
            },
            ExpiresIn=900
        )

        # Log the access
        table.update_item(
            Key={'fileId': file['fileId']},
            UpdateExpression="SET downloadCount = if_not_exists(downloadCount, :zero) + :inc, accessLogs = list_append(if_not_exists(accessLogs, :empty), :log)",
            ExpressionAttributeValues={
                ':inc': 1,
                ':zero': 0,
                ':empty': [],
                ':log': [{
                    'timestamp': datetime.utcnow().isoformat(),
                    'ip': event.get('requestContext', {}).get('identity', {}).get('sourceIp', 'unknown')
                }]
            }
        )

        return {
            'statusCode': 200,
            'body': json.dumps({'downloadUrl': download_url})
        }

    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Internal server error'})
        }