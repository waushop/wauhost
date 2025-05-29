#!/usr/bin/env python3
"""
MinIO Integration Example for Python

This example demonstrates how to connect to MinIO deployed in Kubernetes
and perform basic operations like creating buckets, uploading files, etc.
"""

import os
import sys
import json
import logging
from datetime import timedelta
from pathlib import Path
from typing import Optional, List, Dict, Any

from minio import Minio
from minio.error import S3Error
from minio.datatypes import Object

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)


class MinioClient:
    """Wrapper class for MinIO operations"""
    
    def __init__(self, 
                 endpoint: str = None,
                 access_key: str = None,
                 secret_key: str = None,
                 secure: bool = True):
        """
        Initialize MinIO client
        
        Args:
            endpoint: MinIO endpoint (e.g., 'images.example.com')
            access_key: Access key for MinIO
            secret_key: Secret key for MinIO
            secure: Use HTTPS (default: True)
        """
        self.endpoint = endpoint or os.getenv('MINIO_ENDPOINT', 'images.example.com')
        self.access_key = access_key or os.getenv('MINIO_ACCESS_KEY')
        self.secret_key = secret_key or os.getenv('MINIO_SECRET_KEY')
        self.secure = secure
        
        if not all([self.endpoint, self.access_key, self.secret_key]):
            raise ValueError("MinIO endpoint, access key, and secret key are required")
        
        self.client = Minio(
            self.endpoint,
            access_key=self.access_key,
            secret_key=self.secret_key,
            secure=self.secure
        )
        
    def check_connection(self) -> bool:
        """Check if MinIO connection is working"""
        try:
            self.client.list_buckets()
            logger.info("✅ Successfully connected to MinIO")
            return True
        except S3Error as e:
            logger.error(f"❌ Failed to connect to MinIO: {e}")
            return False
    
    def ensure_bucket(self, bucket_name: str, public: bool = False) -> bool:
        """
        Ensure a bucket exists, create if it doesn't
        
        Args:
            bucket_name: Name of the bucket
            public: Make bucket publicly readable (default: False)
        """
        try:
            if not self.client.bucket_exists(bucket_name):
                self.client.make_bucket(bucket_name)
                logger.info(f"✅ Bucket '{bucket_name}' created successfully")
                
                if public:
                    # Set bucket policy for public read
                    policy = {
                        "Version": "2012-10-17",
                        "Statement": [{
                            "Sid": "PublicRead",
                            "Effect": "Allow",
                            "Principal": "*",
                            "Action": ["s3:GetObject"],
                            "Resource": [f"arn:aws:s3:::{bucket_name}/*"]
                        }]
                    }
                    self.client.set_bucket_policy(bucket_name, json.dumps(policy))
                    logger.info(f"✅ Bucket policy set for '{bucket_name}'")
            else:
                logger.info(f"ℹ️  Bucket '{bucket_name}' already exists")
            return True
        except S3Error as e:
            logger.error(f"❌ Error with bucket '{bucket_name}': {e}")
            return False
    
    def upload_file(self, 
                    bucket_name: str,
                    object_name: str,
                    file_path: str,
                    content_type: Optional[str] = None) -> Optional[str]:
        """
        Upload a file to MinIO
        
        Args:
            bucket_name: Name of the bucket
            object_name: Object name in MinIO
            file_path: Local file path to upload
            content_type: Content type of the file
            
        Returns:
            Public URL if successful, None otherwise
        """
        try:
            # Auto-detect content type if not provided
            if not content_type:
                content_type = self._get_content_type(file_path)
            
            # Upload file
            self.client.fput_object(
                bucket_name,
                object_name,
                file_path,
                content_type=content_type
            )
            
            logger.info(f"✅ File uploaded: {object_name}")
            
            # Generate public URL
            public_url = f"https://{self.endpoint}/{bucket_name}/{object_name}"
            logger.info(f"📎 Public URL: {public_url}")
            
            return public_url
            
        except S3Error as e:
            logger.error(f"❌ Error uploading file: {e}")
            return None
    
    def list_objects(self, bucket_name: str, prefix: str = "") -> List[Object]:
        """
        List objects in a bucket
        
        Args:
            bucket_name: Name of the bucket
            prefix: Prefix to filter objects
            
        Returns:
            List of objects
        """
        try:
            objects = list(self.client.list_objects(bucket_name, prefix=prefix))
            logger.info(f"📋 Found {len(objects)} objects in '{bucket_name}'")
            return objects
        except S3Error as e:
            logger.error(f"❌ Error listing objects: {e}")
            return []
    
    def download_file(self, bucket_name: str, object_name: str, file_path: str) -> bool:
        """
        Download a file from MinIO
        
        Args:
            bucket_name: Name of the bucket
            object_name: Object name in MinIO
            file_path: Local file path to save
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.fget_object(bucket_name, object_name, file_path)
            logger.info(f"✅ File downloaded: {file_path}")
            return True
        except S3Error as e:
            logger.error(f"❌ Error downloading file: {e}")
            return False
    
    def generate_presigned_url(self, 
                               bucket_name: str,
                               object_name: str,
                               expiry: timedelta = timedelta(hours=1)) -> Optional[str]:
        """
        Generate a presigned URL for temporary access
        
        Args:
            bucket_name: Name of the bucket
            object_name: Object name in MinIO
            expiry: URL expiry time (default: 1 hour)
            
        Returns:
            Presigned URL if successful, None otherwise
        """
        try:
            url = self.client.presigned_get_object(bucket_name, object_name, expires=expiry)
            logger.info(f"🔗 Presigned URL (expires in {expiry}): {url}")
            return url
        except S3Error as e:
            logger.error(f"❌ Error generating presigned URL: {e}")
            return None
    
    def delete_object(self, bucket_name: str, object_name: str) -> bool:
        """
        Delete an object from MinIO
        
        Args:
            bucket_name: Name of the bucket
            object_name: Object name to delete
            
        Returns:
            True if successful, False otherwise
        """
        try:
            self.client.remove_object(bucket_name, object_name)
            logger.info(f"✅ Object deleted: {object_name}")
            return True
        except S3Error as e:
            logger.error(f"❌ Error deleting object: {e}")
            return False
    
    def get_bucket_size(self, bucket_name: str) -> Dict[str, Any]:
        """
        Calculate total size of a bucket
        
        Args:
            bucket_name: Name of the bucket
            
        Returns:
            Dictionary with size information
        """
        try:
            total_size = 0
            object_count = 0
            
            for obj in self.client.list_objects(bucket_name, recursive=True):
                total_size += obj.size
                object_count += 1
            
            return {
                'bucket': bucket_name,
                'total_size_bytes': total_size,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'object_count': object_count
            }
        except S3Error as e:
            logger.error(f"❌ Error calculating bucket size: {e}")
            return {}
    
    @staticmethod
    def _get_content_type(file_path: str) -> str:
        """Helper function to determine content type"""
        content_types = {
            '.jpg': 'image/jpeg',
            '.jpeg': 'image/jpeg',
            '.png': 'image/png',
            '.gif': 'image/gif',
            '.pdf': 'application/pdf',
            '.json': 'application/json',
            '.xml': 'application/xml',
            '.txt': 'text/plain',
            '.html': 'text/html',
            '.css': 'text/css',
            '.js': 'application/javascript',
            '.py': 'text/x-python',
            '.csv': 'text/csv',
            '.zip': 'application/zip'
        }
        
        ext = Path(file_path).suffix.lower()
        return content_types.get(ext, 'application/octet-stream')


def main():
    """Example usage of MinIO client"""
    print("🚀 MinIO Integration Example\n")
    
    # Initialize client
    try:
        client = MinioClient()
    except ValueError as e:
        logger.error(f"Failed to initialize MinIO client: {e}")
        logger.info("Please set MINIO_ENDPOINT, MINIO_ACCESS_KEY, and MINIO_SECRET_KEY environment variables")
        sys.exit(1)
    
    # Check connection
    if not client.check_connection():
        sys.exit(1)
    
    # Example operations
    bucket_name = "example-python-app"
    
    # 1. Ensure bucket exists
    if not client.ensure_bucket(bucket_name, public=True):
        sys.exit(1)
    
    # 2. Upload a file (if exists)
    test_file = "example.txt"
    if os.path.exists(test_file):
        object_name = f"uploads/{Path(test_file).name}"
        client.upload_file(bucket_name, object_name, test_file)
        
        # 3. List objects
        objects = client.list_objects(bucket_name, prefix="uploads/")
        for obj in objects:
            print(f"  - {obj.object_name} ({obj.size} bytes)")
        
        # 4. Generate presigned URL
        client.generate_presigned_url(bucket_name, object_name)
        
        # 5. Download file
        download_path = f"downloaded-{Path(test_file).name}"
        client.download_file(bucket_name, object_name, download_path)
        
        # 6. Get bucket size
        size_info = client.get_bucket_size(bucket_name)
        print(f"\n📊 Bucket statistics: {json.dumps(size_info, indent=2)}")
    else:
        # Create a test file
        with open(test_file, 'w') as f:
            f.write("Hello from Python MinIO example!")
        logger.info(f"Created test file: {test_file}")
        logger.info("Run the script again to test upload operations")


if __name__ == "__main__":
    main()