import json
import os
from datetime import datetime

def handler(event, context):
    """
    Simple Lambda handler that outputs environment information.
    """
    environment = os.environ.get('ENVIRONMENT', 'unknown')
    s3_bucket = os.environ.get('S3_BUCKET', 'unknown')

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': f'Hello from {environment} environment!',
            'version': '1.1.0',
            'timestamp': datetime.utcnow().isoformat(),
            'environment': environment,
            's3_bucket': s3_bucket,
            'request_id': context.request_id
        })
    }
