import json
import random
import string
import boto3

dynamodb = boto3.resource('dynamodb')

def handler(event, context):
    try:
        user_id = event['requestContext']['authorizer']['claims']['sub']
        body = json.loads(event.get('body', '{}'))
        file_id = body.get('fileId')

        table = dynamodb.Table(os.environ['TABLE_NAME'])

        # Get file metadata
        response = table.get_item(Key={'fileId': file_id})
        if 'Item' not in response or response['Item']['userId'] != user_id:
            return {
                'statusCode': 403,
                'body': json.dumps({'error': 'Access denied'})
            }

        # Generate short code
        short_code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

        # Update DynamoDB with short code
        table.update_item(
            Key={'fileId': file_id},
            UpdateExpression="SET shortCode = :sc",
            ExpressionAttributeValues={':sc': short_code}
        )

        return {
            'statusCode': 200,
            'body': json.dumps({
                'shortCode': short_code,
                'shareUrl': f"https://your-frontend.com/share/{short_code}",  # Update later
                'expiresIn': '7 days'
            })
        }

    except Exception as e:
        print(e)
        return {
            'statusCode': 500,
            'body': json.dumps({'error': 'Failed to generate share link'})
        }