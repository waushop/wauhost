/**
 * MinIO Integration Example for Node.js
 * 
 * This example demonstrates how to connect to MinIO deployed in Kubernetes
 * and perform basic operations like creating buckets, uploading files, etc.
 */

const Minio = require('minio');
const fs = require('fs');
const path = require('path');

// Configuration
// In production, these should come from environment variables or K8s secrets
const config = {
    endPoint: process.env.MINIO_ENDPOINT || 'images.example.com',
    port: parseInt(process.env.MINIO_PORT || '443'),
    useSSL: process.env.MINIO_USE_SSL !== 'false',
    accessKey: process.env.MINIO_ACCESS_KEY,
    secretKey: process.env.MINIO_SECRET_KEY
};

// Create MinIO client
const minioClient = new Minio.Client(config);

/**
 * Check if a bucket exists and create if it doesn't
 */
async function ensureBucket(bucketName) {
    try {
        const exists = await minioClient.bucketExists(bucketName);
        if (!exists) {
            await minioClient.makeBucket(bucketName, 'us-east-1');
            console.log(`✅ Bucket '${bucketName}' created successfully`);
            
            // Set bucket policy for public read (optional)
            const policy = {
                Version: '2012-10-17',
                Statement: [{
                    Sid: 'PublicRead',
                    Effect: 'Allow',
                    Principal: '*',
                    Action: ['s3:GetObject'],
                    Resource: [`arn:aws:s3:::${bucketName}/*`]
                }]
            };
            
            await minioClient.setBucketPolicy(bucketName, JSON.stringify(policy));
            console.log(`✅ Bucket policy set for '${bucketName}'`);
        } else {
            console.log(`ℹ️  Bucket '${bucketName}' already exists`);
        }
    } catch (error) {
        console.error(`❌ Error with bucket '${bucketName}':`, error);
        throw error;
    }
}

/**
 * Upload a file to MinIO
 */
async function uploadFile(bucketName, objectName, filePath) {
    try {
        const fileStream = fs.createReadStream(filePath);
        const fileStat = fs.statSync(filePath);
        
        await minioClient.putObject(
            bucketName,
            objectName,
            fileStream,
            fileStat.size,
            {
                'Content-Type': getContentType(filePath),
                'x-amz-acl': 'public-read'
            }
        );
        
        console.log(`✅ File uploaded: ${objectName}`);
        
        // Generate public URL
        const publicUrl = `https://${config.endPoint}/${bucketName}/${objectName}`;
        console.log(`📎 Public URL: ${publicUrl}`);
        
        return publicUrl;
    } catch (error) {
        console.error(`❌ Error uploading file:`, error);
        throw error;
    }
}

/**
 * List objects in a bucket
 */
async function listObjects(bucketName, prefix = '') {
    try {
        const objectsList = [];
        const stream = minioClient.listObjectsV2(bucketName, prefix, true);
        
        return new Promise((resolve, reject) => {
            stream.on('data', obj => objectsList.push(obj));
            stream.on('error', reject);
            stream.on('end', () => {
                console.log(`📋 Found ${objectsList.length} objects in '${bucketName}'`);
                resolve(objectsList);
            });
        });
    } catch (error) {
        console.error(`❌ Error listing objects:`, error);
        throw error;
    }
}

/**
 * Download a file from MinIO
 */
async function downloadFile(bucketName, objectName, downloadPath) {
    try {
        await minioClient.fGetObject(bucketName, objectName, downloadPath);
        console.log(`✅ File downloaded: ${downloadPath}`);
    } catch (error) {
        console.error(`❌ Error downloading file:`, error);
        throw error;
    }
}

/**
 * Generate a presigned URL for temporary access
 */
async function generatePresignedUrl(bucketName, objectName, expiry = 3600) {
    try {
        const url = await minioClient.presignedGetObject(bucketName, objectName, expiry);
        console.log(`🔗 Presigned URL (expires in ${expiry}s): ${url}`);
        return url;
    } catch (error) {
        console.error(`❌ Error generating presigned URL:`, error);
        throw error;
    }
}

/**
 * Helper function to determine content type
 */
function getContentType(filePath) {
    const ext = path.extname(filePath).toLowerCase();
    const contentTypes = {
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
        '.js': 'application/javascript'
    };
    return contentTypes[ext] || 'application/octet-stream';
}

/**
 * Example usage
 */
async function main() {
    console.log('🚀 MinIO Integration Example\n');
    
    // Check connection
    try {
        await minioClient.listBuckets();
        console.log('✅ Successfully connected to MinIO\n');
    } catch (error) {
        console.error('❌ Failed to connect to MinIO:', error);
        process.exit(1);
    }
    
    // Example operations
    const bucketName = 'example-app-assets';
    const fileName = 'example-image.jpg';
    
    try {
        // 1. Ensure bucket exists
        await ensureBucket(bucketName);
        
        // 2. Upload a file
        // Note: You'll need to have a file to upload
        if (fs.existsSync(fileName)) {
            const objectName = `uploads/${Date.now()}-${fileName}`;
            await uploadFile(bucketName, objectName, fileName);
            
            // 3. List objects
            const objects = await listObjects(bucketName, 'uploads/');
            objects.forEach(obj => {
                console.log(`  - ${obj.name} (${obj.size} bytes)`);
            });
            
            // 4. Generate presigned URL
            await generatePresignedUrl(bucketName, objectName, 3600);
            
            // 5. Download file
            const downloadPath = `./downloaded-${fileName}`;
            await downloadFile(bucketName, objectName, downloadPath);
        } else {
            console.log('ℹ️  Skipping file operations (no test file found)');
        }
        
    } catch (error) {
        console.error('❌ Example failed:', error);
        process.exit(1);
    }
}

// Run the example
if (require.main === module) {
    main().catch(console.error);
}

// Export functions for use in other modules
module.exports = {
    minioClient,
    ensureBucket,
    uploadFile,
    downloadFile,
    listObjects,
    generatePresignedUrl
};