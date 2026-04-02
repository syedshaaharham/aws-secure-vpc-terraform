import json
import uuid
import boto3
from datetime import datetime
import hashlib

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    try:
        # Get user ID from Cognito authorizer
        user_id = event['requestContext']['authorizer']['claims']['sub']
        
        query_params = event.get('queryStringParameters') or {}
        file_name = query_params.get('fileName', 'document.pdf')
        expiry_days = int(query_params.get('expiryDays', 7))
        password = query_params.get('password')  # optional

        file_id = str(uuid.uuid4())
        s3_key = f"uploads/{user_id}/{file_id}-{file_name}"

        bucket_name = os.environ['BUCKET_NAME']
        table_name = os.environ['TABLE_NAME']

        # Generate presigned URL for upload (10 minutes)
        upload_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': bucket_name,
                'Key': s3_key,
                'ContentType': 'application/octet-stream'
            },
            ExpiresIn=600
        )

        # Save metadata to DynamoDB
        table = dynamodb.Table(table_name)
        expiry_timestamp = int(datetime.utcnow().timestamp()) + (expiry_days * 86400)

        item = {
            'fileId': file_id,
            'userId': user_id,
            'originalFileName': file_name,
            's3Key': s3_key,
            'uploadDate': datetime.utcnow().isoformat(),
            'expiryDate': expiry_timestamp,
            'downloadCount': 0,
            'accessLogs': []
        }

        if password:
            item['passwordHash'] = hashlib.sha256(password.encode()).hexdigest()

        table.put_item(Item=item)

        return {
            'statusCode': 200,
            'headers': {'Content-Type': 'application/json'},
            'body': json.dumps({
                'fileId': file_id,
                'uploadUrl': upload_url,
                'message': 'Upload URL generated successfully'
            })
        }

    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to generate upload URL'})
        }