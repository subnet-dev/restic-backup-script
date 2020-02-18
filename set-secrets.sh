#!/bin/sh

security add-generic-password -a restic-backup -s backup-restic-s3-account-id -w "S3 Access key"
security add-generic-password -a restic-backup -s backup-restic-s3-account-key -w "S3 Secret Key"
security add-generic-password -a restic-backup -s backup-restic-repository -w "s3:http(s)://s3.example.com:1234/bucket-name"
security add-generic-password -a restic-backup -s backup-restic-password -w "MyResticPa$$w0Rd"
