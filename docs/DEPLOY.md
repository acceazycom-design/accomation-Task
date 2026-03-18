# Accomation.io — Deployment Guide
# Your team runs these commands on your AWS server to go live.

===========================================================
STEP 1 — SSH into your AWS EC2 server
===========================================================

ssh -i your-key.pem ubuntu@your-ec2-ip

===========================================================
STEP 2 — Install required software (run once)
===========================================================

# Install Node.js 20
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2 (keeps your app running)
sudo npm install -g pm2

# Install Nginx (web server)
sudo apt-get install -y nginx

===========================================================
STEP 3 — Upload and configure the backend
===========================================================

# Upload the backend folder to your server
scp -r -i your-key.pem ./accomation/backend ubuntu@your-ec2-ip:~/accomation-backend

# SSH in and set up
cd ~/accomation-backend
npm install

# Create your .env file
cp .env.example .env
nano .env
# → Fill in your RDS endpoint, DB password, JWT secret, AWS keys

===========================================================
STEP 4 — Start the backend with PM2
===========================================================

pm2 start src/index.js --name accomation-api
pm2 save
pm2 startup   # Auto-start on server reboot

# Check it's running
pm2 status
curl http://localhost:3000/health
# Should return: {"status":"ok","app":"Accomation.io"}

===========================================================
STEP 5 — Configure Nginx as reverse proxy
===========================================================

sudo nano /etc/nginx/sites-available/accomation

# Paste this config:
server {
    listen 80;
    server_name api.accomation.io;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_bypass $http_upgrade;
    }
}

sudo ln -s /etc/nginx/sites-available/accomation /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

===========================================================
STEP 6 — Add SSL (HTTPS) with Let's Encrypt (Free)
===========================================================

sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d api.accomation.io
# Follow prompts — SSL is free and auto-renews

===========================================================
STEP 7 — Create your Admin account
===========================================================

curl -X POST https://api.accomation.io/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"name":"Your Name","email":"admin@accomation.io","password":"YourPassword123","role":"admin"}'

# Save the token returned — you'll need it to invite team members

===========================================================
STEP 8 — Invite all 25 team members
===========================================================

# Use the token from step 7
curl -X POST https://api.accomation.io/api/auth/invite \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name":"Team Member Name","email":"member@accomation.io","role":"member"}'

# Repeat for each team member — they get a temp password to log in with

===========================================================
STEP 9 — Build & deploy the Flutter app
===========================================================

# On your dev machine (needs Flutter SDK installed)
cd accomation/frontend

# Update the API URL in lib/services/api_service.dart
# Change: static const String baseUrl = 'https://api.accomation.io/api';

# Build for Web
flutter build web
# → Output in build/web/ — upload to S3 + CloudFront

# Build for Android
flutter build apk --release
# → Output: build/app/outputs/flutter-apk/app-release.apk
# → Share APK directly with team OR upload to Google Play

# Build for iOS (needs Mac + Xcode)
flutter build ios --release
# → Upload to App Store via Xcode

===========================================================
STEP 10 — Web hosting on S3 + CloudFront
===========================================================

# Upload web build to S3
aws s3 sync build/web/ s3://accomation-app/ --delete

# Set S3 bucket for static website hosting in AWS console
# Point CloudFront to S3 bucket
# Add custom domain: app.accomation.io → CloudFront

===========================================================
DONE! Your app is live.
===========================================================

Web:     https://app.accomation.io
API:     https://api.accomation.io
Android: Share the APK or Google Play Store
iOS:     App Store

All 25 team members log in with their email + password.
All data syncs in real time across Web, Android, and iOS.

===========================================================
TROUBLESHOOTING
===========================================================

# Check API logs
pm2 logs accomation-api

# Restart API
pm2 restart accomation-api

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log

# Test database connection
curl https://api.accomation.io/health
