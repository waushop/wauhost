# Node.js Integration Examples

This directory contains Node.js examples for integrating with the wauhost infrastructure components.

## Prerequisites

- Node.js 14+ installed
- Access to the Kubernetes cluster
- MinIO/MySQL credentials configured

## Setup

1. Install dependencies:
```bash
npm install
```

2. Configure environment variables:
```bash
# Create .env file
cat > .env << EOF
# MinIO Configuration
MINIO_ENDPOINT=images.example.com
MINIO_PORT=443
MINIO_USE_SSL=true
MINIO_ACCESS_KEY=your-access-key
MINIO_SECRET_KEY=your-secret-key

# MySQL Configuration
MYSQL_HOST=mysql.mysql.svc.cluster.local
MYSQL_PORT=3306
MYSQL_USER=your-user
MYSQL_PASSWORD=your-password
MYSQL_DATABASE=your-database
EOF
```

## Examples

### MinIO S3 Storage

The `minio-example.js` demonstrates:
- Connecting to MinIO
- Creating buckets
- Uploading files
- Generating public/presigned URLs
- Downloading files
- Listing objects

Run the example:
```bash
npm run minio-example
```

### Using in Your Application

```javascript
const { uploadFile, ensureBucket } = require('./minio-example');

// In your app
async function handleFileUpload(file) {
    await ensureBucket('my-app-uploads');
    const url = await uploadFile('my-app-uploads', file.name, file.path);
    return { url };
}
```

### MySQL Database

The `mysql-example.js` demonstrates:
- Connecting to MySQL
- Connection pooling
- Basic CRUD operations
- Transactions
- Prepared statements

Run the example:
```bash
npm run mysql-example
```

## Production Best Practices

### 1. Use Kubernetes Secrets

Instead of hardcoding credentials, mount them from Kubernetes secrets:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: app
    env:
    - name: MINIO_ACCESS_KEY
      valueFrom:
        secretKeyRef:
          name: minio-credentials
          key: accessKey
    - name: MINIO_SECRET_KEY
      valueFrom:
        secretKeyRef:
          name: minio-credentials
          key: secretKey
```

### 2. Connection Pooling

Always use connection pooling for database connections:

```javascript
const mysql = require('mysql2/promise');

const pool = mysql.createPool({
    host: process.env.MYSQL_HOST,
    connectionLimit: 10,
    waitForConnections: true,
    queueLimit: 0
});
```

### 3. Error Handling

Implement proper error handling and retries:

```javascript
async function uploadWithRetry(bucket, name, path, maxRetries = 3) {
    for (let i = 0; i < maxRetries; i++) {
        try {
            return await uploadFile(bucket, name, path);
        } catch (error) {
            if (i === maxRetries - 1) throw error;
            await new Promise(resolve => setTimeout(resolve, 1000 * Math.pow(2, i)));
        }
    }
}
```

### 4. Health Checks

Implement health check endpoints:

```javascript
app.get('/health', async (req, res) => {
    const checks = {
        minio: false,
        mysql: false
    };
    
    try {
        await minioClient.listBuckets();
        checks.minio = true;
    } catch (error) {
        console.error('MinIO health check failed:', error);
    }
    
    try {
        await pool.query('SELECT 1');
        checks.mysql = true;
    } catch (error) {
        console.error('MySQL health check failed:', error);
    }
    
    const healthy = Object.values(checks).every(v => v);
    res.status(healthy ? 200 : 503).json({
        status: healthy ? 'healthy' : 'unhealthy',
        checks
    });
});
```

### 5. Monitoring

Add metrics for monitoring:

```javascript
const prometheus = require('prom-client');

const uploadDuration = new prometheus.Histogram({
    name: 'minio_upload_duration_seconds',
    help: 'MinIO upload duration in seconds',
    buckets: [0.1, 0.5, 1, 2, 5]
});

async function monitoredUpload(bucket, name, path) {
    const end = uploadDuration.startTimer();
    try {
        const result = await uploadFile(bucket, name, path);
        end({ status: 'success' });
        return result;
    } catch (error) {
        end({ status: 'error' });
        throw error;
    }
}
```

## Troubleshooting

### Connection Issues

1. **MinIO Connection Failed**
   - Verify endpoint and port
   - Check network policies
   - Ensure credentials are correct
   - Test with MinIO client: `mc alias set test https://endpoint accesskey secretkey`

2. **MySQL Connection Failed**
   - Check if MySQL service is accessible
   - Verify credentials
   - Test connection: `kubectl run -it --rm mysql-test --image=mysql:8 -- mysql -h mysql.mysql.svc.cluster.local -u user -p`

### Performance Issues

1. **Slow Uploads**
   - Use multipart uploads for large files
   - Consider increasing MinIO resources
   - Check network bandwidth

2. **Database Timeouts**
   - Increase connection timeout
   - Use connection pooling
   - Optimize queries with indexes

## Additional Resources

- [MinIO JavaScript SDK](https://docs.min.io/docs/javascript-client-quickstart-guide.html)
- [MySQL2 Documentation](https://github.com/sidorares/node-mysql2)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)